pragma solidity 0.8.20;

import { VestClaimFactory } from "./VestClaimFactory.sol";
import { VestingAgreement } from "./VestingAgreement.sol";

contract Claimer {

    uint256 constant monthsInSeconds = 2628000;

    constructor() payable {
        // Get the vestTokenAddr address
        VestingAgreement vestTokenAddr = VestClaimFactory(msg.sender).vestTokenAddr();
        
        address beneficiary = vestTokenAddr.ownerOf(address(this));

        // Get the vesting parameters
        (
            uint128 cliffMonths,
            uint128 vestMonths,
            uint128 startTime128,
            uint128 amount
        ) = vestTokenAddr.contractDetails(beneficiary);

        

        uint256 cliffTime = cliffMonths * 2628000; // Seconds in a non-leap-year div 12
        uint256 startTime = uint256(startTime128);

        // Vesting must have started
        require(block.timestamp >= startTime, "!started");

        // Must have passed cliff window
        require(block.timestamp >= startTime + cliffTime, "incliffwindow");

        // Calculate how many months haven't been paid yet
        uint256 amountPerMonth = amount / (cliffMonths + vestMonths);
        uint256 monthsUnpaid = address(this).balance / amountPerMonth;

        // If no unpaid months then entire contract wait time is done
        if(monthsUnpaid == 0) {
            send(beneficiary, address(this).balance);
        }

        // Calculate how many months have been paid
        uint256 monthsPaid = (cliffMonths + vestMonths) - monthsUnpaid;

        // Calculate the current month we're at
        uint256 timeSinceStart = block.timestamp - startTime;
        uint256 currentMonth = timeSinceStart / monthsInSeconds;

        // Calculate the number of months owed
        uint256 monthsOwed = currentMonth - monthsPaid;

        // Pay owed months
        send(beneficiary, amountPerMonth * monthsOwed);

        selfdestruct(payable(address(this)));

    }

    function send(address beneficiary, uint256 amount) internal {
        (bool success, bytes memory data) = beneficiary.call{value: amount, gas: 10000}("");
        require(success, "failed");
        require(data.length == 0, "len");
    }
}
