// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IRebaseTokenErrors} from "./interfaces/IRebaseTokenContext.sol";

contract RebaseERC20 is IERC20Errors, IRebaseTokenErrors, IERC20 {
    /// @notice The variable storing all shares of all users
    /// @dev This variable is updated during burning or minting of shares when underlying token is added or removed from the contract
    uint256 internal _totalShares;
    
    /// @notice The value that in this mapping, represents a user share of the pool
    /// @dev Fraction of the total supply can be computed as: sharebalance[user] / totalShares(sum of shares of all users)
    mapping(address => uint256) public shareBalance;

    /// @notice The mapping storing the allowance of the owner for the spender
    /// @dev This mapping is used to store the allowance of the owner for the spender
    mapping (address owner => mapping(address spender => uint256 allowance)) internal _allowance;

    /// @notice User deposits underlying token to the contract, and mints an amount of shares that represents 
    /// their percent ownership of all outstanding shares.
    /// @dev If user a 1st minter, then the amount of shares minted is simply `msg.value`.
    /// Otherwise formula for shares minting is the next:
    /// `shares to mint = previous shares balance * msg.value / previous contract underlying token balance`
    /// @param to The address which will receive the shares
    /// @param slippageBp The slippage in basis points, which is the maximum allowed deviation from the ideal shares to mint 
    function mint(address to, uint256 slippageBp) external payable {
        if (to == address(0)) revert ERC20InvalidReceiver(to);

        uint256 sharesToMint;
        if (_totalShares == 0) {
            sharesToMint = msg.value;
        } else {
            sharesToMint = _totalShares * msg.value / (address(this).balance - msg.value);
        }
        
        // Prevent small deposit attack. If the slippage is too high, revert the transaction
        if (sharesToMint * 10000 * address(this).balance < slippageBp * msg.value * _totalShares) {
            revert SharesSlippage();
        }

        _totalShares += sharesToMint;
        shareBalance[to] += sharesToMint;

        emit Transfer(address(0), to, sharesToMint);
    }

    /// @notice User burns shares to withdraw underlying token from the contract
    /// @dev The amount of underlying token that can be withdrawn by the user is computed as:
    /// `total shares * `amount` / address(this).balance`
    /// @param from The address which will burn the shares
    /// @param amount The amount of shares to burn
    function burn(address from, uint256 amount) external {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (amount == 0) revert ERC20InvalidAmount(amount);

        _spendAllowanceOrBlock(from, msg.sender, amount);

        uint256 sharesToBurn = _amountToShares(amount);
        // Prevents Ether from being transferred out of the contract if shares rounds down to 0 in `_amountToShares`.
        // It is possible when _totalShares * amount < address(this).balance, then sharesToBurn = 0.
        if (sharesToBurn == 0) revert ZeroSharesToBurn(); 

        // If user provide an amount of underl. token that he doesn't have in reality, then
        // the `sharesToBurn` will exceed the `shareBalance[from]` --> as a result, the transaction will revert
        // due to underflow in the next line
        shareBalance[from] -= sharesToBurn;
        _totalShares -= sharesToBurn;

        (bool success, ) = payable(from).call{value: amount}("");
        if (!success) revert ERC20InvalidReceiver(from);

        emit Transfer(from, address(0), amount);
    }

    /// @notice Returns the amount of shares that the spender is allowed to spend on behalf of the owner
    /// @param owner The address of the owner of the allowance
    /// @param spender The address of the spender
    /// @return The amount of shares that the spender is allowed to spend on behalf of the owner
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowance[owner][spender];
    }

    /// @notice Approves a spender to spend a certain amount of shares on behalf of the caller. 
    /// Approval behave like a usual approval in ERC-20 token, and it is not rebased.
    /// @dev The spender can then spend the shares using `transferFrom` or `burn`
    /// @param spender The address of the spender
    /// @param amount The amount of shares to approve 
    /// @return True if the approval is successful, false otherwise
    function approve(address spender, uint256 amount) external returns (bool) {
        if (msg.sender == address(0)) revert ERC20InvalidApprover(msg.sender);
        if (spender == address(0)) revert ERC20InvalidSpender(spender);

        _allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Function returns the amount of underlying token(e.g: ETH, USDT, etc) that can be withdrawn by the user
    /// @dev The amount of underlying token that can be withdrawn by the user is computed as:
    /// `user shares * total contract balance of underlying token / total shares`
    /// @param account The address of the user
    /// @return The amount of underlying token that can be withdrawn by the user
    function balanceOf(address account) public view returns(uint256) {
        if (_totalShares == 0) return 0;
        return shareBalance[account] * address(this).balance / _totalShares;
    }
    
    /// @notice Returns the total amount of underlying token(e.g: ETH, USDT, etc) held by the contract
    function totalSupply() public view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Transfers shares from the caller to another address
    /// @dev This function is a wrapper around `transferFrom` that calls it with the caller as the `from` address 
    /// @param to The address which will receive the shares
    /// @param amount The amount of shares to transfer
    /// @return True if the transfer is successful, false otherwise
    function transfer(address to, uint256 amount) external returns (bool) {
        transferFrom(msg.sender, to, amount);
        return true;
    }

    /// @notice Transfers shares from one address to another
    /// @dev The amount of shares to transfer is computed as: `total shares * value / address(this).balance`
    /// Be aware that with the above formula division rounds down, this means that the balance received by `to` might be very slightly less than `value`.
    /// @param from The address which will transfer the shares
    /// @param to The address which will receive the shares
    /// @param amount The amount of shares to transfer
    /// @return True if the transfer is successful, false otherwise
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (from == address(0)) revert ERC20InvalidSender(from);
        if (to == address(0)) revert ERC20InvalidReceiver(to);

        _spendAllowanceOrBlock(from, msg.sender, amount);
        
        uint256 sharesToTransfer = _amountToShares(amount);
        shareBalance[from] -= sharesToTransfer;
        shareBalance[to] += sharesToTransfer;

        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Converts the amount of underlying token to the amount of shares
    /// @dev The amount of shares is computed as: `total shares * amount of underlying token to withdraw / total contract balance of underlying token`
    /// @param amount The amount of underlying token to convert to shares
    /// @return The amount of shares
    function _amountToShares(uint256 amount) internal view returns (uint256) {
        if (address(this).balance == 0) return 0;
        return _totalShares * amount / address(this).balance;
    }

    /// @notice Spends the allowance of the caller or blocks the transaction if the allowance is not enough
    /// @dev If the allowance is not enough, the transaction is reverted
    /// @param owner The address of the owner of the allowance
    /// @param spender The address of the spender
    /// @param amount The amount of shares to spend
    function _spendAllowanceOrBlock(address owner, address spender, uint256 amount) internal {
        if (owner != msg.sender && _allowance[owner][spender] != type(uint256).max) {
            uint256 currentAllowance = _allowance[owner][spender];
            if (currentAllowance < amount) revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            _allowance[owner][spender] -= currentAllowance - amount;
        }
    }
}
