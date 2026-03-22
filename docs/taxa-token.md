# TaxaToken (TAXA) Documentation

## Purpose

TaxaToken is a **non-transferable** ERC-20 governance token. It represents voting power derived from off-chain tax payments. TAXA is not a currency — it cannot be traded, bought, or transferred between users. It exists solely to measure and enforce voting rights within the SmartTaxAllocation system.

## Token Specifications

| Property | Value |
|---|---|
| Name | TAXA |
| Symbol | TAXA |
| Decimals | 18 |
| Initial Supply | 0 (no pre-mint) |
| Max Supply | Unlimited (admin mints as needed) |
| Transferable | No |
| Standard | ERC-20 (with transfer restriction) |
| Base Contracts | OpenZeppelin ERC20, Ownable |

## Token Lifecycle

```
Off-chain          On-chain                   On-chain
Tax Payment   -->  Admin mints TAXA    -->    Citizen votes (tokens burned)
                   to taxpayer wallet         |
                                              v
                                         Round finalized
                                         (tokens permanently gone)

                                         -- OR --

                                         Round cancelled
                                         (tokens re-minted via reclaim)
```

### Minting

The contract owner (admin) mints TAXA tokens to taxpayer addresses after verifying their off-chain tax payment. There is no fixed supply — the admin can mint as needed.

```solidity
function mint(address _to, uint256 _amount) external onlyOwner
```

### Burning

The SmartTaxAllocation contract burns tokens from a user's wallet when they allocate votes to a project. Only the designated allocation contract can call this.

```solidity
function burn(address _from, uint256 _amount) external  // allocationContract only
```

### Re-minting (Reclaim)

If a voting round is cancelled, users can reclaim their burned tokens. The allocation contract re-mints the exact amount.

```solidity
function mintFromAllocation(address _to, uint256 _amount) external  // allocationContract only
```

## Non-Transferability

The `_update` hook (inherited from OpenZeppelin ERC20) is overridden to block all transfers:

```solidity
function _update(address from, address to, uint256 value) internal override {
    bool isMint = (from == address(0));
    bool isBurn = (to == address(0));
    require(isMint || isBurn, "Transfers disabled");
    super._update(from, to, value);
}
```

This means:
- `transfer()` always reverts
- `transferFrom()` always reverts
- `approve()` still works (no harm, but transferFrom will fail)
- Only `_mint()` and `_burn()` succeed

## Access Control

| Function | Who Can Call |
|---|---|
| `mint` | Owner (admin) only |
| `burn` | Allocation contract only |
| `mintFromAllocation` | Allocation contract only |
| `setAllocationContract` | Owner (admin) only |
| `transfer` / `transferFrom` | Nobody (always reverts) |

## Configuration

After deployment, the owner must call `setAllocationContract()` to authorize the SmartTaxAllocation contract for burn/re-mint operations:

```solidity
token.setAllocationContract(address(smartTaxAllocation));
```

This is a one-time setup step (though it can be updated if the allocation contract is redeployed).

## Security Notes

- **No fixed supply.** The admin can mint unlimited tokens. This is intentional for the MVP — the admin is trusted to mint proportionally to verified tax payments.
- **No self-burn.** Users cannot burn their own tokens. Only the allocation contract can burn.
- **No pause.** There is no emergency pause mechanism on the token.
- **Audited base.** Built on OpenZeppelin's battle-tested ERC20 and Ownable contracts.
