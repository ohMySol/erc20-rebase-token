// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IRebaseTokenErrors {
    /// @notice Thrown when the slippage is too high
    error SharesSlippage();
    /// @notice Thrown when the amount is invalid
    error ERC20InvalidAmount(uint256);
    /// @notice Thrown when the amount of shares to burn is 0
    error ZeroSharesToBurn();
}