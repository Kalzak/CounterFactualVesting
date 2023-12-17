pragma solidity 0.8.20;

import { VestClaimFactory } from "./VestClaimFactory.sol";
import { VestingAgreement } from "./VestingAgreement.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Claimer {

    uint256 constant monthsInSeconds = 2628000;

    constructor() payable {
        // Get the vestTokenAddr address
        VestingAgreement vestTokenAddr = VestClaimFactory(msg.sender).vestTokenAddr();
        
        // Get the beneficiary address
        address beneficiary = vestTokenAddr.ownerOf(address(this));

        // Get the vesting parameters
        (
            uint128 cliffMonths,
            uint128 vestMonths,
            uint128 startTime_u128,
            uint128 amount
        ) = vestTokenAddr.contractDetails(beneficiary);

        uint256 remainingAmount = address(this).balance;

        // Vesting must have started
        uint256 startTime = startTime_u128;
        require(block.timestamp >= startTime, "!started");

        // Must have passed cliff period
        require(block.timestamp >= startTime + (cliffMonths * monthsInSeconds), "incliff");

        // If entire vest period has passed send all funds
        if(block.timestamp >= startTime + ((cliffMonths + vestMonths) * monthsInSeconds)) {
            send(beneficiary, remainingAmount);
            return;
        }

        // Send funds for unpaid months
        uint256 currentMonth = (block.timestamp - startTime) / monthsInSeconds;
        uint256 amountPerMonth = amount / (cliffMonths + vestMonths);
        uint256 paidMonths = (amount - remainingAmount) / amountPerMonth;
        uint256 amountToPay = (currentMonth - paidMonths) * amountPerMonth;

        send(beneficiary, amountToPay);

        selfdestruct(payable(address(this)));
    }

    function send(address beneficiary, uint256 amount) internal {
        (bool success, ) = beneficiary.call{value: amount, gas: 10000}("");
        require(success, "failed");
    }
}
