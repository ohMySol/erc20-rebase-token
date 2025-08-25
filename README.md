# RebaseERC20 - ETH Rebase Token Contract

A rebase token implementation where user balances automatically increase as the underlying ETH pool grows, similar to AAVE's aTokens or Lido's stETH.
While AAVE or Lido rebase tokens work with different tokens for deposit, my example showcase ETH usage as underlying token. But the code in **ERC20RebaseToken.sol** contract can be easily adjusted to use different tokens for depositing.

## 🔑 Key Concept

This contract uses a **shares-based mechanism** where:
- Users deposit ETH and receive **shares** representing their proportional ownership
- User balances are calculated dynamically based on their share percentage of the total ETH pool
- As the contract's ETH balance grows (through interest, staking rewards, etc.), all user balances automatically increase proportionally

### The Magic Formula
```solidity
User Balance = (User Shares × Total ETH Pool) ÷ Total Shares
```

## 🚀 How It Works

### Example Scenario

**Initial State:**
- Alice deposits 10 ETH → receives 10 shares
- Bob deposits 40 ETH → receives 40 shares  
- Total: 50 ETH, 50 shares

**Balances:**
- Alice: `10 shares × 50 ETH ÷ 50 shares = 10 ETH`
- Bob: `40 shares × 50 ETH ÷ 50 shares = 40 ETH`

**After 10 ETH Interest Earned:**
- Contract now has 60 ETH total
- Shares remain unchanged (10 + 40 = 50)

**New Balances automatically updated:**
- Alice: `10 shares × 60 ETH ÷ 50 shares = 12 ETH` ✨ (+2 ETH interest)
- Bob: `40 shares × 60 ETH ÷ 50 shares = 48 ETH` ✨ (+8 ETH interest)

## 📋 Contract Methods

### `balanceOf(address account) → uint256`
Returns the current ETH balance (including earned interest) that the user can withdraw.

### `mint(address to, uint256 slippageBp) payable`
Deposits ETH and mints shares representing proportional ownership.

**Parameters:**
- `to`: Address to receive the shares
- `slippageBp`: Maximum slippage in basis points (protection against deposit front-running)

**Share Calculation:**
- First deposit: `shares = msg.value`
- Subsequent: `shares = totalShares × msg.value ÷ (currentBalance - msg.value)`

### `burn(address from, uint256 amount)`
Burns shares and withdraws the specified ETH amount (including interest).

**Parameters:**
- `from`: Address to burn shares from  
- `amount`: **ETH amount** to withdraw (NOT shares)

**Important:** The `amount` is in ETH, not shares. The contract calculates how many shares to burn automatically.

### `transfer(address to, uint256 amount) → bool`
Transfers ETH amount worth of shares to another address.

### `transferFrom(address from, address to, uint256 amount) → bool`
Transfers ETH amount worth of shares between addresses (requires allowance).

### `approve(address spender, uint256 amount) → bool`
Approves spender to spend shares amount on behalf of owner.

**Note:** Allowances are in share amounts, not in underlying tokens.

### `allowance(address owner, address spender) → uint256`
Returns the shares amount the spender can spend on behalf of owner.

### `totalSupply() → uint256`
Returns the total ETH held by the contract.

### `_amountToShares(uint256 amount) → (uint256)`
Converts amount of tokens in shares representation.
When user transfer or withdraw underlying tokens, we need to calculate how many shares to deduct, add from the balance.

### `_spendAllowanceOrBlock()`
Verify spender allowance and decrease it if validation pass.

## 🔒 Security Features

### Slippage Protection
The `mint` function includes slippage protection to prevent small deposit attack and front running:

```solidity
// Reverts if shares received deviate too much from expected
if (sharesToMint * 10000 * totalBalance < slippageBp * msg.value * _totalShares) {
    revert SharesSlippage();
}
```

### Withdrawal Protection
Users cannot withdraw more ETH than they own:
- The `_amountToShares` conversion ensures proper share calculation
- Underflow protection prevents burning more shares than owned
- Zero-share burns are blocked to prevent ETH drainage

### Allowance System
Standard ERC20 allowance system for secure third-party interactions.

## ⚠️ Important Considerations

### Rounding
Due to integer division, small amounts might round down to zero shares. The contract prevents zero-share burns to avoid ETH loss.

### Interest Generation
This contract **does not generate interest automatically**. Interest must be added externally through:
- Direct ETH transfers to the contract
- Integration with yield protocols (staking, DeFi lending)
- Rewards distribution mechanisms

### Transfer Precision
When transferring amounts, the receiving balance might be slightly less due to rounding in the shares conversion.

## 🎯 Use Cases

- **Liquid Staking Tokens**: Represent staked ETH that earns rewards
- **Interest-Bearing Deposits**: DeFi savings accounts that accrue yield  
- **Reward Distribution**: Automatically distribute protocol fees to token holders
- **Yield Farming**: Tokens that appreciate from farming rewards

---

*This implementation provides the foundation for a rebase token system. Additional features like governance, yield strategies, or access controls can be added as needed.*