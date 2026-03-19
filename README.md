# OnLoan — Hook-Native Lending on Uniswap v4

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.26-363636.svg)](https://soliditylang.org/)
[![Uniswap v4](https://img.shields.io/badge/Uniswap-v4%20Hook-FF007A.svg)](https://docs.uniswap.org/contracts/v4/overview)
[![Reactive Network](https://img.shields.io/badge/Reactive-Network-6C3BF5.svg)](https://reactive.network)
[![Chain](https://img.shields.io/badge/Chain-Unichain%20Sepolia-orange.svg)](https://docs.unichain.org/)

> **Submission for:** Atrium Academy UHI8 Hookathon
> **Sponsor Integration:** Reactive Network
> **Chain:** Unichain Sepolia (Chain ID 1301)

---

## Links

| | |
|---|---|
| **Live App** | [onloan-hook.vercel.app](https://onloan-hook.vercel.app/) |
| **Demo Video** | [Loom](https://www.loom.com/share/demo-video-link) |
| **Pitch Deck** | [Canva](https://www.canva.com/design/DAHETVP5AV4/vYndLA7_qw3bUxRGUtq_zg/view) |
| **GitHub** | [github.com/Akanimoh12/OnLoan-Hook](https://github.com/Akanimoh12/OnLoan-Hook) |

---

## What is OnLoan?

**OnLoan** is the first fully hook-native lending protocol built on Uniswap v4. It embeds a complete lending market — deposits, collateralized borrowing, interest accrual, and liquidation — directly inside a Uniswap v4 pool's lifecycle hooks, so lenders earn **swap fees and lending interest simultaneously** from a single deposit.

Liquidations are handled by **Reactive Smart Contracts (RSCs)** deployed on Reactive Network, which autonomously monitor on-chain health factors across chains and trigger liquidations the moment a position becomes undercollateralized — without any off-chain keeper bots, cron jobs, or centralized infrastructure.

---

## The Problem

Today's DeFi lending and AMM liquidity are completely siloed systems with three structural failures:

**1. Capital Fragmentation**
Liquidity providers must choose: earn swap fees on Uniswap *or* earn interest on Aave/Compound — but never both from the same capital. This forces users to split their assets and actively manage multiple positions.

**2. Keeper-Dependent Liquidations**
Every major lending protocol (Aave, Compound, MorphoBlue) relies on off-chain keeper bots to trigger liquidations. During volatile markets — exactly when liquidations matter most — these bots face gas wars, MEV extraction, and network congestion. Bad debt accumulates when keepers fail.

**3. No Cross-Chain Position Awareness**
Collateral deposited on one chain has zero visibility into price movements observed on other chains. A multi-chain DeFi ecosystem needs cross-chain health monitoring, not just single-chain snapshots.

---

## The Solution

OnLoan solves all three problems through two core innovations:

### Innovation 1 — Hook-Native Lending
By embedding the entire lending lifecycle inside Uniswap v4 hooks, OnLoan eliminates the boundary between AMM liquidity and lending capital:

- Lenders **add liquidity once** to a Uniswap v4 pool. The hook automatically registers their deposit in the lending pool.
- Their capital **simultaneously earns** Uniswap swap fees (from traders) and lending interest (from borrowers).
- Borrowers post WETH or WBTC collateral, then **borrow USDC via a swap** — the hook intercepts the `beforeSwap` callback, validates collateral, creates the loan, and the swap executes in the same atomic transaction.
- Repayment flows through Uniswap's `donate()` — the hook intercepts `afterDonate`, closes the loan, and returns collateral.

No separate lending contract entry points. No fragmented UX. Every interaction flows through the Uniswap pool.

### Innovation 2 — Reactive Smart Contract Liquidations
OnLoan deploys `LiquidationRSC` on Reactive Network's Kopli Testnet. This Reactive Smart Contract:

- **Subscribes to on-chain events** from Unichain: `LoanCreated`, `PriceUpdated`, `CollateralDeposited`, `LoanFullyRepaid`, `LoanLiquidated`
- **Recalculates health factors** for every active borrower after each `PriceUpdated` event
- **Emits a Callback** when any borrower's health factor drops below 1.0
- Reactive Network **relays that callback** to `OnLoanHook.liquidateLoan()` on Unichain — triggering the liquidation on-chain, trustlessly

No keeper bots. No off-chain scripts. No centralized infrastructure. Liquidations are purely event-driven.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Unichain Sepolia                   │
│                                                     │
│  Lender ──addLiquidity──► OnLoanHook                │
│                              │ afterAddLiquidity     │
│                              ▼                       │
│                         LendingPool ◄──shares──► ERC-6909 ReceiptToken
│                              │                       │
│  Borrower ──swap(hookData)──► beforeSwap             │
│                              │                       │
│                         LoanManager ◄──prices──► PriceOracle / TWAPOracle
│                              │                       │
│                         CollateralManager            │
│                              │                       │
│  Borrower ──donate(hookData)─► afterDonate           │
│                              │ (repay)               │
│                         LiquidationEngine            │
│                              │                       │
│                         RiskEngine ◄──monitors──────┐│
└─────────────────────────────────────────────────────┘│
                                                        │
┌─────────────────────────────────────────────────────┐│
│               Reactive Network (Kopli)              ││
│                                                     ││
│  LiquidationRSC ◄──subscribes──[LoanCreated,        ││
│       │                         PriceUpdated,       ││
│       │                         CollateralDeposited]─┘│
│       │                                              │
│       └──HF < 1.0──► Callback ──relay──► liquidateLoan() on Unichain
│                                                     │
│  CrossChainCollateralWatcher                        │
│       └──watches collateral prices across chains    │
└─────────────────────────────────────────────────────┘
```

---

## How It Works — Step by Step

### Lending (Dual Yield)
1. Lender calls `addLiquidity()` on the USDC/WETH Uniswap v4 pool
2. OnLoanHook's `afterAddLiquidity` deposits the USDC into `LendingPool`
3. LendingPool mints **ERC-6909 receipt tokens** representing pool shares
4. From this point: every swap through the pool earns the lender swap fees; every borrower repayment accrues interest directly into `totalDeposited`

### Borrowing
1. Borrower calls `CollateralManager.depositCollateral(WETH, 5 ether)`
2. Borrower encodes a borrow request in `hookData`:
   ```
   hookData = encodeBorrowPayload(borrower, WETH, 5 ether, 3000 USDC, 30 days)
   ```
3. Borrower calls `PoolManager.swap(poolKey, swapParams, hookData)`
4. `beforeSwap` decodes the payload, validates collateral ratio (max LTV: 75% for WETH), creates the loan, locks collateral
5. Swap executes — borrower receives USDC

### Interest Accrual
OnLoan uses a **kinked interest rate model** (inspired by Aave):
- Below 80% utilization: rates scale linearly from 2% → 10% APR
- Above 80% utilization: rates spike sharply from 10% → 20% APR
- The kink disincentivizes over-utilization and protects lender liquidity

### Repayment
1. Borrower approves repayment token
2. Borrower calls `PoolManager.donate(poolKey, amount0, amount1, hookData)` where `hookData = encodeRepayPayload(borrower)`
3. `afterDonate` closes the loan, splits interest 90/10 (lenders/protocol), returns collateral

### Liquidation — Reactive Path
1. `PriceUpdated` event fires on Unichain (e.g., WETH drops from $3,000 → $1,500)
2. `LiquidationRSC` on Reactive Network receives the event
3. RSC recalculates all tracked borrowers' health factors: `HF = (collateral × threshold) / debt`
4. For any borrower with HF < 1.0 (and cooldown elapsed): RSC emits a `Callback`
5. Reactive Network relays the callback to `OnLoanHook.liquidateLoan(borrower)` on Unichain
6. `LiquidationEngine` performs a final on-chain HF check, seizes collateral, settles debt
7. Liquidator receives a 5% bonus on seized collateral

---

## Contract Architecture

### Smart Contracts (28 files across 10 modules)

| Module | Contract | Role |
|--------|----------|------|
| **Hook** | `OnLoanHook` | Uniswap v4 hook — orchestrates all lending lifecycle events |
| **Lending** | `LendingPool` | Pool state, deposits, withdrawals, share accounting |
| **Lending** | `LoanManager` | Loan creation, interest accrual, repayment, health factors |
| **Lending** | `CollateralManager` | Collateral custody, LTV enforcement, seizure on liquidation |
| **Lending** | `InterestRateModel` | Kinked rate model — 2%/10%/20% at 0%/80%/100% utilization |
| **Oracle** | `PriceOracle` | Price feeds with staleness guards |
| **Oracle** | `TWAPOracle` | Ring-buffer TWAP with heartbeat and max deviation enforcement |
| **Liquidation** | `LiquidationEngine` | Liquidation execution, bonus calculation, collateral settlement |
| **Risk** | `RiskEngine` | Batch risk assessment, stress-test simulation, warning thresholds |
| **Reactive** | `LiquidationRSC` | Autonomous health factor monitor on Reactive Network |
| **Reactive** | `CrossChainCollateralWatcher` | Cross-chain collateral price surveillance |
| **Tokens** | `LendingReceipt6909` | ERC-6909 semi-fungible receipt tokens for LP shares |

### Hook Permissions

OnLoanHook implements the full Uniswap v4 hook interface:

| Hook | Purpose |
|------|---------|
| `beforeInitialize` | Validate pool configuration |
| `afterInitialize` | Register pool in LendingPool |
| `afterAddLiquidity` | Deposit lender funds into lending pool |
| `afterRemoveLiquidity` | Withdraw lender funds from lending pool |
| `beforeSwap` | Intercept and decode borrow requests from `hookData` |
| `afterSwap` | Post-swap state reconciliation |
| `afterDonate` | Intercept and process repayments from `hookData` |

---

## Deployed Contracts

### Unichain Sepolia (Chain ID 1301)

| Contract | Address | Explorer |
|----------|---------|----------|
| **OnLoanHook** | `0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0` | [View ↗](https://sepolia.uniscan.xyz/address/0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0) |
| **LendingPool** | `0xD3ebBdbEB12C656B9743b94384999E0ff7010f36` | [View ↗](https://sepolia.uniscan.xyz/address/0xD3ebBdbEB12C656B9743b94384999E0ff7010f36) |
| **LoanManager** | `0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46` | [View ↗](https://sepolia.uniscan.xyz/address/0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46) |
| **CollateralManager** | `0xa97C9C8dD22db815a4AB3E3279562FD379F925c6` | [View ↗](https://sepolia.uniscan.xyz/address/0xa97C9C8dD22db815a4AB3E3279562FD379F925c6) |
| **PriceOracle** | `0x1106661FB7104CFbd35E8477796D8CD9fB3806f2` | [View ↗](https://sepolia.uniscan.xyz/address/0x1106661FB7104CFbd35E8477796D8CD9fB3806f2) |
| **LiquidationEngine** | `0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6` | [View ↗](https://sepolia.uniscan.xyz/address/0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6) |
| **InterestRateModel** | `0xF2268d8133687e40AC174bCcA150677c42D74233` | [View ↗](https://sepolia.uniscan.xyz/address/0xF2268d8133687e40AC174bCcA150677c42D74233) |
| **RiskEngine** | `0x1bdFc336373903E24BD46f8d22b14972f0fAEF83` | [View ↗](https://sepolia.uniscan.xyz/address/0x1bdFc336373903E24BD46f8d22b14972f0fAEF83) |
| **ReceiptToken (ERC-6909)** | `0xEAE3b6033d744b8E0e817269df92004F3069bfB1` | [View ↗](https://sepolia.uniscan.xyz/address/0xEAE3b6033d744b8E0e817269df92004F3069bfB1) |
| PoolManager (Uniswap v4) | `0x000000000004444c5dc75cB358380D2e3dE08A90` | [View ↗](https://sepolia.uniscan.xyz/address/0x000000000004444c5dc75cB358380D2e3dE08A90) |

### Reactive Network (Kopli Testnet)

| Contract | Address | Role |
|----------|---------|------|
| **LiquidationRSC** | `0x6F491FaBdEc72fD14e9E014f50B2ffF61C508bf1` | Autonomous liquidation trigger |
| **CrossChainWatcher** | `0x012D911Dbc11232472A6AAF6b51E29A0C5929cC5` | Cross-chain collateral monitor |

### Testnet Tokens (Mintable — Use the Faucet)

| Token | Address | Decimals |
|-------|---------|----------|
| USDC | `0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6` | 6 |
| WETH | `0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D` | 18 |
| WBTC | `0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8` | 8 |

> The testnet tokens are permissionlessly mintable. Visit the **Faucet** page at `/faucet` in the app to claim 10,000 USDC, 10 WETH, and 0.5 WBTC in one click.

---

## Why Reactive Network?

Most lending protocols solve the liquidation problem by paying keeper bots to run `liquidate()` in a loop. This approach has well-documented failure modes: keeper downtime, gas wars during market stress, and MEV sandwich attacks that extract value from liquidated users.

OnLoan's integration with **Reactive Network** eliminates these failure modes entirely:

| Traditional Keeper Approach | OnLoan + Reactive Network |
|---|---|
| Off-chain bot polls health factors | On-chain RSC reacts to `PriceUpdated` events |
| Fails during gas spikes / network congestion | Event-driven — no polling loop |
| Single point of failure | Reactive Network infrastructure is decentralized |
| MEV-extractable liquidation race | Deterministic callback — first emitter wins |
| Requires off-chain server uptime | Purely on-chain, no external server |
| No cross-chain awareness | `CrossChainCollateralWatcher` observes multiple chains |

The `LiquidationRSC` maintains a live map of all active borrowers and their health factors. Every time a price update is recorded on Unichain, the RSC autonomously re-evaluates every position. If a position becomes liquidatable, the RSC emits a `Callback` that Reactive Network relays back to Unichain — triggering the liquidation without any human or off-chain intervention.

This is the **inversion of control** model: instead of a bot checking "is anyone liquidatable?", the protocol reacts to events and answers "this position just became liquidatable — liquidate it now."

---

## Partner Integration Summary

**Reactive Network** — Primary sponsor integration

- `LiquidationRSC.sol` deployed on Kopli Testnet (`0x6F491FaBdEc72fD14e9E014f50B2ffF61C508bf1`)
- `CrossChainCollateralWatcher.sol` deployed on Kopli Testnet (`0x012D911Dbc11232472A6AAF6b51E29A0C5929cC5`)
- Event subscriptions: `LoanCreated`, `PriceUpdated`, `CollateralDeposited`, `LoanFullyRepaid`, `LoanLiquidated`
- Autonomous callback relay to `OnLoanHook.liquidateLoan()` on Unichain Sepolia
- Per-borrower cooldown (1 hour) prevents duplicate liquidation spam
- Warning threshold (HF < 1.3) emits early warning events for UI display

---

## Frontend

OnLoan ships a full production-quality React frontend, live at [onloan-hook.vercel.app](https://onloan-hook.vercel.app/).

**Pages:**

| Route | Description |
|-------|-------------|
| `/` | Dashboard — TVL, APR, utilization, your active supply & borrow positions |
| `/lend` | Deposit USDC to earn dual yield; manage withdrawal with cooldown tracking |
| `/borrow` | Post WETH/WBTC collateral, select borrow amount and duration, view health factor |
| `/markets` | Pool analytics — rates, liquidity, utilization across all active pools |
| `/liquidations` | At-risk borrower table with live health factors and one-click liquidation |
| `/faucet` | Claim testnet USDC, WETH, and WBTC to start testing immediately |

**Tech Stack:**

| Layer | Technology |
|-------|-----------|
| Framework | React 19, TypeScript 5.9, Vite 7 |
| Styling | Tailwind CSS 4, Radix UI |
| Web3 | wagmi 3.5, viem 2 |
| Async State | TanStack React Query 5 |
| Global State | Zustand 5 |
| Router | React Router 7 |

---

## Testing

OnLoan has **211+ tests** across unit, integration, fuzz, simulation, and gas benchmark suites.

```bash
cd contracts
forge test                        # Run all tests
forge test --match-path test/unit # Unit tests only
forge test --match-path test/integration # Integration tests
forge test --match-path test/fuzz # Fuzz tests
forge test --gas-report           # Gas benchmarks
```

**Test Coverage:**

| Suite | Files | What's Tested |
|-------|-------|---------------|
| Unit | 12 files | LendingPool, LoanManager, CollateralManager, InterestRateModel, PriceOracle, TWAPOracle, LiquidationEngine, RiskEngine, LiquidationRSC, ERC-6909 |
| Integration | 3 files | Full Lend→Borrow→Repay→Withdraw, LiquidationFlow, RepaymentFlow |
| Fuzz | 3 files | HealthFactor monotonicity, CollateralRatio bounds, InterestRateModel continuity |
| Simulation | 1 file | Market crash scenario — 50% price drop across active positions |
| Gas | 1 file | Benchmarks for core operations |

---

## Quick Start

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 20+

### Run Contracts

```bash
git clone https://github.com/Akanimoh12/OnLoan-Hook.git
cd OnLoan-Hook

# Install contract dependencies
cd contracts && forge install

# Build
forge build

# Test
forge test

# Deploy to Unichain Sepolia
forge script script/deploy/DeployOnLoan.s.sol \
  --rpc-url https://sepolia.unichain.org \
  --broadcast
```

### Run Frontend

```bash
cd frontend

# Install dependencies
npm install

# Configure your RPC (see .env.example)
cp .env.example .env
# Edit .env and add VITE_RPC_URL_TESTNET=<your-alchemy-url>

# Start dev server
npm run dev
```

Open [http://localhost:5173](http://localhost:5173), connect MetaMask to Unichain Sepolia (Chain ID 1301), and visit `/faucet` to claim testnet tokens.

---

## Project Structure

```
OnLoan-Hook/
├── contracts/
│   ├── src/
│   │   ├── hook/           # OnLoanHook — core hook lifecycle
│   │   ├── lending/        # LendingPool, LoanManager, CollateralManager, InterestRateModel
│   │   ├── oracle/         # PriceOracle, TWAPOracle, OracleAdapter
│   │   ├── liquidation/    # LiquidationEngine, HealthFactorCalculator
│   │   ├── risk/           # RiskEngine — batch assessment & stress testing
│   │   ├── reactive/       # LiquidationRSC, CrossChainCollateralWatcher
│   │   ├── tokens/         # LendingReceipt6909 (ERC-6909)
│   │   ├── interfaces/     # IOnLoanHook, ILendingPool, ILoanManager, etc.
│   │   ├── libraries/      # LoanMath, HealthFactor, InterestAccrual, Events
│   │   └── types/          # LoanTypes, PoolTypes, Errors
│   └── test/
│       ├── unit/           # Per-module unit tests
│       ├── integration/    # End-to-end workflow tests
│       ├── fuzz/           # Property-based fuzz tests
│       ├── simulation/     # Market crash simulation
│       └── gas/            # Gas benchmarks
├── script/
│   └── deploy/             # DeployOnLoan, DeployTestnetTokens, DeployRiskEngine, DeployReactiveMonitor
├── frontend/
│   └── src/
│       ├── abis/           # Contract ABI JSON files
│       ├── components/     # UI primitives, layout, domain components
│       ├── hooks/          # wagmi read/write hooks
│       ├── lib/            # sdk.ts, constants.ts, wagmi.ts, utils.ts
│       ├── pages/          # Dashboard, Lend, Borrow, Markets, Liquidations, Faucet
│       └── types/          # TypeScript domain types
├── docs/
│   ├── ARCHITECTURE.md     # Deep-dive protocol design
│   ├── REACTIVE_INTEGRATION.md  # Reactive Network integration guide
│   ├── CONTRACTS.md        # Full contract reference
│   └── guides/
│       ├── GETTING_STARTED.md
│       ├── TESTING_GUIDE.md
│       └── DEPLOYMENT_GUIDE.md
└── deployments/
    ├── addresses.json      # Live contract addresses
    └── testnet-tokens.json # Testnet token addresses
```

---

## What Makes OnLoan Different

### vs. Aave / Compound
Aave and Compound are standalone lending protocols. They do not interact with AMMs. Lenders either provide liquidity to an AMM *or* to a lending protocol — never both at once. OnLoan is the first protocol to unify these into a single position.

### vs. Morpho Blue
Morpho Blue separates lending markets from AMMs and still relies on off-chain liquidators. OnLoan embeds lending inside the AMM and uses Reactive Network for autonomous liquidation — no external dependency.

### vs. Euler v2 Hook (Uniswap v4)
Euler's v4 hook integration focuses on flash loan mechanics. OnLoan focuses on the full lending lifecycle embedded in the hook, including a complete interest rate model, ERC-6909 receipt tokens, and cross-chain liquidation automation.

### The Unique Combination
No existing protocol combines:
- ✅ Uniswap v4 hook-native lending (borrow via `swap`, repay via `donate`)
- ✅ Dual yield for LPs (swap fees + interest)
- ✅ Autonomous cross-chain liquidations via Reactive Smart Contracts
- ✅ ERC-6909 semi-fungible receipt tokens for pool shares
- ✅ TWAP oracle with ring buffer, heartbeat, and max deviation guards
- ✅ Kinked interest rate model per pool
- ✅ Full production frontend with testnet faucet

---

## Protocol Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| Min Loan Duration | 1 day | Prevents flash loan abuse |
| Max Loan Duration | 365 days | |
| LP Withdrawal Cooldown | 1 day | Protects against bank run |
| Protocol Fee | 10% of interest | Accrues to protocol |
| WETH Max LTV | 75% | Borrow up to 75% of WETH value |
| WETH Liquidation Threshold | 80% | Liquidation triggers at 80% |
| WBTC Max LTV | 70% | More conservative for WBTC |
| WBTC Liquidation Threshold | 75% | |
| Liquidation Bonus | 5% | Incentive for liquidators |
| Base Interest Rate | 2% APR | At 0% utilization |
| Kink Rate | 10% APR | At 80% utilization |
| Max Interest Rate | 20% APR | At 100% utilization |
| RSC Liquidation Cooldown | 1 hour | Per borrower, prevents spam |
| RSC Warning Threshold | HF < 1.3 | Early warning before liquidation |
| Health Factor — Safe | > 1.5 | |
| Health Factor — Warning | 1.2–1.5 | |
| Health Factor — Danger | 1.0–1.2 | |
| Health Factor — Liquidatable | < 1.0 | RSC triggers liquidation |

---

## Documentation

- **[Architecture Deep-Dive](docs/ARCHITECTURE.md)** — Full protocol design, hook flow diagrams, data structures
- **[Reactive Integration Guide](docs/REACTIVE_INTEGRATION.md)** — How RSC event subscriptions and callbacks work
- **[Contract Reference](docs/CONTRACTS.md)** — Every public function, event, and error documented
- **[Protocol Spec](docs/OnLoan.md)** — Original protocol design document
- **[Project Structure](docs/PROJECT_STRUCTURE.md)** — Complete directory layout
- **[Getting Started](docs/guides/GETTING_STARTED.md)** — Complete setup guide for contributors and testers
- **[Testing Guide](docs/guides/TESTING_GUIDE.md)** — How to write and run tests
- **[Deployment Guide](docs/guides/DEPLOYMENT_GUIDE.md)** — Deploy to Unichain Sepolia and Reactive Network

---

## Team

Built by a 3-person team for the Atrium Academy UHI8 Hookathon.

- **Developer A** — Smart contracts: hook lifecycle, lending modules, oracle, deployment
- **Developer B** — Risk engine, Reactive Network RSCs, cross-chain automation
- **Developer C** — Frontend: React/TypeScript, wagmi integration, UI/UX

---

## License

MIT — see [LICENSE](LICENSE)
