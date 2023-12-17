pragma solidity 0.8.20;

import { ERC721 } from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract VestingAgreement is ERC721 {

    struct VestingParameters {
        uint128 cliffMonths;
        uint128 vestMonths;
        uint128 startTime;
        uint128 amount;
    }

    address immutable public vestClaimFactory;

    mapping(address => VestingParameters) public contractDetails;

    constructor(address _vestClaimFactory) ERC721("VestingAgreemnent", "VST") {
        vestClaimFactory = _vestClaimFactory;
    }

    function mint(
        address recipient,
        address counterFactualAddress,
        uint128 cliffMonths,
        uint128 vestMonths,
        uint128 startTime,
        uint128 amount
    ) public {
        _mint(recipient, uint256(uint160(counterFactualAddress)));    
        VestingParameters memory vp = VestingParameters(
            cliffMonths,
            vestMonths,
            startTime,
            amount
        );
        contractDetails[recipient] = vp;
    }

    function ownerOf(address id) external view returns (address) {
        return _ownerOf(uint256(uint160(id)));
    }
}
