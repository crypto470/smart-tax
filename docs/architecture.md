# System Architecture

## Overview

The system consists of two on-chain smart contracts and off-chain actors:

```
+------------------+         +------------------+
|                  |         |                  |
|   Admin Wallet   |         |  Citizen Wallet  |
|                  |         |  (MetaMask)      |
+--------+---------+         +--------+---------+
         |                            |
         | mint()                     | allocateVotes()
         | startRound()               | reclaimTokens()
         | cancelRound()              |
         | proposeAddProject()        |
         | proposeDeactivateProject() |
         | cancelProposal()           |        Anyone: executeProposal()
         | transferAdmin()            |        Anyone: finalize()
         v                            v
+--------+----------------------------+---------+
|                                               |
|            Ethereum Blockchain (EVM)          |
|          (Anvil / Sepolia / Mainnet)          |
|                                               |
|   +--------------------+   +-----------------+|
|   |    TaxaToken        |   | SmartTaxAlloc-  ||
|   |    (ERC-20)         |   | ation           ||
|   |                     |   |                 ||
|   | - mint()      [owner]<--+ - startRound()  ||
|   | - burn()     [alloc]|   | - allocateVotes||
|   | - mintFromAlloc     |   | - finalize()   ||
|   |        [alloc]      |   | - cancelRound()||
|   |                     |   | - reclaimTokens||
|   | Non-transferable    |   | - propose*()   ||
|   | Mint + Burn only    |   | - execute*()   ||
|   +--------------------+   +-----------------+|
|                                               |
+-----------------------------------------------+
```

## Contract Relationships

**TaxaToken depends on SmartTaxAllocation** (via `allocationContract` address). The allocation contract is authorized to burn tokens (when votes are cast) and re-mint tokens (when cancelled rounds are reclaimed).

**SmartTaxAllocation depends on TaxaToken** (via constructor parameter). It calls `burn()` and `mintFromAllocation()` on the token contract.

This is a **bidirectional dependency**, unlike the old design where only the allocation contract depended on the token. Both contracts must be deployed and linked together.

## Data Flow

```
1. Admin verifies off-chain tax payment
2. Admin mints TAXA to taxpayer          :  Admin --> TaxaToken.mint()
3. Admin starts a voting round           :  Admin --> SmartTaxAllocation.startRound()
4. Citizen allocates tokens to projects  :  Citizen --> SmartTaxAllocation.allocateVotes()
     --> SmartTaxAllocation calls         :  SmartTaxAllocation --> TaxaToken.burn()
5. Anyone finalizes the round            :  Anyone --> SmartTaxAllocation.finalize()
     --> Results emitted as events        :  SmartTaxAllocation emits ProjectResult events
6. Off-chain: budget distributed based on QV percentages
```

If a round is cancelled:
```
7. Admin cancels round                   :  Admin --> SmartTaxAllocation.cancelRound()
8. Users reclaim burned tokens           :  User --> SmartTaxAllocation.reclaimTokens()
     --> SmartTaxAllocation calls         :  SmartTaxAllocation --> TaxaToken.mintFromAllocation()
```

## Design Decisions

### Why two contracts?

Separation of concerns. The token contract handles the token lifecycle (mint, burn, non-transferability). The allocation contract handles governance logic (rounds, voting, project management). Either could be upgraded independently.

### Why non-transferable?

TAXA represents voting power from tax payments, not tradeable value. Allowing transfers would let people buy/sell votes, undermining the governance model.

### Why burn-on-vote instead of burn-on-finalize?

Burning immediately when votes are cast is simpler — no need to track "pending burns" or iterate over voters at finalization. The tradeoff is that cancelled rounds require a re-mint mechanism.

### Why a 2-day timelock for projects?

Prevents the admin from silently adding or removing projects right before a vote. The delay gives citizens time to notice and react. The execution is permissionless (anyone can call it after the delay), adding transparency.

## Limitations

- **Single admin.** The system relies on one address for minting and round management. A compromised admin could mint tokens arbitrarily.
- **No Sybil resistance.** One person could use multiple wallets to receive minted tokens.
- **No quorum.** A round with very low participation can still be finalized.
- **Off-chain budget distribution.** The on-chain result is advisory — actual money distribution requires off-chain trust.
- **No upgradability.** Contracts are immutable after deployment.
- **Gas scales with projects.** Finalization iterates over all projects.
