# Blockchain-Based Decentralized System for Smart Tax Allocation

## Project Description

This project implements a blockchain-based governance system for transparent tax budget allocation. Citizens pay taxes off-chain; after verification, an admin mints non-transferable TAXA governance tokens to their wallets. Citizens then use these tokens to vote — via **Quadratic Voting (QV)** — on how the public budget should be distributed among registered projects. After a voting round, the on-chain results determine each project's budget share, and all used tokens are permanently burned. New voting power comes only from future tax payments.

The platform consists of two Solidity smart contracts: **TaxaToken** (a non-transferable ERC-20) and **SmartTaxAllocation** (a governance contract with QV voting, timelocked project management, and burn-on-vote mechanics).

## Key Concepts

- **TAXA is voting power, not currency.** Tokens cannot be transferred between users. They can only be minted by admin and burned by the governance contract.
- **Quadratic Voting (QV)** compresses wealth-based influence: `voteWeight = floor(sqrt(tokens))`. Doubling your tokens gives ~41% more votes, not 100%.
- **Burn-on-vote.** Tokens are burned the moment a user allocates them to a project. No reuse across rounds.
- **Budget allocation is governance output.** The on-chain result is each project's share of total QV votes. Actual money distribution happens off-chain.
- **Timelocked project management.** Adding or removing projects requires a 2-day transparent delay.

## Contracts Overview

| Contract | File | Description |
|---|---|---|
| **TaxaToken** | `src/TaxaToken.sol` | Non-transferable ERC-20. Admin mints after tax verification. Allocation contract burns on vote, re-mints on cancelled-round reclaim. |
| **SmartTaxAllocation** | `src/SmartTaxAllocation.sol` | Governance contract: voting rounds, QV math, multi-project allocation, timelocked project management, burn-on-vote, reclaim for cancelled rounds. |

## Tech Stack

| Technology | Purpose |
|---|---|
| Solidity ^0.8.19 | Smart contract language |
| Foundry (forge, cast, anvil) | Development, testing, deployment |
| OpenZeppelin Contracts v5 | Audited ERC-20 and Ownable |
| Sepolia Testnet | Public test network |

## Project Structure

```
smart-tax/
├── foundry.toml
├── remappings.txt
├── README.md
├── docs/
│   ├── overview.md
│   ├── architecture.md
│   ├── smart-tax-allocation.md
│   ├── taxa-token.md
│   ├── user-flow.md
│   ├── admin-flow.md
│   ├── deployment.md
│   ├── testing.md
│   └── glossary.md
├── src/
│   ├── TaxaToken.sol
│   └── SmartTaxAllocation.sol
├── test/
│   ├── TaxaToken.t.sol
│   └── SmartTaxAllocation.t.sol
├── script/
│   └── Deploy.s.sol
└── lib/
    ├── forge-std/
    └── openzeppelin-contracts/
```

## Setup

```bash
git clone <repository-url>
cd smart-tax
forge install
forge build
```

## Testing

```bash
forge test           # Run all 93 tests
forge test -vvv      # Verbose output
forge coverage       # Coverage report
```

## Deployment

```bash
# Local (Anvil)
anvil
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key <KEY>

# After 2 days, execute project proposals:
cast send <ALLOC_ADDR> "executeProposal(uint256)" 0 --rpc-url <RPC> --private-key <KEY>
cast send <ALLOC_ADDR> "executeProposal(uint256)" 1 --rpc-url <RPC> --private-key <KEY>
cast send <ALLOC_ADDR> "executeProposal(uint256)" 2 --rpc-url <RPC> --private-key <KEY>
```

## Example Flow

1. **Deploy** both contracts. Admin sets allocation contract on token.
2. **Propose projects** (Roads, Schools, Healthcare). Wait 2 days. Execute proposals.
3. **Verify taxes off-chain.** Admin mints TAXA to taxpayers: `token.mint(citizen, amount)`.
4. **Start a round:** `allocation.startRound(voteEndTimestamp)`.
5. **Citizens vote:** `allocation.allocateVotes(projectId, tokenAmount)`. Tokens burned immediately.
6. **Finalize:** After `voteEnd`, anyone calls `allocation.finalize()`. Results emitted on-chain.
7. **Off-chain:** Government distributes budget based on on-chain QV percentages.
8. **Next cycle:** Admin mints new TAXA from new tax payments. Start another round.

## Documentation Index

| Document | Description |
|---|---|
| [docs/overview.md](docs/overview.md) | Executive summary and motivation |
| [docs/architecture.md](docs/architecture.md) | System architecture and design decisions |
| [docs/taxa-token.md](docs/taxa-token.md) | Token behavior, non-transferability, mint/burn lifecycle |
| [docs/smart-tax-allocation.md](docs/smart-tax-allocation.md) | Voting, QV, timelock, rounds, and reclaim logic |
| [docs/user-flow.md](docs/user-flow.md) | Step-by-step citizen/voter guide |
| [docs/admin-flow.md](docs/admin-flow.md) | Step-by-step administrator guide |
| [docs/deployment.md](docs/deployment.md) | Deployment via Anvil, Sepolia, and Remix |
| [docs/testing.md](docs/testing.md) | Test suite documentation |
| [docs/glossary.md](docs/glossary.md) | Key term definitions |

## Future Improvements

- **Multisig admin** to decentralize minting and round management.
- **On-chain identity / Sybil resistance** to prevent one person using multiple wallets.
- **Quorum requirements** to ensure minimum participation before finalization.
- **Vote delegation** for liquid democracy.
- **Frontend dashboard** for real-time round status and results.
- **Shorter/configurable timelocks** for different deployment contexts.
- **Historical analytics** via event indexing (The Graph, etc.).

## License

MIT
