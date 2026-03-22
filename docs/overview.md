# Project Overview

## Executive Summary

The **Blockchain-Based Decentralized System for Smart Tax Allocation** is a governance system that gives citizens a direct voice in how their tax money is spent. It connects off-chain tax payments to on-chain voting using non-transferable governance tokens and Quadratic Voting.

The system is built as a proof-of-concept MVP using Solidity and Foundry, demonstrating how smart contracts can bring transparency and accountability to public budget allocation.

## How It Works

1. **Off-chain tax payment.** Citizens pay their taxes through traditional channels.
2. **Admin mints TAXA.** After verifying the payment, the admin mints TAXA governance tokens to the taxpayer's wallet. The token amount corresponds to the tax amount paid.
3. **Citizens vote.** During a voting round, citizens allocate their TAXA tokens to public projects they support. Tokens are burned immediately when allocated. Vote weight follows the Quadratic Voting formula: `weight = floor(sqrt(tokens))`.
4. **Round finalization.** After the voting deadline, anyone can finalize the round. The on-chain result is each project's share of total QV votes — this determines the budget allocation.
5. **Off-chain budget distribution.** The government distributes the actual budget based on the on-chain vote results.
6. **Cycle repeats.** New tax payments → new TAXA minted → new voting round.

## Why This Approach

### Why governance tokens instead of depositing real funds?

Using non-transferable tokens that represent voting power (not money) has several advantages:

- **Prevents speculation.** TAXA cannot be traded, bought, or sold. Your voting power comes only from your tax contribution.
- **Clean lifecycle.** Tokens are burned after each round. No accumulation of old voting power.
- **Separation of concerns.** Money flows through existing government channels; blockchain handles only the governance decision.

### Why Quadratic Voting?

Under linear voting, a citizen who paid 10,000 in taxes has 100x the influence of someone who paid 100. Under QV, the ratio is `sqrt(10000)/sqrt(100) = 100/10 = 10x`. This compresses wealth-based dominance while still rewarding larger contributors.

### Why blockchain?

- **Transparency.** Every vote is recorded on a public ledger.
- **Immutability.** Vote results cannot be altered after the fact.
- **Permissionless finalization.** Anyone can trigger result calculation — no single point of control.
- **Auditability.** Complete history of every round is permanently available.

## Core Design Principles

1. **Non-transferable tokens.** TAXA cannot move between wallets. Only mint and burn.
2. **Burn after use.** Tokens are burned when votes are cast. No reuse across rounds.
3. **Timelocked project management.** Adding or removing projects has a mandatory 2-day delay for transparency.
4. **Off-chain simplicity.** Tax verification is handled by a trusted admin. The smart contract does not attempt to verify real-world payments.
5. **MVP scope.** The system is designed to be buildable, testable, and demonstrable as a student project while preserving the core governance concepts.
