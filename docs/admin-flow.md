# Admin Flow: System Administration Guide

## Overview

The admin is responsible for: deploying contracts, managing projects (through timelock), verifying tax payments, minting TAXA tokens, and managing voting round lifecycle.

---

## Initial Setup

### Step 1: Deploy Contracts

Deploy in order:
1. `TaxaToken(adminAddress)` — admin becomes the owner.
2. `SmartTaxAllocation(taxaTokenAddress)` — admin becomes the contract admin.
3. Call `token.setAllocationContract(allocationAddress)` — authorizes burn/re-mint.

### Step 2: Register Initial Projects

All project changes go through the 2-day timelock:

```
// Propose projects
smartTaxAllocation.proposeAddProject("Roads", roadsWalletAddress)
smartTaxAllocation.proposeAddProject("Schools", schoolsWalletAddress)
smartTaxAllocation.proposeAddProject("Healthcare", healthcareWalletAddress)

// Wait 2 days...

// Execute proposals (anyone can call after timelock)
smartTaxAllocation.executeProposal(0)
smartTaxAllocation.executeProposal(1)
smartTaxAllocation.executeProposal(2)
```

---

## Ongoing Operations

### Step 3: Verify Tax Payments and Mint TAXA

When a citizen's tax payment is verified off-chain:

```
taxaToken.mint(citizenAddress, taxAmount * 1e18)
```

The amount minted should correspond to the tax amount paid. This is the admin's most important responsibility — maintaining a fair and accurate mapping between off-chain payments and on-chain voting power.

### Step 4: Start a Voting Round

```
smartTaxAllocation.startRound(voteEndTimestamp)
```

- `voteEndTimestamp` — Unix timestamp when voting closes. Must be at least 1 hour in the future.
- Requires at least one active project.
- Previous round must be finalized or cancelled.

### Step 5: Monitor the Round

During voting, monitor participation:

```
smartTaxAllocation.getRound(roundId)                           // round overview
smartTaxAllocation.getProjectVotes(roundId, projectId)         // per-project QV votes
smartTaxAllocation.getUserTotalAllocated(roundId, userAddress)  // per-user allocation
```

### Step 6: Finalization

After `voteEnd`, anyone can finalize. The admin doesn't need to do this, but can:

```
smartTaxAllocation.finalize()
```

Results are emitted as `ProjectResult` events containing each project's QV vote share.

### Step 7: Distribute Budget Off-Chain

Based on the on-chain results, distribute the actual budget:

```
Project budget share = projectQVVotes / totalQVVotes * totalBudget
```

### Step 8: Start Next Round

Mint new TAXA from new tax payments and start another round. The cycle repeats.

---

## Project Management

### Adding a Project

```
smartTaxAllocation.proposeAddProject("New Project", walletAddress)
// Wait 2 days
smartTaxAllocation.executeProposal(proposalId)  // anyone can call
```

### Deactivating a Project

```
smartTaxAllocation.proposeDeactivateProject(projectId)
// Wait 2 days
smartTaxAllocation.executeProposal(proposalId)  // anyone can call
```

### Cancelling a Proposal

```
smartTaxAllocation.cancelProposal(proposalId)  // admin only, before execution
```

**Note:** Proposals cannot be executed during an active voting round. Wait until the round is finalized or cancelled.

---

## Emergency: Cancel a Round

If something goes wrong, the admin can cancel the current round:

```
smartTaxAllocation.cancelRound()
```

After cancellation, citizens reclaim their burned tokens individually via `reclaimTokens(roundId)`.

---

## Admin Transfer

To transfer admin rights:

```
smartTaxAllocation.transferAdmin(newAdminAddress)
```

This is immediate and irreversible. The old admin loses all privileges.

For the token contract, transfer ownership via:

```
taxaToken.transferOwnership(newOwnerAddress)
```

---

## Admin Powers Summary

| Function | When Allowed | Restrictions |
|---|---|---|
| `mint` (token) | Any time | Only owner |
| `proposeAddProject` | Any time | Name and wallet required |
| `proposeDeactivateProject` | Any time | Project must be active |
| `cancelProposal` | Before execution | Admin only |
| `startRound` | Previous round resolved | Min 1hr voting, active projects needed |
| `cancelRound` | During active round | Admin only |
| `transferAdmin` | Any time | Irreversible |

| Permissionless Function | Who Can Call | When |
|---|---|---|
| `executeProposal` | Anyone | After timelock, not during voting |
| `finalize` | Anyone | After voteEnd |
| `reclaimTokens` | User who voted | After round cancelled |
| `allocateVotes` | Any TAXA holder | During voting phase |
