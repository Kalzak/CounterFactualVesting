pragma solidity 0.8.20;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Create2 } from "openzeppelin-contracts/contracts/utils/Create2.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { VestingAgreement } from "./VestingAgreement.sol";
import { Claimer } from "./Claimer.sol";

contract VestClaimFactory is Ownable {

    VestingAgreement public vestTokenAddr;
    mapping(address => bool) public issuers;
    mapping(address => uint256) public numContracts;

    modifier onlyIssuer() {
        require(issuers[msg.sender] == true, "!issuer");
        _;
    }

    constructor(address _owner) Ownable(_owner) {}

    /**
     * @notice Creates a vesting agreement and allocates funds to counterfactual address
     * @dev Minted VestingAgreement ID is the same as counterfactual address
     * @param beneficiary The address that will recieve the funds
     * @param cliffMonths The number of cliff months
     * @param vestMonths  The number of vest months
     * @param startTime   The time at which vesting starts
     */
    function issueVestingContract(
        address beneficiary,
        uint16 cliffMonths,
        uint16 vestMonths,
        address asset,
        uint128 startTime,
        uint128 amount
    ) public onlyIssuer {
        // Cannot vest an amount of zero
        require(amount != 0, "zero amount");
        // Vest amount must be cleanly divisible by number of months
        require(amount % (cliffMonths + vestMonths) == 0, "no clean divide");
        // Total vest time period cannot be more than 100 years
        require(cliffMonths + vestMonths <= 1200, "vest>100yrs");
        // Total vest time cannot be zero
        require(cliffMonths + vestMonths != 0, "zero vest time");

        address fundsAddr = calculateFundsAddress(beneficiary, numContracts[beneficiary]);
        
        vestTokenAddr.mint(
            beneficiary,
            fundsAddr,
            cliffMonths,
            vestMonths,
            asset,
            startTime,
            amount
        );

        // Transfer funds
        IERC20(asset).transferFrom(msg.sender, fundsAddr, amount);
    }

    /**
     * @notice Calculates the counterfactual address that holds funds for beneficiary
     * @param beneficiary The address to calculate the vest address for
     * @param contractNum The number of the vesting agreement (1st is 0, then 1 etc...)
     * @return The counterfactual address
     */
    function calculateFundsAddress(
        address beneficiary,
        uint256 contractNum
    ) public view returns (address) {
        bytes32 salt = calculateSalt(beneficiary, contractNum);
        return Create2.computeAddress(salt, keccak256(type(Claimer).creationCode));
    }

    /**
     * @notice Called by a beneficiary, claims funds from counterfactual address
     * @dev Deploys claimer contract at funds address, self-destructs after
     * @param fundsAddr   The counterfactual address to claim funds from
     * @param contractNum The number of the vesting agreement (1st is 0, then 1 etc...)
     */
    function claim(address fundsAddr, uint256 contractNum) external {
        require(vestTokenAddr.ownerOf(fundsAddr) == msg.sender);
        bytes32 salt = calculateSalt(msg.sender, contractNum);
        Create2.deploy(0, salt, type(Claimer).creationCode);
    }

    /**
     * @notice Sets the issuer role state for an addres
     * @dev Only callably by owner
     * @param issuer   The address to have its issuer role modified
     * @param isIssuer The new issuer role status
     */
    function setIssuer(address issuer, bool isIssuer) external onlyOwner {
        issuers[issuer] = isIssuer;
    }

    /**
     * @notice Sets the vesting agreement address
     * @dev Only callable once, by owner
     * @param _vestTokenAddr The vesting agreement contract address
     */
    function setVestTokenAddr(VestingAgreement _vestTokenAddr) external onlyOwner {
        require(_vestTokenAddr != VestingAgreement(address(0)));
        vestTokenAddr = _vestTokenAddr;
    }

    /**
     * @notice Calculates the unique salt needed for counterfactual address calculation
     * @param beneficiary The address of the beneficiary
     * @param contractNum The number of the vesting agreement (1st is 0, then 1 etc...)
     * @return The unique salt to be used with create2 for counterfactual deployment
     */
    function calculateSalt(
        address beneficiary,
        uint256 contractNum
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(beneficiary, contractNum));
    }
}
