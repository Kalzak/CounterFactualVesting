pragma solidity 0.8.20;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
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
     * @notice Sets the vesting agreement address
     * @dev Only callable once, by owner
     * @param _vestTokenAddr The vesting agreement contract address
     */
    function setVestTokenAddr(VestingAgreement _vestTokenAddr) external onlyOwner {
        require(_vestTokenAddr != VestingAgreement(address(0)));
        vestTokenAddr = _vestTokenAddr;
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
    ) external onlyIssuer {
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
     * @notice Called by a beneficiary, claims funds from counterfactual address
     * @dev Deploys claimer contract at funds address, self-destructs after
     * @param fundsAddr   The counterfactual address to claim funds from
     * @param contractNum The number of the vesting agreement (1st is 0, then 1 etc...)
     */
    function claim(address fundsAddr, uint256 contractNum) external {
        require(vestTokenAddr.ownerOf(fundsAddr) == msg.sender);
        bytes32 salt = calculateSalt(msg.sender, contractNum);
        create2Deploy(type(Claimer).creationCode, salt);
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
        return calculateCreate2Deployment(type(Claimer).creationCode, salt);
    }

    /**
     * @notice Create2 deploys some creation code with a given salt
     * @dev Always deploys with zero value
     * @param creationCode the init code of the contract that will be deployed
     * @param salt         the unique salt derived from beneficiary addr and contractnum
     */
    function create2Deploy(
        bytes memory creationCode,
        bytes32 salt
    ) internal {
        bool success;
        assembly ("memory-safe") {
            // create2 takes args ( <value>, <codeOffset>, <codeLen>, <salt>)
            let addr := create2(0, add(creationCode, 0x20), mload(creationCode), salt)
            success := not(eq(addr, 0x0))
        }
        require(success, "create2 failed");
    }

    /**
     * @notice Calculates the address a create2 would deploy at
     * @param creationCode the init code of the contract that will be deployed
     * @param salt         the unique salt derived from beneficiary addr and contractnum
     * @return addr the address if deployed using create2
     */
    function calculateCreate2Deployment(
        bytes memory creationCode,
        bytes32 salt
    ) internal view returns (address addr) {
        assembly ("memory-safe") {
            /*
             * Create2 deployed address can be calculated as follows:
             * keccak( 0xff + <deployer> + <salt> + <codeHash> )[12:]
             * In this case "+" means "concatenate"
             */

            let ptr := mload(0x40)
            // Update free memory pointer (effectively alloc 96 bytes of memory)
            mstore(0x40, add(ptr, 0x60))
            // Mem-store the <deployer> address (which is this contract address)
            mstore(ptr, or(shl(0xa0, 0xff), address()))
            // Mem-store the <salt> (needed for unique deploy add for beneficiary) 
            mstore(add(ptr, 0x20), salt)
            // Mem-store the <codeHash> (hash of the `Claimer` deployment bytecode)
            mstore(add(ptr, 0x40), keccak256(add(creationCode, 0x20), mload(creationCode)))
            // Hash all mem-stored data above and cut off first 12 bytes to get address
            addr := and(keccak256(add(ptr, 0xb), 0x55), sub(shl(0xa0, 0x1), 0x1))
        }
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
