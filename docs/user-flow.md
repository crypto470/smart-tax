# User Flow: Citizen / Voter Journey

## Overview

As a citizen, your journey is: pay taxes off-chain → receive TAXA tokens → vote on budget projects → tokens are burned → results determine budget allocation.

You do **not** deposit tokens. You do **not** withdraw funds. TAXA is governance power, not money.

---

## Prerequisites

1. **TAXA tokens** in your wallet (minted by admin after your tax payment is verified).
2. **MetaMask** (or compatible wallet) connected to the correct network.
3. **SmartTaxAllocation contract address** (provided by admin).

---

## Step-by-Step Flow

### Step 1: Receive TAXA Tokens

After you pay your taxes through normal channels, the system admin verifies your payment and mints TAXA tokens to your wallet address. The number of tokens corresponds to your tax contribution.

Check your balance:
```
taxaToken.balanceOf(yourAddress)
```

### Step 2: Wait for a Voting Round

The admin starts voting rounds periodically. Each round has a deadline (`voteEnd`). You can check the current round status:
```
smartTaxAllocation.getCurrentPhase()    // 0=Idle, 1=Voting, 2=Finalized, 3=Cancelled
smartTaxAllocation.getRound(roundId)    // returns voteEnd, totalQVVotes, etc.
```

### Step 3: View Available Projects

See which projects you can vote for:
```
smartTaxAllocation.getProjects()
```

This returns a list of projects with names, wallet addresses, and active status. Only active projects can receive votes.

### Step 4: Allocate Your Votes

During the voting phase (before `voteEnd`), allocate your TAXA tokens to projects:

```
smartTaxAllocation.allocateVotes(projectId, tokenAmount)
```

**Key details:**
- Your tokens are **burned immediately** when you allocate. This is by design — you're spending your voting power.
- **QV weight** = `floor(sqrt(tokenAmount / 1e18))`. Example: 400 TAXA → 20 QV votes.
- You can **split tokens across multiple projects** by calling `allocateVotes` multiple times with different project IDs.
- You can **top up** an existing allocation to the same project. The QV weight is recalculated correctly.
- You don't have to allocate all your tokens. Unallocated tokens remain in your wallet for future rounds.

**Example:**
```
// Alice has 10,000 TAXA
allocateVotes(0, 5000e18)   // Roads: sqrt(5000) = 70 QV votes, 5000 TAXA burned
allocateVotes(1, 3000e18)   // Schools: sqrt(3000) = 54 QV votes, 3000 TAXA burned
allocateVotes(2, 2000e18)   // Healthcare: sqrt(2000) = 44 QV votes, 2000 TAXA burned
// Alice now has 0 TAXA remaining
```

### Step 5: Wait for Finalization

After `voteEnd` passes, anyone can finalize the round:
```
smartTaxAllocation.finalize()
```

You can call this yourself, or wait for someone else to do it. It's permissionless.

### Step 6: View Results

After finalization, check each project's share of the vote:
```
smartTaxAllocation.getProjectVotes(roundId, projectId)   // QV votes for a project
smartTaxAllocation.getRound(roundId)                      // total QV votes
```

Budget percentage for a project = `projectQVVotes / totalQVVotes * 100%`.

The actual budget distribution happens off-chain based on these on-chain results.

---

## If the Round Is Cancelled

The admin can cancel a round at any time before finalization. If your tokens were burned during voting, you can reclaim them:

```
smartTaxAllocation.reclaimTokens(roundId)
```

This re-mints the exact amount of TAXA you allocated in the cancelled round. You can use these tokens in future rounds.

---

## Summary Diagram

```
+----------------------+
|  Pay taxes off-chain |
+----------+-----------+
           |
           v
+----------+-----------+
|  Admin mints TAXA    |
|  to your wallet      |
+----------+-----------+
           |
           v
+----------+-----------+
|  allocateVotes()     |
|  (tokens burned)     |
|  Split across        |
|  multiple projects   |
+----------+-----------+
           |
           |  voteEnd passes
           v
+----------+-----------+
|  finalize()          |
|  (permissionless)    |
+----------+-----------+
           |
           v
+----------+-----------+
|  View results        |
|  Budget % on-chain   |
+----------------------+

--- If Cancelled ---

+----------------------+
|  reclaimTokens()     |
|  (tokens re-minted)  |
+----------------------+
```
