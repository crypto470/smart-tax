# Deployment Guide

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed (`foundryup`)
- MetaMask or compatible wallet
- Sepolia ETH for testnet deployment (from a faucet)

### Environment Setup

Create a `.env` file in the project root (do NOT commit this):

```
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

---

## Deployment Order

1. Deploy TaxaToken (admin = deployer)
2. Deploy SmartTaxAllocation (admin = deployer)
3. Call `token.setAllocationContract(allocationAddress)`
4. Propose initial projects
5. **Wait 2 days** (timelock)
6. Execute project proposals

Steps 1-4 are handled by the deploy script. Steps 5-6 require separate transactions after the timelock.

---

## Local Deployment (Anvil)

### Step 1: Start Anvil

```bash
anvil
```

### Step 2: Deploy

```bash
forge script script/Deploy.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

Note the deployed addresses from the output.

### Step 3: Execute Project Proposals (after timelock)

On Anvil you can fast-forward time:

```bash
# Advance 2 days + 1 second
cast rpc anvil_increaseTime 172801 --rpc-url http://127.0.0.1:8545
cast rpc anvil_mine --rpc-url http://127.0.0.1:8545

# Execute proposals
cast send <ALLOC_ADDR> "executeProposal(uint256)" 0 --rpc-url http://127.0.0.1:8545 --private-key <KEY>
cast send <ALLOC_ADDR> "executeProposal(uint256)" 1 --rpc-url http://127.0.0.1:8545 --private-key <KEY>
cast send <ALLOC_ADDR> "executeProposal(uint256)" 2 --rpc-url http://127.0.0.1:8545 --private-key <KEY>
```

### Step 4: Verify

```bash
cast call <TOKEN_ADDR> "name()(string)" --rpc-url http://127.0.0.1:8545
cast call <ALLOC_ADDR> "admin()(address)" --rpc-url http://127.0.0.1:8545
cast call <ALLOC_ADDR> "getProjectCount()(uint256)" --rpc-url http://127.0.0.1:8545
```

---

## Testnet Deployment (Sepolia)

```bash
source .env

# Deploy
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

After 2 days, execute the project proposals:

```bash
cast send <ALLOC_ADDR> "executeProposal(uint256)" 0 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send <ALLOC_ADDR> "executeProposal(uint256)" 1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send <ALLOC_ADDR> "executeProposal(uint256)" 2 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

---

## Deployment via Remix

1. Open [remix.ethereum.org](https://remix.ethereum.org).
2. Create `TaxaToken.sol` and `SmartTaxAllocation.sol` with the contract source code.
3. Add OpenZeppelin imports (use Remix npm or GitHub URLs).
4. Compile with Solidity ^0.8.19.
5. Deploy `TaxaToken` with your address as the `_owner` parameter.
6. Deploy `SmartTaxAllocation` with the TaxaToken address.
7. Call `setAllocationContract` on TaxaToken with the SmartTaxAllocation address.
8. Propose projects via `proposeAddProject`.
9. Wait 2 days. Execute via `executeProposal`.

---

## Constructor Arguments

| Contract | Parameter | Type | Description |
|---|---|---|---|
| TaxaToken | `_owner` | address | Admin who can mint tokens |
| SmartTaxAllocation | `_taxaToken` | address | Deployed TaxaToken address |

---

## Post-Deployment Checklist

- [ ] TaxaToken deployed and address recorded
- [ ] SmartTaxAllocation deployed with correct token address
- [ ] `setAllocationContract()` called on token
- [ ] Admin verified on both contracts
- [ ] Project proposals created
- [ ] Timelock waited (2 days)
- [ ] Project proposals executed
- [ ] At least one active project confirmed
- [ ] Contracts verified on Etherscan (if testnet/mainnet)
