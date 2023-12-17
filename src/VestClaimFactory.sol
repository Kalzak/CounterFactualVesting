pragma solidity 0.8.20;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Create2 } from "openzeppelin-contracts/contracts/utils/Create2.sol";
import { VestingAgreement } from "./VestingAgreement.sol";
import { Claimer } from "./Claimer.sol";

contract VestClaimFactory is Ownable {

    VestingAgreement public vestTokenAddr;
    mapping(address => uint256) public numContracts;
    mapping(address => bool) issuers;

    constructor() Ownable(msg.sender) {}

    function issueVestingContract(
        address beneficiary,
        uint128 cliffMonths,
        uint128 vestMonths,
        uint128 startTime
    ) public payable {
        // Validate that the amount is cleanly divisible by the number of months
        require(msg.value % cliffMonths + vestMonths == 0, "invalid amount");
        address fundsAddr = calculateFundsAddress(beneficiary, numContracts[beneficiary]);
        vestTokenAddr.mint(beneficiary, fundsAddr, cliffMonths, vestMonths, startTime, uint128(msg.value));
        (bool success, bytes memory data) = fundsAddr.call{value: msg.value}("");

        // Empty return from call to empty contract
        require(data.length == 0, "unexpected return");
        require(success, "failed");
    }

    function calculateFundsAddress(
        address beneficiary,
        uint256 contractNum
    ) public view returns (address) {
        bytes32 salt = calculateSalt(beneficiary, contractNum);
        return Create2.computeAddress(salt, keccak256(type(Claimer).creationCode));
    }

    function claim(address fundsAddr, uint256 contractNum) external {
        // Caller must be the owner of the contract associated with the address
        require(vestTokenAddr.ownerOf(fundsAddr) == msg.sender);
        bytes32 salt = calculateSalt(msg.sender, contractNum);
        Create2.deploy(0, salt, type(Claimer).creationCode);
    }

    function setIssuer(address issuer, bool isIssuer) external {
        issuers[issuer] = isIssuer;
    }

    function setVestTokenAddr(VestingAgreement _vestTokenAddr) onlyOwner public {
        require(vestTokenAddr != VestingAgreement(address(0)));
        vestTokenAddr = _vestTokenAddr;
    }

    function calculateSalt(
        address beneficiary,
        uint256 contractNum
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(beneficiary, contractNum));
    }
}
