# Testing Documentation

## Overview

The test suite contains **93 tests** covering both contracts:

| Contract | Tests | Description |
|---|---|---|
| TaxaToken | 22 | Minting, burning, non-transferability, access control |
| SmartTaxAllocation | 71 | Rounds, QV voting, timelock, finalization, reclaim, multi-round |

## Running Tests

```bash
forge test                # Run all tests
forge test -vvv           # Verbose (shows traces for failures)
forge test -vvvv          # Maximum verbosity
forge test --gas-report   # Gas usage per function
forge coverage            # Coverage report
```

### Run specific tests:

```bash
forge test --match-path test/TaxaToken.t.sol
forge test --match-test test_allocateVotes
```

---

## Test Categories

### TaxaToken Tests (22)

| Category | Count | What Is Tested |
|---|---|---|
| Metadata | 4 | Name, symbol, decimals, initial supply = 0 |
| Ownership | 1 | Owner set correctly |
| setAllocationContract | 3 | Set, revert on non-owner, revert on zero address |
| Minting | 5 | Mint, multiple mints, revert on non-owner/zero-addr/zero-amount |
| Burning | 4 | Burn, revert on non-alloc/owner/insufficient-balance |
| mintFromAllocation | 2 | Re-mint, revert on non-alloc |
| Non-transferability | 2 | transfer reverts, transferFrom reverts |
| Approve | 1 | Approve still works (interface compat) |

### SmartTaxAllocation Tests (71)

| Category | Count | What Is Tested |
|---|---|---|
| Constructor | 2 | Token stored, admin set, revert on zero address |
| transferAdmin | 4 | Transfer, revert on non-admin/zero/same |
| Timelock proposals | 14 | Propose add/deactivate, execute after timelock, revert before timelock, revert during voting, cancel, revert on cancelled/executed, permissionless execution |
| startRound | 7 | Start, revert on non-admin/short-window/no-projects/unresolved, after finalization/cancellation |
| allocateVotes | 11 | Allocate, multi-project, same-project-twice, QV weight correct, revert on no-round/ended/invalid/inactive/zero/insufficient/resolved |
| finalize | 7 | Finalize, permissionless, tokens burned permanently, revert on open/no-votes/resolved/no-round |
| cancelRound + reclaim | 9 | Cancel, cancel after votes, reclaim, revert on non-admin/resolved/no-round/non-cancelled/nothing/double |
| QV math | 2 | qvWeight, sqrt |
| View helpers | 4 | getProjects, getProjectCount, getActiveProjectCount, constants |
| Phase transitions | 5 | Idle, voting, past-deadline, finalized, cancelled |
| Multi-round | 2 | Full flow, after cancel |
| Budget share | 1 | Off-chain percentage verification |

---

## Key Test Scenarios

### Burn-on-Vote

Tests verify that tokens are burned immediately when `allocateVotes` is called, not at finalization. The user's balance decreases at vote time.

### QV Weight Correctness

When a user allocates to the same project twice, the QV weight is correctly recalculated:
- First allocation: 100 TAXA → `sqrt(100)` = 10 QV votes
- Second allocation: 300 TAXA more → total 400 TAXA → `sqrt(400)` = 20 QV votes
- Net increase: 10 QV votes (not `sqrt(300)` = 17)

### Timelock Enforcement

- Proposals cannot be executed before the 2-day delay.
- Proposals cannot be executed during an active voting round.
- Anyone (not just admin) can execute after the delay.
- Admin can cancel before execution.

### Reclaim on Cancellation

After a round is cancelled, users get their exact token amount re-minted. Verified with balance assertions.

### Multi-Round

Tests verify that round data is preserved across multiple rounds and that fresh tokens are needed for each round.

---

## Coverage Targets

| Metric | Target |
|---|---|
| Line | > 95% |
| Branch | > 90% |
| Function | 100% |
