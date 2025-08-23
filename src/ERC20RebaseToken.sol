// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract RebaseERC20 is IERC20Errors, IERC20 {
    /// @notice The variable storing all shares of all users
    /// @dev This variable is updated during burning or minting of shares when underlying token is added or removed from the contract
    uint256 internal _totalShares;
    
    /// @notice The value that in this mapping, represents a user share of the pool
    /// @dev Fraction of the total supply can be computed as: _sharebalance[user] / totalShares(sum of shares of all users)
    mapping(address => uint256) internal _shareBalance;
    

    /// @notice Function returns the amount of underlying token(e.g: ETH, USDT, etc) that can be withdrawn by the user
    /// @dev The amount of underlying token that can be withdrawn by the user is computed as:
    /// `user shares * total contract balance of underlying token / total shares``
    /// @param account The address of the user
    /// @return The amount of underlying token that can be withdrawn by the user
    function balanceOf(address account) public view returns(uint256) {
        if (_totalShares == 0) return 0;
        return _shareBalance[account] * address(this).balance / _totalShares;
    }

    /// @notice User deposits underlying token to the contract, and mints an amount of shares that represents 
    /// their percent ownership of all outstanding shares.
    /// @dev If user a 1st minter, then the amount of shares minted is simply `msg.value`.
    /// Otherwise formula for shares minting is the next:
    /// `shares to mint = previous shares balance * msg.value / previous contract underlying token balance`
    function mint(address to) external payable {
        if (to == address(0)) revert ERC20InvalidReceiver(to);

        uint256 sharesToMint;
        if (_totalShares == 0) {
            sharesToMint = msg.value;
        } else {
            sharesToMint = _totalShares * msg.value / (address(this).balance - msg.value);
            _totalShares += sharesToMint;
            _shareBalance[to] += sharesToMint;
        }

        uint256 balance = sharesToMint * address(this).balance / _totalShares;
        emit Transfer(address(0), to, balance);
    }

    function allowance(address owner, address spender) external view returns (uint256) {}

    function approve(address spender, uint256 value) external returns (bool) {}

    function totalSupply() external view returns (uint256) {}

    function transfer(address to, uint256 value) external returns (bool) {}

    function transferFrom(address from, address to, uint256 value) external returns (bool) {}
}
