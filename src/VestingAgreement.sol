pragma solidity 0.8.20;

import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract VestingAgreement is ERC721 {

    // `cliffMonths` number of months in the cliff window
    // `vestMonths`  number of months in the vest window
    // `asset`       address of the ERC20 asset token
    // `startTime`   timestamp where vesting cliff time begins
    // `amount`      amount of asset tokens to be vested  
    struct VestingParameters {
        uint16 cliffMonths;
        uint16 vestMonths;
        address asset;
        uint128 startTime;
        uint128 amount;
    }

    address immutable public vestClaimFactory;

    mapping(address => VestingParameters) public contractDetails;

    constructor(address _vestClaimFactory) ERC721("VestingAgreemnent", "VST") {
        vestClaimFactory = _vestClaimFactory;
    }

    /**
     * @notice Mints a vesting agreement token and stores vesting parameters
     * @param recipient             the address to receive the assets and vest token
     * @param counterFactualAddress the address that holds funds, also the token id to mind
     * @param cliffMonths           number of months in the cliff window
     * @param vestMonths            number of months in the vest window
     * @param asset                 address of the ERC20 asset token
     * @param startTime             timestamp where vesting cliff time begins
     * @param amount                amount of asset tokens to be vested
     */
    function mint(
        address recipient,
        address counterFactualAddress,
        uint16 cliffMonths,
        uint16 vestMonths,
        address asset,
        uint128 startTime,
        uint128 amount
    ) external {
        require(msg.sender == vestClaimFactory, "!vestclaimfactory");

        _mint(recipient, uint256(uint160(counterFactualAddress)));    
        VestingParameters memory vp = VestingParameters(
            cliffMonths,
            vestMonths,
            asset,
            startTime,
            amount
        );
        contractDetails[recipient] = vp;
    }

    /**
     * @notice Ownerof function that accepts `id` argument as address
     * @dev Since counterfactual address is the token ID this approach works well
     * @param id the unique token id (counterfactual funds address)
     * @return the owner address for the given token
     */
    function ownerOf(address id) external view returns (address) {
        return _ownerOf(uint256(uint160(id)));
    }
}
