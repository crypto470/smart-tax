# Glossary

### Admin

The Ethereum address with elevated privileges. Can mint TAXA tokens, start/cancel voting rounds, and propose project changes. Initially set to the contract deployer. Can be transferred.

### Allocation

The process of distributing budget across projects based on vote results. In this system, allocation is determined on-chain (as QV vote percentages) but executed off-chain (actual money distribution).

### Burn

Permanently destroying TAXA tokens. Happens automatically when a citizen allocates votes to a project. Burned tokens reduce the user's balance and the total supply.

### ERC-20

The standard interface for fungible tokens on Ethereum. TAXA follows this standard but overrides the transfer functions to make the token non-transferable.

### Finalization

The process of closing a voting round and recording results on-chain. Permissionless — anyone can call `finalize()` after the vote deadline. Emits `ProjectResult` events with each project's QV vote share.

### Gas

The unit of computational effort on Ethereum. Every transaction costs gas, paid in ETH.

### Governance

On-chain decision-making by token holders. In this system, citizens vote on budget allocation for public projects.

### Mint

Creating new TAXA tokens. Only the admin can mint, and minting represents verified off-chain tax payments being converted to on-chain voting power.

### Non-Transferable

TAXA tokens cannot be moved between wallets. `transfer()` and `transferFrom()` always revert. Only minting and burning are allowed.

### Phase

A stage in the round lifecycle: **Idle** (no round), **Voting** (active round), **Finalized** (results recorded), **Cancelled** (round aborted).

### Project

A public initiative (e.g., Roads, Schools, Healthcare) registered in the system that citizens can vote for. Managed through timelocked proposals.

### Proposal

A pending request to add or deactivate a project. Subject to a 2-day timelock before execution. Admin proposes; anyone can execute after the delay.

### Quadratic Voting (QV)

A voting mechanism where vote weight = `sqrt(tokens)`. Spending `c` tokens on a project gives `sqrt(c)` votes. This compresses wealth-based dominance: doubling your tokens gives ~41% more votes, not 100%.

### Reclaim

Re-minting tokens that were burned during a cancelled round. Users call `reclaimTokens(roundId)` to recover their voting power.

### Round

A single voting cycle. Admin starts it with a deadline. Citizens vote. Round ends via finalization or cancellation. Multiple rounds can occur sequentially.

### Smart Contract

A program deployed to and executed on a blockchain. Immutable after deployment. Executes automatically when called.

### TAXA

The non-transferable ERC-20 governance token. Represents voting power derived from off-chain tax payments. Burned when used for voting.

### Testnet

A blockchain network for testing. Uses tokens with no real value. This project uses the **Sepolia** testnet.

### Timelock

A mandatory delay before an action takes effect. In this system, adding or removing projects requires a 2-day wait, giving citizens time to notice the change.

### Wallet

An Ethereum address controlled by a private key. Can be a citizen's personal wallet (MetaMask), a project identifier address, or the admin address.
