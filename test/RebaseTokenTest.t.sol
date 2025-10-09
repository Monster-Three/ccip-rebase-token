// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    /////////////
    /// Error ///
    /////////////
    error RebaseTokenTest__addRewardsToVaultNotSuccess();

    /////////////////////////
    /// Type declarations ///
    /////////////////////////
    RebaseToken private rebaseToken;
    Vault private vault;

    ///////////////////////
    /// State variables ///
    ///////////////////////
    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    /////////////////
    /// Functions ///
    /////////////////
    function setUp() public {
        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        if (!success) {
            revert RebaseTokenTest__addRewardsToVaultNotSuccess();
        }
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1.deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}(amount);
        // 2.check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log(startBalance, amount);
        // 3.warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startBalance);
        // 4.warp the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, middleBalance);

        /* assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        它的作用是检查两个值是否“近似相等”，在给定的绝对误差范围内。*/
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 _amount) public {
        _amount = bound(_amount, 1e5, type(uint96).max);
        // 1.deposit
        vm.startPrank(user);
        vm.deal(user, _amount);
        vault.deposit{value: _amount}(_amount);
        // 2.check our rebase token balance
        assertEq(rebaseToken.balanceOf(user), _amount);
        // 3.redeem the tokens
        vault.redeem(type(uint256).max);
        // 4.check the balance again
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, _amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        // 1.deposit
        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}(depositAmount);
        // 2.warp the time
        vm.warp(block.timestamp + time);
        uint256 balance = rebaseToken.balanceOf(user);
        // 2.(b) Add the rewards to the vault
        vm.deal(owner, balance - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balance - depositAmount);
        // 3. redeem
        vm.prank(user);
        vault.redeem(balance);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, balance);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 2e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        // 1.deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(amount);

        address user2 = makeAddr("user2");
        uint256 userbalance = rebaseToken.balanceOf(user);
        uint256 user2balance = rebaseToken.balanceOf(user2);
        assertEq(userbalance, amount);
        assertEq(user2balance, 0);

        //owner reduce the interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 2.transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, amount - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // check the interest rate has been inherited(5e10 not 4e10)
        assertEq(rebaseToken.getUserInteretsRate(user), 5e10);
        assertEq(rebaseToken.getUserInteretsRate(user2), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testUserCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.mint(user, 100, rebaseToken.getInterestRate());
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.burn(user, 100);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint256).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}(amount);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterstRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterstRate = bound(newInterstRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.Rebasetoken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterstRate);
        // assertEq(rebaseToken.getInterestRate(), newInterstRate);
    }
}
