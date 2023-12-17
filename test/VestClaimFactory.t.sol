// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TestToken} from "./TestToken.sol"; 

import {VestClaimFactory} from "../src/VestClaimFactory.sol";
import {VestingAgreement} from "../src/VestingAgreement.sol";
import {Claimer} from "../src/Claimer.sol";

contract VestClaimFactoryTest is Test {
    VestClaimFactory public vcf;
    VestingAgreement public va;
    TestToken public tt;

    uint256 constant monthsInSeconds = 2628000;

    address immutable owner = makeAddr("owner");
    address immutable issuer = makeAddr("issuer");
    address immutable beneficiary = makeAddr("beneficiary");

    function setUp() public {
        vm.startPrank(owner);
        
        // Create factory and assign issuer role
        vcf = new VestClaimFactory(owner);
        vcf.setIssuer(issuer, true);

        // Create the vesting agreement token contract
        va = new VestingAgreement(address(vcf));      
    
        // Set the vesting agreement token contract address
        vcf.setVestTokenAddr(va);
        
        tt = new TestToken();

        vm.stopPrank();
    }

    //////////////////////
    // PERMISSION CHECKS
    //////////////////////

    function test_owner_permissions() public {
        // Setup
        address nonOwner = makeAddr("nonowner");

        // Test
        vm.startPrank(nonOwner);

        vm.expectRevert();
        vcf.setIssuer(nonOwner, true);

        vm.expectRevert();
        vcf.setVestTokenAddr(VestingAgreement(nonOwner));
    
        vm.stopPrank();
    }

    function test_issuer_permissions() public {
        // Setup
        address nonIssuer = makeAddr("nonissuer");

        // Test
        vm.prank(nonIssuer);
        vm.expectRevert("!issuer");
        vcf.issueVestingContract(
            beneficiary, 
            1, 
            1, 
            address(tt),
            uint128(block.timestamp),
            0
        );
    }

    //////////////////////////////
    // ISSUING VESTING CONTRACTS
    //////////////////////////////

    function test_issue_vest_sends_funds() public {
        // Setup
        uint128 amount = 2 ether;
        tt.mint(issuer, amount);
        vm.prank(issuer);
        tt.approve(address(vcf), amount);
        
        // Test
        vm.prank(issuer);
        vcf.issueVestingContract(
            beneficiary, 
            1, 
            1, 
            address(tt),
            uint128(block.timestamp),
            amount
        );

        address fundsAddr = vcf.calculateFundsAddress(beneficiary, 0);
        assertEq(tt.balanceOf(fundsAddr), amount, "Contract did not get funds");
    }

    function test_issue_vest_nondivisible_amount_revert(
        uint128 amount,
        uint16 cliffMonths,
        uint16 vestMonths
    ) public {
        // Fuzz constraints
        cliffMonths %= 1200;
        vestMonths %= (1200 - cliffMonths);
        vm.assume(cliffMonths + vestMonths != 0);
        vm.assume(amount % (cliffMonths + vestMonths) != 0);
        
        // Setup
        tt.mint(issuer, amount);
        vm.prank(issuer);
        tt.approve(address(vcf), amount);
        
        // Test
        vm.prank(issuer);
        vm.expectRevert("no clean divide");
        vcf.issueVestingContract(
            beneficiary,
            cliffMonths,
            vestMonths,
            address(tt),
            uint128(block.timestamp),
            amount
        );
    }

    function test_issue_vest_mints_token() public {
        // Setup
        uint128 amount = 2 ether;
        tt.mint(issuer, amount);
        vm.prank(issuer);
        tt.approve(address(vcf), amount);
        
        // Test
        vm.prank(issuer);
        vcf.issueVestingContract(
            beneficiary, 
            1, 
            1, 
            address(tt),
            uint128(block.timestamp),
            amount
        );

        uint256 balance = va.balanceOf(beneficiary);
        assertEq(balance, 1, "Vesting token not minted");
    }

    //
    // CLAIMING
    //

    function test_claim_retreives_funds_after_cliff(
        uint128 amount,
        uint16 cliffMonths,
        uint16 vestMonths
    ) public {
        // Fuzz constraints
        cliffMonths %= 1200;
        vestMonths %= (1200 - cliffMonths);
        vm.assume(cliffMonths + vestMonths != 0);  
        amount -= (amount % (cliffMonths + vestMonths));
        vm.assume(amount > cliffMonths + vestMonths);

        // Setup
        tt.mint(issuer, amount);
        vm.prank(issuer);
        tt.approve(address(vcf), amount);
        
        // Test
        vm.prank(issuer);
        vcf.issueVestingContract(
            beneficiary, 
            cliffMonths, 
            vestMonths, 
            address(tt),
            uint128(block.timestamp),
            amount
        );

        vm.warp(block.timestamp + (monthsInSeconds * cliffMonths));

        address fundsAddr = vcf.calculateFundsAddress(beneficiary, 0);
        vm.prank(beneficiary);
        vcf.claim(fundsAddr, 0);

        uint256 actualBalance = tt.balanceOf(beneficiary);
        uint256 expectedBalance = (amount / (cliffMonths + vestMonths)) * cliffMonths;

        assertEq(expectedBalance, actualBalance, "unexpected payment amount");
    }

    function test_claim_retreives_funds_after_vest(
        uint128 amount,
        uint16 cliffMonths,
        uint16 vestMonths
    ) public {
        // Fuzz constraints
        cliffMonths %= 1200;
        vestMonths %= (1200 - cliffMonths);
        vm.assume(cliffMonths + vestMonths != 0);
        amount -= (amount % (cliffMonths + vestMonths));
        vm.assume(amount > cliffMonths + vestMonths);

        // Setup
        tt.mint(issuer, amount);
        vm.prank(issuer);
        tt.approve(address(vcf), amount);
        
        // Test
        vm.prank(issuer);
        vcf.issueVestingContract(
            beneficiary, 
            cliffMonths, 
            vestMonths, 
            address(tt),
            uint128(block.timestamp),
            amount
        );

        vm.warp(block.timestamp + (monthsInSeconds * (cliffMonths + vestMonths)));

        address fundsAddr = vcf.calculateFundsAddress(beneficiary, 0);
        vm.prank(beneficiary);
        vcf.claim(fundsAddr, 0);

        uint256 actualBalance = tt.balanceOf(beneficiary);
        uint256 expectedBalance = amount;

        assertEq(expectedBalance, actualBalance, "unexpected payment amount");
    }
}
