# SmartTaxAllocation Contract Documentation

## Purpose

SmartTaxAllocation is the governance contract. It manages voting rounds, project registration (with timelock), Quadratic Voting, token burning, and result calculation. The on-chain output is each project's share of total QV votes — actual budget distribution happens off-chain.

---

## Data Structures

### Enum: Phase

| Value | Description |
|---|---|
| `Idle` | No active round. Waiting for admin to start one. |
| `Voting` | A round is active. Citizens can allocate tokens to projects. Persists after `voteEnd` until finalized or cancelled. |
| `Finalized` | Round finalized. Results are on-chain. |
| `Cancelled` | Round cancelled by admin. Users can reclaim tokens. |

### Enum: ProposalType

| Value | Description |
|---|---|
| `AddProject` | Proposal to add a new project. |
| `DeactivateProject` | Proposal to deactivate an existing project. |

### Struct: Round

| Field | Type | Description |
|---|---|---|
| `voteEnd` | `uint256` | Unix timestamp when voting closes. |
| `totalQVVotes` | `uint256` | Sum of all QV vote weights in this round. |
| `finalized` | `bool` | Whether the round has been finalized. |
| `cancelled` | `bool` | Whether the round was cancelled. |

### Struct: Project

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Human-readable project name. |
| `wallet` | `address` | Address representing this project (for identification). |
| `active` | `bool` | Whether the project can receive votes. |

### Struct: Proposal

| Field | Type | Description |
|---|---|---|
| `pType` | `ProposalType` | Add or Deactivate. |
| `name` | `string` | Project name (for AddProject). |
| `wallet` | `address` | Project wallet (for AddProject). |
| `projectId` | `uint256` | Project index (for DeactivateProject). |
| `executeAfter` | `uint256` | Timestamp after which the proposal can be executed. |
| `executed` | `bool` | Whether the proposal has been executed. |
| `cancelled` | `bool` | Whether the proposal was cancelled by admin. |

---

## Constants

| Constant | Value | Description |
|---|---|---|
| `TIMELOCK_DELAY` | `2 days` | Mandatory delay before project proposals can be executed. |
| `MIN_VOTING_DURATION` | `1 hours` | Minimum length of a voting round. |

---

## Phase System

```
Idle --> Voting --> Finalized
                \-> Cancelled --> (Idle for next round)
```

### getCurrentPhase()

1. If `currentRound == 0`, return `Idle`.
2. If round is cancelled, return `Cancelled`.
3. If round is finalized, return `Finalized`.
4. Otherwise, return `Voting` (even after `voteEnd`, until resolved).

---

## Project Management (Timelocked)

All project changes go through a transparent 2-day timelock:

1. **Admin proposes** → `proposeAddProject()` or `proposeDeactivateProject()`
2. **Wait 2 days** → timelock delay
3. **Anyone executes** → `executeProposal()` (permissionless after delay)
4. **Admin can cancel** → `cancelProposal()` (before execution)

Proposals cannot be executed during an active voting round (Phase.Voting).

---

## Voting (Quadratic Voting)

### allocateVotes(projectId, tokenAmount)

Citizens allocate TAXA tokens to projects they support:

1. Tokens are **burned immediately** from the voter's wallet.
2. QV weight is calculated: `weight = floor(sqrt(totalTokensForThisProject / 1e18))`.
3. Users can allocate to **multiple projects** and **top up** existing allocations.
4. Each top-up recalculates the QV weight correctly (delta-based update).

**QV Formula:**

```
voiceCredits  = TAXA tokens allocated (in whole tokens)
voteWeight    = floor(sqrt(voiceCredits))
```

**Example:** Alice has 10,000 TAXA:
- Allocates 5,000 to Roads → `sqrt(5000)` = 70 QV votes
- Allocates 3,000 to Schools → `sqrt(3000)` = 54 QV votes
- Allocates 2,000 to Healthcare → `sqrt(2000)` = 44 QV votes

vs. putting all on Roads:
- 10,000 to Roads → `sqrt(10000)` = 100 QV votes

QV incentivizes spreading votes across multiple projects.

---

## Finalization

After `voteEnd` passes, anyone can call `finalize()`:

1. Marks the round as finalized.
2. Emits a `ProjectResult` event for each project that received votes.
3. The event includes `(roundId, projectId, qvVotes, totalQVVotes)`.
4. Off-chain systems use these to calculate budget percentages:
   ```
   projectBudgetShare = projectQVVotes / totalQVVotes * 100%
   ```

**No tokens are distributed on-chain.** The contract is governance-only.

---

## Cancellation and Reclaim

Admin can cancel any active round via `cancelRound()`. Users who allocated tokens can reclaim them via `reclaimTokens(roundId)`, which re-mints the exact amount burned during voting.

---

## Events

| Event | Parameters | When |
|---|---|---|
| `AdminTransferred` | previousAdmin, newAdmin | Admin role transferred |
| `RoundStarted` | roundId, voteEnd | New round started |
| `RoundCancelled` | roundId | Round cancelled |
| `RoundFinalized` | roundId, totalQVVotes | Round finalized |
| `ProjectAdded` | projectId, name, wallet | Project added via proposal |
| `ProjectDeactivated` | projectId | Project deactivated via proposal |
| `ProposalCreated` | proposalId, pType, executeAfter | New proposal |
| `ProposalExecuted` | proposalId | Proposal executed |
| `ProposalCancelled` | proposalId | Proposal cancelled |
| `VotesAllocated` | roundId, voter, projectId, tokens, newQVWeight | Votes allocated |
| `TokensReclaimed` | roundId, user, amount | Tokens reclaimed from cancelled round |
| `ProjectResult` | roundId, projectId, qvVotes, totalQVVotes | Per-project result at finalization |

---

## View Helpers

| Function | Returns |
|---|---|
| `getCurrentPhase()` | Current phase enum |
| `getProjects()` | All projects |
| `getProjectCount()` | Number of projects |
| `getActiveProjectCount()` | Number of active projects |
| `getRound(roundId)` | Round struct |
| `getProjectVotes(roundId, projectId)` | QV votes for a project in a round |
| `getUserAllocation(roundId, user, projectId)` | Tokens a user allocated to a project |
| `getUserTotalAllocated(roundId, user)` | Total tokens a user allocated in a round |
| `getProposal(proposalId)` | Proposal struct |
| `getProposalCount()` | Number of proposals |
| `qvWeight(tokenAmountWei)` | QV weight for a given token amount |
| `sqrt(x)` | Integer square root |
