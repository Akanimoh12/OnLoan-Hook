# Deployment Guide

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Foundry** | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| **Unichain Sepolia ETH** | Get from [faucet.unichain.org](https://faucet.unichain.org) or bridge from Sepolia |
| **Reactive Kopli ETH** | Get from [Reactive Network faucet](https://docs.reactive.network/kopli-testnet) |
| **Deployer wallet** | Any EOA with testnet ETH on both chains |

## Chain Reference

| Chain | Chain ID | RPC URL |
|-------|----------|---------|
| Unichain Sepolia | 1301 | `https://sepolia.unichain.org` |
| Reactive Kopli | 5318008 | `https://kopli-rpc.reactive.network` |

## Deployment Order

The protocol spans two chains. Contracts must be deployed in this order:

```
Unichain Sepolia                    Reactive Network Kopli
─────────────────                   ──────────────────────
1. Mock Tokens (if needed)
2. Core Protocol (DeployOnLoan)
3. RiskEngine
                                    4. LiquidationRSC
                                    5. CrossChainCollateralWatcher
                                    6. Configure RSC subscriptions
```

## Step-by-Step

### 0. Setup Environment

```bash
cp .env.example .env
# Edit .env — fill in DEPLOYER_PRIVATE_KEY
```

### 1. Deploy Mock Tokens (skip if tokens already exist)

```bash
make deploy-tokens
```

Copy the output addresses into `.env`:
```
WETH_ADDRESS=0x...
WBTC_ADDRESS=0x...
```

### 2. Deploy Core Protocol

Requires `POOL_MANAGER_ADDRESS` in `.env`. The canonical Uniswap v4 PoolManager is:
```
POOL_MANAGER_ADDRESS=0x000000000004444c5dc75cB358380D2e3dE08A90
```

> **Important:** Verify that the PoolManager is deployed on Unichain Sepolia before proceeding.
> Check via: `cast code 0x000000000004444c5dc75cB358380D2e3dE08A90 --rpc-url $UNICHAIN_TESTNET_RPC_URL`
> If empty, Uniswap v4 may not yet be on Unichain Sepolia — use Ethereum Sepolia instead.

```bash
make deploy-testnet
```

This deploys all core contracts and writes addresses to `deployments/addresses.json`. Copy the addresses into `.env`:
```
ONLOAN_HOOK_ADDRESS=0x...
PRICE_ORACLE_ADDRESS=0x...
LOAN_MANAGER_ADDRESS=0x...
LIQUIDATION_ENGINE_ADDRESS=0x...
COLLATERAL_MANAGER_ADDRESS=0x...
LENDING_POOL_ADDRESS=0x...
```

### 3. Deploy RiskEngine (on Unichain)

```bash
make deploy-risk
```

### 4. Deploy RSCs (on Reactive Network)

Ensure all core protocol addresses are in `.env`, then:

```bash
make deploy-rsc
```

This deploys:
- **LiquidationRSC** — subscribes to PriceUpdated, LoanCreated, LoanFullyRepaid, LoanLiquidated, CollateralDeposited
- **CrossChainCollateralWatcher** — monitors cross-chain Transfer events

Addresses are written to `deployments/reactive-addresses.json`.

### 5. Export All Addresses

```bash
make export-addresses
```

Creates `deployments/all-addresses.json` — a single file with every contract address for frontend integration.

## Verification

After deployment, verify contracts are working:

```bash
# Check core contracts on Unichain
cast call $ONLOAN_HOOK_ADDRESS "priceOracle()(address)" --rpc-url $UNICHAIN_TESTNET_RPC_URL

# Check RSC on Reactive Network
cast call $LIQUIDATION_RSC_ADDRESS "ORIGIN_CHAIN_ID()(uint256)" --rpc-url $REACTIVE_RPC_URL

# Check RiskEngine
cast call $RISK_ENGINE_ADDRESS "warningThreshold()(uint256)" --rpc-url $UNICHAIN_TESTNET_RPC_URL
```

## Frontend Integration

After deployment, the frontend needs these environment variables:
```
VITE_UNICHAIN_RPC_URL=https://sepolia.unichain.org
VITE_CHAIN_ID=1301
VITE_ONLOAN_HOOK_ADDRESS=<from deployments/addresses.json>
VITE_WALLETCONNECT_ID=<from cloud.walletconnect.com>
```

Or import `deployments/all-addresses.json` directly in the frontend code.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Hook address mismatch` | CREATE2 mining failed — try different salt or check PoolManager address |
| `StalePrice` on reads | Call `priceOracle.setPrice()` to set initial prices after deployment |
| RSC not triggering | Fund the RSC with ETH for callback gas: `cast send $RSC_ADDRESS --value 0.1ether` |
| `Insufficient funds` on RSC | RSCs need ETH to pay for cross-chain callbacks |
