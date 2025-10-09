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

import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

contract Vault {
    // We need to pass the token address to the constructor
    // create a deposit function that mints tokens to the user equal the amount of ETH the user has sent
    // create a redeem function that burns the tokens and sends the user the equivalent amount of ETH
    // create a way to add rewards to the vault

    IRebaseToken private immutable i_rebaseToken;

    error Vault__RedeemFailed(address user, uint256 amount);

    // indexed的作用？
    /* 也就是说，在Etherscan里面直接搜索user对应的address的话，就会直接显示出它所对应的相关事件 */
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {
        // We need to use the amount of ETH the user has sent to mint tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to deposit ETH into the vault and receive Rebase tokens in return
     * @param _amount The amount of tokens the user wants to deposit
     */
    function deposit(uint256 _amount) external payable {
        // We need to use the amount of ETH the user has sent to mint tokens to the user
        // 我们需要使用用户发送的ETH数量来为用户制造令牌
        uint256 interestRate = i_rebaseToken.getInterestRate();
        i_rebaseToken.mint(msg.sender, _amount, interestRate);
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice Allows users to redeem their Rebase tokens for ETH
     * @param _amount The amount of tokens the user wants to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // Burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // Send the user the equivalent amount of ETH
        /* _amount 这个变量代表的是要销毁的代币数量，而你却用它来指定要转账的 ETH 数量。
        在不同的情况中，你可能需要一个转换汇率来计算应该转账多少 ETH。*/
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed(msg.sender, _amount);
        }
        emit Redeem(msg.sender, _amount);
    }

    /**
     * @notice Get the address of the Rebase token
     * @return The address of the Rebasetoken contract
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
