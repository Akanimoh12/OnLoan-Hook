# OnLoan — Project Structure & Documentation Guide

> A comprehensive project structure blueprint for the OnLoan Uniswap v4 Hook lending protocol with Reactive Network automation.  
> **No code implementation** — this document serves as the architectural map for contributors and developers.

---

## Table of Contents

- [Root Directory Overview](#root-directory-overview)
- [Complete Folder Structure](#complete-folder-structure)
- [Directory Breakdown](#directory-breakdown)
  - [Contracts (`contracts/`)](#contracts-contracts)
  - [Frontend (`frontend/`)](#frontend-frontend)
  - [Documentation (`docs/`)](#documentation-docs)
  - [Scripts & Deployment (`script/`)](#scripts--deployment-script)
  - [Testing (`test/`)](#testing-test)
  - [CI/CD & DevOps (`.github/`)](#cicd--devops-github)
  - [Configuration Files](#configuration-files)
- [Dependency Map](#dependency-map)
- [Environment Setup](#environment-setup)
- [Naming Conventions](#naming-conventions)
- [Tooling Reference](#tooling-reference)

---

## Root Directory Overview

```
OnLoan-Hook/
│
├── contracts/           # All Solidity smart contracts (Foundry workspace)
├── frontend/            # Vite + React + TypeScript frontend application
├── docs/                # Project documentation, specs, and guides
├── script/              # Foundry deployment & migration scripts
├── test/                # Foundry test suites (unit, integration, fork, invariant)
├── .github/             # GitHub Actions CI/CD workflows & templates
├── .env.example         # Environment variable template
├── .gitmodules          # Foundry dependency submodules
├── foundry.toml         # Foundry configuration
├── README.md            # Project overview and quickstart
├── PROJECT_STRUCTURE.md # This file
├── OnLoan.md            # Architecture & design document
├── LICENSE              # MIT License
└── Makefile             # Common development commands
```

---

## Complete Folder Structure

```
OnLoan-Hook/
│
├── contracts/
│   ├── src/
│   │   ├── hook/
│   │   │   ├── OnLoanHook.sol
│   │   │   └── HookPermissions.sol
│   │   │
│   │   ├── lending/
│   │   │   ├── LendingPool.sol
│   │   │   ├── InterestRateModel.sol
│   │   │   ├── CollateralManager.sol
│   │   │   └── LoanManager.sol
│   │   │
│   │   ├── liquidation/
│   │   │   ├── LiquidationEngine.sol
│   │   │   └── HealthFactorCalculator.sol
│   │   │
│   │   ├── reactive/
│   │   │   ├── ReactiveMonitor.sol
│   │   │   ├── LiquidationRSC.sol
│   │   │   └── CrossChainCollateralWatcher.sol
│   │   │
│   │   ├── oracle/
│   │   │   ├── PriceOracle.sol
│   │   │   └── OracleAdapter.sol
│   │   │
│   │   ├── tokens/
│   │   │   └── LendingReceipt6909.sol
│   │   │
│   │   ├── interfaces/
│   │   │   ├── IOnLoanHook.sol
│   │   │   ├── ILendingPool.sol
│   │   │   ├── ICollateralManager.sol
│   │   │   ├── ILoanManager.sol
│   │   │   ├── ILiquidationEngine.sol
│   │   │   ├── IPriceOracle.sol
│   │   │   └── IInterestRateModel.sol
│   │   │
│   │   ├── libraries/
│   │   │   ├── LoanMath.sol
│   │   │   ├── HealthFactor.sol
│   │   │   ├── InterestAccrual.sol
│   │   │   ├── CollateralValuation.sol
│   │   │   └── Events.sol
│   │   │
│   │   └── types/
│   │       ├── LoanTypes.sol
│   │       ├── PoolTypes.sol
│   │       └── Errors.sol
│   │
│   └── lib/
│       ├── v4-core/                   # Uniswap v4 core (git submodule)
│       ├── v4-periphery/              # Uniswap v4 periphery (git submodule)
│       ├── forge-std/                 # Foundry standard library (git submodule)
│       ├── openzeppelin-contracts/    # OpenZeppelin utilities (git submodule)
│       └── reactive-network/         # Reactive Network contracts (git submodule)
│
├── test/
│   ├── unit/
│   │   ├── hook/
│   │   │   ├── OnLoanHook.beforeInitialize.t.sol
│   │   │   ├── OnLoanHook.afterInitialize.t.sol
│   │   │   ├── OnLoanHook.beforeSwap.t.sol
│   │   │   ├── OnLoanHook.afterSwap.t.sol
│   │   │   ├── OnLoanHook.beforeAddLiquidity.t.sol
│   │   │   ├── OnLoanHook.afterAddLiquidity.t.sol
│   │   │   ├── OnLoanHook.beforeRemoveLiquidity.t.sol
│   │   │   ├── OnLoanHook.afterRemoveLiquidity.t.sol
│   │   │   ├── OnLoanHook.beforeDonate.t.sol
│   │   │   └── OnLoanHook.afterDonate.t.sol
│   │   │
│   │   ├── lending/
│   │   │   ├── LendingPool.t.sol
│   │   │   ├── InterestRateModel.t.sol
│   │   │   ├── CollateralManager.t.sol
│   │   │   └── LoanManager.t.sol
│   │   │
│   │   ├── liquidation/
│   │   │   ├── LiquidationEngine.t.sol
│   │   │   └── HealthFactorCalculator.t.sol
│   │   │
│   │   ├── oracle/
│   │   │   └── PriceOracle.t.sol
│   │   │
│   │   └── tokens/
│   │       └── LendingReceipt6909.t.sol
│   │
│   ├── integration/
│   │   ├── LendAndBorrow.t.sol
│   │   ├── LiquidationFlow.t.sol
│   │   ├── RepaymentFlow.t.sol
│   │   ├── DualYieldAccrual.t.sol
│   │   └── ReactiveCallbackFlow.t.sol
│   │
│   ├── fork/
│   │   ├── UnichainFork.t.sol
│   │   └── ReactiveNetworkFork.t.sol
│   │
│   ├── invariant/
│   │   ├── LendingPoolInvariant.t.sol
│   │   ├── CollateralInvariant.t.sol
│   │   └── InterestAccrualInvariant.t.sol
│   │
│   ├── fuzz/
│   │   ├── InterestRateModel.fuzz.t.sol
│   │   ├── HealthFactor.fuzz.t.sol
│   │   └── CollateralRatio.fuzz.t.sol
│   │
│   ├── gas/
│   │   └── GasBenchmarks.t.sol
│   │
│   └── helpers/
│       ├── TestSetup.sol
│       ├── MockPriceOracle.sol
│       ├── MockReactiveCallback.sol
│       ├── MockERC20.sol
│       ├── HookDeployer.sol
│       └── Fixtures.sol
│
├── script/
│   ├── deploy/
│   │   ├── DeployOnLoan.s.sol
│   │   ├── DeployPriceOracle.s.sol
│   │   └── DeployReactiveMonitor.s.sol
│   │
│   ├── configure/
│   │   ├── SetupLendingPool.s.sol
│   │   ├── SetCollateralParams.s.sol
│   │   └── SubscribeRSC.s.sol
│   │
│   ├── verify/
│   │   └── VerifyContracts.s.sol
│   │
│   └── utils/
│       ├── HookMiner.s.sol
│       └── AddressComputer.s.sol
│
├── frontend/
│   ├── public/
│   │   ├── favicon.svg
│   │   ├── og-image.png
│   │   └── manifest.json
│   │
│   ├── src/
│   │   ├── app/
│   │   │   ├── App.tsx
│   │   │   ├── Router.tsx
│   │   │   └── Providers.tsx
│   │   │
│   │   ├── pages/
│   │   │   ├── Dashboard/
│   │   │   │   ├── DashboardPage.tsx
│   │   │   │   └── components/
│   │   │   │       ├── PortfolioOverview.tsx
│   │   │   │       ├── ActiveLoans.tsx
│   │   │   │       └── YieldSummary.tsx
│   │   │   │
│   │   │   ├── Lend/
│   │   │   │   ├── LendPage.tsx
│   │   │   │   └── components/
│   │   │   │       ├── DepositForm.tsx
│   │   │   │       ├── WithdrawForm.tsx
│   │   │   │       └── LendingPositionCard.tsx
│   │   │   │
│   │   │   ├── Borrow/
│   │   │   │   ├── BorrowPage.tsx
│   │   │   │   └── components/
│   │   │   │       ├── CollateralDepositForm.tsx
│   │   │   │       ├── BorrowForm.tsx
│   │   │   │       ├── RepayForm.tsx
│   │   │   │       └── HealthFactorGauge.tsx
│   │   │   │
│   │   │   ├── Markets/
│   │   │   │   ├── MarketsPage.tsx
│   │   │   │   └── components/
│   │   │   │       ├── MarketTable.tsx
│   │   │   │       ├── PoolCard.tsx
│   │   │   │       └── InterestRateChart.tsx
│   │   │   │
│   │   │   └── Liquidations/
│   │   │       ├── LiquidationsPage.tsx
│   │   │       └── components/
│   │   │           ├── LiquidationFeed.tsx
│   │   │           └── AtRiskPositions.tsx
│   │   │
│   │   ├── components/
│   │   │   ├── ui/
│   │   │   │   ├── Button.tsx
│   │   │   │   ├── Card.tsx
│   │   │   │   ├── Modal.tsx
│   │   │   │   ├── Input.tsx
│   │   │   │   ├── Skeleton.tsx
│   │   │   │   ├── Toast.tsx
│   │   │   │   └── Tooltip.tsx
│   │   │   │
│   │   │   ├── layout/
│   │   │   │   ├── Header.tsx
│   │   │   │   ├── Footer.tsx
│   │   │   │   ├── Sidebar.tsx
│   │   │   │   └── Layout.tsx
│   │   │   │
│   │   │   ├── web3/
│   │   │   │   ├── ConnectWallet.tsx
│   │   │   │   ├── NetworkSwitcher.tsx
│   │   │   │   ├── TransactionStatus.tsx
│   │   │   │   └── TokenApproval.tsx
│   │   │   │
│   │   │   └── shared/
│   │   │       ├── TokenIcon.tsx
│   │   │       ├── AddressDisplay.tsx
│   │   │       ├── AmountInput.tsx
│   │   │       └── LoadingSpinner.tsx
│   │   │
│   │   ├── hooks/
│   │   │   ├── useOnLoanHook.ts
│   │   │   ├── useLendingPool.ts
│   │   │   ├── useBorrow.ts
│   │   │   ├── useRepay.ts
│   │   │   ├── useCollateral.ts
│   │   │   ├── useHealthFactor.ts
│   │   │   ├── useLiquidations.ts
│   │   │   ├── useInterestRate.ts
│   │   │   ├── useTokenBalance.ts
│   │   │   └── useTransactionToast.ts
│   │   │
│   │   ├── lib/
│   │   │   ├── wagmi.ts
│   │   │   ├── viem.ts
│   │   │   ├── chains.ts
│   │   │   └── constants.ts
│   │   │
│   │   ├── config/
│   │   │   ├── abis/
│   │   │   │   ├── OnLoanHook.json
│   │   │   │   ├── LendingPool.json
│   │   │   │   ├── PriceOracle.json
│   │   │   │   └── ERC20.json
│   │   │   │
│   │   │   ├── addresses.ts
│   │   │   └── tokens.ts
│   │   │
│   │   ├── services/
│   │   │   ├── lendingService.ts
│   │   │   ├── borrowService.ts
│   │   │   ├── liquidationService.ts
│   │   │   └── priceService.ts
│   │   │
│   │   ├── store/
│   │   │   ├── useAppStore.ts
│   │   │   ├── useLendingStore.ts
│   │   │   └── useBorrowStore.ts
│   │   │
│   │   ├── types/
│   │   │   ├── loan.ts
│   │   │   ├── pool.ts
│   │   │   ├── market.ts
│   │   │   └── index.ts
│   │   │
│   │   ├── utils/
│   │   │   ├── format.ts
│   │   │   ├── calculations.ts
│   │   │   ├── validation.ts
│   │   │   └── errors.ts
│   │   │
│   │   ├── styles/
│   │   │   ├── globals.css
│   │   │   └── tailwind.css
│   │   │
│   │   ├── main.tsx
│   │   └── vite-env.d.ts
│   │
│   ├── index.html
│   ├── vite.config.ts
│   ├── tailwind.config.ts
│   ├── postcss.config.js
│   ├── tsconfig.json
│   ├── tsconfig.node.json
│   ├── eslint.config.js
│   ├── .prettierrc
│   └── package.json
│
├── docs/
│   ├── architecture/
│   │   ├── SYSTEM_OVERVIEW.md
│   │   ├── HOOK_LIFECYCLE.md
│   │   ├── REACTIVE_INTEGRATION.md
│   │   ├── CROSS_CHAIN_FLOW.md
│   │   └── diagrams/
│   │       ├── architecture.mmd
│   │       ├── liquidation-flow.mmd
│   │       ├── lending-flow.mmd
│   │       └── borrowing-flow.mmd
│   │
│   ├── contracts/
│   │   ├── ONLOAN_HOOK.md
│   │   ├── LENDING_POOL.md
│   │   ├── INTEREST_RATE_MODEL.md
│   │   ├── COLLATERAL_MANAGER.md
│   │   ├── LIQUIDATION_ENGINE.md
│   │   ├── REACTIVE_MONITOR.md
│   │   └── PRICE_ORACLE.md
│   │
│   ├── guides/
│   │   ├── GETTING_STARTED.md
│   │   ├── LOCAL_DEVELOPMENT.md
│   │   ├── TESTING_GUIDE.md
│   │   ├── DEPLOYMENT_GUIDE.md
│   │   ├── FRONTEND_SETUP.md
│   │   └── CONTRIBUTING.md
│   │
│   ├── specs/
│   │   ├── LENDING_SPEC.md
│   │   ├── BORROWING_SPEC.md
│   │   ├── LIQUIDATION_SPEC.md
│   │   ├── FEE_STRUCTURE.md
│   │   ├── INTEREST_RATE_SPEC.md
│   │   └── LOAN_PARAMETERS.md
│   │
│   ├── security/
│   │   ├── THREAT_MODEL.md
│   │   ├── AUDIT_CHECKLIST.md
│   │   ├── ACCESS_CONTROL.md
│   │   └── INVARIANTS.md
│   │
│   └── api/
│       ├── HOOK_API.md
│       ├── FRONTEND_API.md
│       └── EVENT_REFERENCE.md
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── contracts-test.yml
│   │   ├── frontend-build.yml
│   │   ├── slither.yml
│   │   └── deploy.yml
│   │
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── contract_issue.md
│   │
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── CODEOWNERS
│
├── .env.example
├── .gitignore
├── .gitmodules
├── .solhint.json
├── .prettierrc
├── foundry.toml
├── remappings.txt
├── Makefile
├── LICENSE
├── README.md
├── PROJECT_STRUCTURE.md
└── OnLoan.md
```

---

## Directory Breakdown

### Contracts (`contracts/`)

The smart contract layer is organized as a Foundry workspace with clearly separated concerns.

#### `contracts/src/hook/`

| File | Purpose |
|---|---|
| `OnLoanHook.sol` | Main entry point — implements all 10 Uniswap v4 hook callbacks (`beforeInitialize`, `afterInitialize`, `beforeAddLiquidity`, `afterAddLiquidity`, `beforeRemoveLiquidity`, `afterRemoveLiquidity`, `beforeSwap`, `afterSwap`, `beforeDonate`, `afterDonate`). Orchestrates lending, borrowing, and liquidation logic. |
| `HookPermissions.sol` | Isolates `getHookPermissions()` configuration and hook flag validation. |

#### `contracts/src/lending/`

| File | Purpose |
|---|---|
| `LendingPool.sol` | Manages lender deposits, withdrawal logic, utilization rate tracking, and pool accounting. Tracks `totalDeposited`, `totalBorrowed`, and per-lender shares. |
| `InterestRateModel.sol` | Implements dynamic interest rate curves based on pool utilization. Variable APR (5–20%) with configurable kink points. |
| `CollateralManager.sol` | Handles collateral deposits, locks, releases, and valuation. Enforces 150% collateral ratio and 66.7% max LTV. |
| `LoanManager.sol` | Creates, tracks, and settles individual loans. Manages loan lifecycle from creation through repayment or liquidation. |

#### `contracts/src/liquidation/`

| File | Purpose |
|---|---|
| `LiquidationEngine.sol` | Executes liquidation logic — seizes collateral, performs swaps through the Uniswap v4 pool, distributes proceeds to lenders, and pays the 5% liquidation bonus. |
| `HealthFactorCalculator.sol` | Computes health factors for individual loans. Returns the ratio of collateral value to outstanding debt. |

#### `contracts/src/reactive/`

| File | Purpose |
|---|---|
| `ReactiveMonitor.sol` | Base Reactive Smart Contract that subscribes to OnLoan events on Unichain and processes incoming log records. |
| `LiquidationRSC.sol` | Specialized RSC that monitors `PriceUpdated` events, calculates health factors, and emits `Callback` events to trigger `liquidateLoan()` on Unichain when health factor drops below 120%. |
| `CrossChainCollateralWatcher.sol` | RSC that monitors collateral token events on origin chains (Ethereum Mainnet, other L2s) and relays price/state updates to the OnLoan hook on Unichain. |

#### `contracts/src/oracle/`

| File | Purpose |
|---|---|
| `PriceOracle.sol` | On-chain price feed contract for collateral valuation. Emits `PriceUpdated` events consumed by Reactive Network RSCs. |
| `OracleAdapter.sol` | Adapter pattern to support multiple oracle sources (Chainlink, Pyth, TWAP) behind a unified interface. |

#### `contracts/src/tokens/`

| File | Purpose |
|---|---|
| `LendingReceipt6909.sol` | ERC-6909 multi-token implementation for lender position receipts. Composable with other DeFi protocols. Minted on deposit, burned on withdrawal. |

#### `contracts/src/interfaces/`

All external-facing interface definitions. Each contract has a corresponding `I{ContractName}.sol` interface to enable modularity, testing, and upgradability patterns.

#### `contracts/src/libraries/`

| File | Purpose |
|---|---|
| `LoanMath.sol` | Pure math functions for loan calculations — interest accrual, compounding, pro-rata distributions. |
| `HealthFactor.sol` | Shared health factor computation logic used by both on-chain and RSC contracts. |
| `InterestAccrual.sol` | Time-weighted interest accrual utilities using block timestamps. |
| `CollateralValuation.sol` | Collateral-to-USD valuation helpers integrating with the oracle layer. |
| `Events.sol` | Centralized event definitions consumed across all contracts and by Reactive Network RSC subscriptions. |

#### `contracts/src/types/`

| File | Purpose |
|---|---|
| `LoanTypes.sol` | Struct definitions — `Loan`, `LendingPool`, `CollateralInfo`, `LoanParams`. |
| `PoolTypes.sol` | Pool configuration types — `LendingPoolConfig`, `InterestRateConfig`, `CollateralConfig`. |
| `Errors.sol` | Custom error definitions — `InsufficientCollateral`, `LoanNotActive`, `BelowMinimumLTV`, `WithdrawalLocked`, etc. |

#### `contracts/lib/`

External dependencies managed as git submodules via Foundry:

| Dependency | Version | Purpose |
|---|---|---|
| `v4-core` | Latest | Uniswap v4 core — `PoolManager`, `PoolKey`, `BalanceDelta`, hook interfaces |
| `v4-periphery` | Latest | `BaseHook` abstract contract, hook utilities, router contracts |
| `forge-std` | Latest | Foundry test utilities — `Test`, `console2`, `Vm` cheatcodes |
| `openzeppelin-contracts` | v5.x | `ReentrancyGuard`, `Ownable`, `SafeERC20`, `Math` |
| `reactive-network` | Latest | `AbstractReactive`, `IReactive`, RSC base contracts |

---

### Frontend (`frontend/`)

Modern React SPA using the latest tooling for Web3 dApp development.

#### `frontend/src/app/`

Application shell — top-level providers, router configuration, and global app wrapper.

| File | Purpose |
|---|---|
| `App.tsx` | Root component with layout wrapper |
| `Router.tsx` | TanStack Router or React Router v7 route definitions |
| `Providers.tsx` | Composition root — wagmi `WagmiProvider`, `QueryClientProvider`, theme provider, toast provider |

#### `frontend/src/pages/`

Feature-based page modules. Each page has its own `components/` folder for page-specific UI.

| Page | Route | Description |
|---|---|---|
| `Dashboard/` | `/` | Portfolio overview — active positions, total yield earned, aggregated health factor |
| `Lend/` | `/lend` | Deposit/withdraw interface for lenders. Shows pool APY breakdown (swap fees + interest) |
| `Borrow/` | `/borrow` | Collateral deposit, borrow execution, repayment, and health factor monitoring |
| `Markets/` | `/markets` | All available lending markets — utilization rates, interest rates, TVL per pool |
| `Liquidations/` | `/liquidations` | Real-time feed of Reactive Network liquidation events, at-risk positions |

#### `frontend/src/components/`

Reusable component library organized by scope:

| Folder | Contents |
|---|---|
| `ui/` | Primitive UI components — `Button`, `Card`, `Modal`, `Input`, `Skeleton`, `Toast`, `Tooltip`. Built with Radix UI primitives + Tailwind CSS. |
| `layout/` | Structural layout components — `Header`, `Footer`, `Sidebar`, `Layout` wrapper. |
| `web3/` | Wallet and chain interaction components — `ConnectWallet` (wagmi), `NetworkSwitcher`, `TransactionStatus` tracker, `TokenApproval` flow. |
| `shared/` | Domain-specific shared components — `TokenIcon`, `AddressDisplay` (ENS-aware), `AmountInput` (with max/percentage), `LoadingSpinner`. |

#### `frontend/src/hooks/`

Custom React hooks wrapping contract interactions via wagmi + viem:

| Hook | Description |
|---|---|
| `useOnLoanHook` | Core hook interaction — reads pool state, lending parameters |
| `useLendingPool` | Deposit, withdraw, and pool balance queries |
| `useBorrow` | Borrow execution and active loan state |
| `useRepay` | Loan repayment transactions |
| `useCollateral` | Collateral deposit/withdraw and balance tracking |
| `useHealthFactor` | Real-time health factor calculation and danger threshold alerts |
| `useLiquidations` | Event log subscription for liquidation events |
| `useInterestRate` | Current interest rate queries and historical rate data |
| `useTokenBalance` | ERC-20 balance and allowance reads |
| `useTransactionToast` | Transaction lifecycle toast notifications |

#### `frontend/src/lib/`

Core library configuration:

| File | Purpose |
|---|---|
| `wagmi.ts` | wagmi client configuration — Unichain chain definition, transport (viem HTTP/WebSocket), connectors (injected, WalletConnect, Coinbase Wallet) |
| `viem.ts` | Public and wallet client setup for Unichain |
| `chains.ts` | Custom chain definitions for Unichain (mainnet + testnet) and Reactive Network |
| `constants.ts` | Global constants — contract addresses, supported tokens, API endpoints |

#### `frontend/src/config/`

| Folder/File | Purpose |
|---|---|
| `abis/` | JSON ABI files for each deployed contract, auto-generated from Foundry build artifacts |
| `addresses.ts` | Deployed contract addresses per network (testnet, mainnet) |
| `tokens.ts` | Supported token metadata — symbol, decimals, logo, contract address |

#### `frontend/src/services/`

Service layer abstracting contract calls and data transformations:

| Service | Purpose |
|---|---|
| `lendingService.ts` | Lender deposit/withdraw transaction builders, pool state reads |
| `borrowService.ts` | Borrow/repay transaction builders, loan state reads |
| `liquidationService.ts` | Liquidation event queries and at-risk loan identification |
| `priceService.ts` | Token price fetching from oracle contracts |

#### `frontend/src/store/`

Client-side state management using Zustand:

| Store | Purpose |
|---|---|
| `useAppStore.ts` | Global app state — connected wallet, selected network, UI preferences |
| `useLendingStore.ts` | Cached lending pool data, lender positions |
| `useBorrowStore.ts` | Active loans, collateral balances, health factor cache |

#### `frontend/src/types/`

TypeScript type definitions mirroring Solidity structs:

| File | Purpose |
|---|---|
| `loan.ts` | `Loan`, `LoanStatus`, `LoanParams` types |
| `pool.ts` | `LendingPool`, `PoolConfig`, `PoolStats` types |
| `market.ts` | `Market`, `MarketMetrics`, `InterestRateData` types |
| `index.ts` | Barrel exports |

#### `frontend/src/utils/`

Utility functions:

| File | Purpose |
|---|---|
| `format.ts` | Number formatting — APR display, token amounts, USD values, health factor coloring |
| `calculations.ts` | Client-side interest calculations, collateral ratio estimation |
| `validation.ts` | Form input validation — amount bounds, address validation |
| `errors.ts` | Custom error handling and user-friendly error message mapping |

#### Frontend Configuration Files

| File | Purpose |
|---|---|
| `vite.config.ts` | Vite bundler config — plugins, aliases (`@/` → `src/`), environment variable handling |
| `tailwind.config.ts` | Tailwind CSS v4 configuration — custom theme, colors, fonts, animations |
| `postcss.config.js` | PostCSS plugins — Tailwind, autoprefixer |
| `tsconfig.json` | TypeScript compiler options — strict mode, path aliases |
| `eslint.config.js` | ESLint flat config — TypeScript, React, import order rules |
| `.prettierrc` | Code formatting rules — semicolons, single quotes, trailing commas |
| `package.json` | Dependencies and scripts |

---

### Documentation (`docs/`)

#### `docs/architecture/`

High-level system design documents and visual diagrams.

| File | Description |
|---|---|
| `SYSTEM_OVERVIEW.md` | End-to-end architecture — how the hook, lending pool, Reactive Network, and frontend interact |
| `HOOK_LIFECYCLE.md` | Detailed walkthrough of each Uniswap v4 hook callback and the OnLoan logic executed at each point |
| `REACTIVE_INTEGRATION.md` | Reactive Network integration deep dive — RSC subscription model, callback mechanism, event flow |
| `CROSS_CHAIN_FLOW.md` | Cross-chain collateral monitoring architecture — origin chain events, relay mechanism, state sync |
| `diagrams/` | Mermaid diagram source files for architecture, flow, and sequence diagrams |

#### `docs/contracts/`

Per-contract technical documentation — storage layout, function signatures, access control, event definitions, and integration notes.

#### `docs/guides/`

Step-by-step guides for developers and contributors.

| Guide | Audience | Contents |
|---|---|---|
| `GETTING_STARTED.md` | All developers | Prerequisites, repo clone, environment setup, first build |
| `LOCAL_DEVELOPMENT.md` | Backend devs | Foundry workflow, local Anvil fork, hot-reload testing |
| `TESTING_GUIDE.md` | Backend devs | Unit/integration/fork/invariant/fuzz testing patterns, coverage targets |
| `DEPLOYMENT_GUIDE.md` | DevOps | Deployment scripts, verification, Unichain + Reactive Network deployment |
| `FRONTEND_SETUP.md` | Frontend devs | Node/pnpm setup, env variables, ABI sync, dev server |
| `CONTRIBUTING.md` | Contributors | Branch strategy, PR workflow, commit conventions, code review process |

#### `docs/specs/`

Protocol specification documents — formal definitions of lending mechanics, fee structures, interest rate models, and loan parameters. Referenced during implementation and audits.

#### `docs/security/`

| File | Description |
|---|---|
| `THREAT_MODEL.md` | Identified attack vectors — flash loan attacks, oracle manipulation, MEV, reentrancy, griefing |
| `AUDIT_CHECKLIST.md` | Pre-audit preparation checklist — common vulnerability patterns, Uniswap v4 hook-specific risks |
| `ACCESS_CONTROL.md` | Role and permission matrix — who can call what, RSC callback authentication |
| `INVARIANTS.md` | Protocol invariants that must always hold — used as the basis for invariant fuzz tests |

#### `docs/api/`

| File | Description |
|---|---|
| `HOOK_API.md` | Complete API reference for `OnLoanHook.sol` — all public/external functions, events, errors |
| `FRONTEND_API.md` | Frontend service layer API documentation — hook parameters, expected return types |
| `EVENT_REFERENCE.md` | Comprehensive event catalog with topic hashes, parameter types, and Reactive Network subscription patterns |

---

### Scripts & Deployment (`script/`)

Foundry scripts for deployment, configuration, and maintenance.

#### `script/deploy/`

| Script | Target Network | Purpose |
|---|---|---|
| `DeployOnLoan.s.sol` | Unichain | Deploys `OnLoanHook` with correct hook address flags (via CREATE2 / hook mining), `LendingPool`, `CollateralManager`, and `PriceOracle` |
| `DeployPriceOracle.s.sol` | Unichain | Standalone oracle deployment for testing or oracle upgrades |
| `DeployReactiveMonitor.s.sol` | Reactive Network | Deploys `LiquidationRSC` and `CrossChainCollateralWatcher` on Reactive Network with event subscriptions |

#### `script/configure/`

| Script | Purpose |
|---|---|
| `SetupLendingPool.s.sol` | Initializes a lending pool with parameters — base interest rate, LTV, liquidation threshold |
| `SetCollateralParams.s.sol` | Configures supported collateral tokens and their parameters |
| `SubscribeRSC.s.sol` | Registers RSC event subscriptions on Reactive Network |

#### `script/utils/`

| Script | Purpose |
|---|---|
| `HookMiner.s.sol` | Mines a CREATE2 salt to produce a hook address with the correct permission flags for Uniswap v4 |
| `AddressComputer.s.sol` | Pre-computes deployment addresses for deterministic deployments |

---

### Testing (`test/`)

Comprehensive test suite organized by test type.

| Test Type | Folder | Purpose |
|---|---|---|
| **Unit** | `test/unit/` | Isolated tests for each contract function. One test file per contract, grouped by module. |
| **Integration** | `test/integration/` | Multi-contract interaction tests — full lend→borrow→repay and lend→borrow→liquidate flows. |
| **Fork** | `test/fork/` | Tests against live Unichain and Reactive Network state using Foundry's fork mode. |
| **Invariant** | `test/invariant/` | Stateful fuzz tests asserting protocol invariants hold across random sequences of actions. |
| **Fuzz** | `test/fuzz/` | Stateless fuzz tests for math-heavy functions — interest rate calculations, health factors, collateral ratios. |
| **Gas** | `test/gas/` | Gas usage benchmarks for critical paths — hook callbacks, liquidation execution, loan creation. |
| **Helpers** | `test/helpers/` | Shared test fixtures, mock contracts, and deployment utilities used across all test types. |

---

### CI/CD & DevOps (`.github/`)

#### Workflows

| Workflow | Trigger | Actions |
|---|---|---|
| `ci.yml` | Push/PR to `main`, `develop` | Runs full pipeline — lint, build, test, coverage |
| `contracts-test.yml` | Changes in `contracts/`, `test/`, `script/` | `forge build` → `forge test` → coverage report → gas snapshot |
| `frontend-build.yml` | Changes in `frontend/` | `pnpm install` → `pnpm lint` → `pnpm build` → `pnpm test` |
| `slither.yml` | PR to `main` | Static analysis via Slither for vulnerability detection |
| `deploy.yml` | Manual trigger / tag | Deployment pipeline — build, verify, deploy to testnet/mainnet |

#### Templates

| Template | Purpose |
|---|---|
| `ISSUE_TEMPLATE/bug_report.md` | Structured bug report — reproduction steps, expected vs actual behavior |
| `ISSUE_TEMPLATE/feature_request.md` | Feature proposal template with rationale and scope |
| `ISSUE_TEMPLATE/contract_issue.md` | Smart contract-specific issue — affected function, potential impact |
| `PULL_REQUEST_TEMPLATE.md` | PR checklist — tests added, gas impact, security considerations |
| `CODEOWNERS` | Auto-assign reviewers by file path |

---

### Configuration Files

| File | Purpose |
|---|---|
| `.env.example` | Template for environment variables — RPC URLs, private keys, API keys, contract addresses |
| `.gitignore` | Ignore patterns — `out/`, `cache/`, `node_modules/`, `.env`, `broadcast/` |
| `.gitmodules` | Foundry library submodule references |
| `.solhint.json` | Solidity linter configuration — naming conventions, security rules, gas optimizations |
| `.prettierrc` | Prettier configuration for Solidity and TypeScript formatting |
| `foundry.toml` | Foundry project configuration — compiler version, optimizer runs, remappings, RPC endpoints, fuzz runs |
| `remappings.txt` | Solidity import remappings — `@uniswap/v4-core/=lib/v4-core/`, `@reactive/=lib/reactive-network/` |
| `Makefile` | Developer convenience commands — `make build`, `make test`, `make deploy-testnet`, `make snapshot` |

---

## Dependency Map

```
OnLoanHook.sol
├── BaseHook (v4-periphery)
│   └── IHooks (v4-core)
├── IPoolManager (v4-core)
├── PoolKey, BalanceDelta, BeforeSwapDelta (v4-core/types)
├── Hooks (v4-core/libraries)
├── LendingPool.sol
│   ├── InterestRateModel.sol
│   │   └── LoanMath.sol (library)
│   └── LendingReceipt6909.sol
├── CollateralManager.sol
│   ├── PriceOracle.sol
│   │   └── OracleAdapter.sol
│   └── CollateralValuation.sol (library)
├── LoanManager.sol
│   ├── LoanTypes.sol
│   ├── InterestAccrual.sol (library)
│   └── HealthFactor.sol (library)
├── LiquidationEngine.sol
│   └── HealthFactorCalculator.sol
├── ReentrancyGuard (OpenZeppelin)
└── Events.sol (library)

ReactiveMonitor.sol
├── AbstractReactive (reactive-network)
├── IReactive (reactive-network)
├── LiquidationRSC.sol
│   └── HealthFactor.sol (shared library)
└── CrossChainCollateralWatcher.sol
```

---

## Environment Setup

### Required Environment Variables

```bash
# ── RPC Endpoints ──
UNICHAIN_RPC_URL=           # Unichain RPC (Alchemy/Infura/public)
UNICHAIN_TESTNET_RPC_URL=   # Unichain Sepolia testnet RPC
REACTIVE_RPC_URL=            # Reactive Network RPC endpoint
ETHEREUM_RPC_URL=            # Ethereum mainnet (for fork tests)

# ── Deployment Keys ──
DEPLOYER_PRIVATE_KEY=        # Deployer wallet private key
ETHERSCAN_API_KEY=           # Block explorer verification API key

# ── Contract Addresses (post-deployment) ──
ONLOAN_HOOK_ADDRESS=         # Deployed OnLoanHook address
POOL_MANAGER_ADDRESS=        # Uniswap v4 PoolManager on Unichain
PRICE_ORACLE_ADDRESS=        # Deployed PriceOracle address

# ── Frontend ──
VITE_UNICHAIN_RPC_URL=      # Public RPC for frontend
VITE_WALLETCONNECT_ID=      # WalletConnect project ID
VITE_ONLOAN_HOOK_ADDRESS=   # Hook address for frontend
```

---

## Naming Conventions

| Category | Convention | Example |
|---|---|---|
| Solidity contracts | PascalCase | `OnLoanHook.sol`, `LendingPool.sol` |
| Solidity libraries | PascalCase | `LoanMath.sol`, `HealthFactor.sol` |
| Solidity interfaces | `I` + PascalCase | `IOnLoanHook.sol`, `ILendingPool.sol` |
| Solidity events | PascalCase verbs | `LoanCreated`, `CollateralReleased` |
| Solidity errors | PascalCase descriptive | `InsufficientCollateral`, `LoanNotActive` |
| Solidity test files | `ContractName.t.sol` | `OnLoanHook.beforeSwap.t.sol` |
| Solidity scripts | `ActionName.s.sol` | `DeployOnLoan.s.sol` |
| React components | PascalCase | `HealthFactorGauge.tsx`, `DepositForm.tsx` |
| React hooks | `use` + PascalCase | `useHealthFactor.ts`, `useBorrow.ts` |
| TypeScript utils | camelCase | `format.ts`, `calculations.ts` |
| Store files | `use` + PascalCase + `Store` | `useLendingStore.ts` |
| CSS/styles | kebab-case | `globals.css` |
| Documentation | UPPER_SNAKE_CASE | `SYSTEM_OVERVIEW.md`, `THREAT_MODEL.md` |
| Env variables | UPPER_SNAKE_CASE | `UNICHAIN_RPC_URL` |

---

## Tooling Reference

| Tool | Version | Purpose |
|---|---|---|
| **Foundry (forge, cast, anvil)** | Latest | Solidity compilation, testing, deployment, local devnet |
| **Solidity** | ^0.8.26 | Smart contract language |
| **Node.js** | v20 LTS+ | Frontend runtime |
| **pnpm** | v9+ | Fast, disk-efficient package manager |
| **Vite** | v6+ | Frontend build tool and dev server |
| **React** | v19+ | UI framework |
| **TypeScript** | v5.5+ | Type-safe frontend development |
| **Tailwind CSS** | v4+ | Utility-first CSS framework |
| **wagmi** | v2+ | React hooks for Ethereum/EVM wallet interactions |
| **viem** | v2+ | TypeScript Ethereum library (transport, encoding, ABI) |
| **TanStack Query** | v5+ | Async state management and caching for contract reads |
| **Zustand** | v5+ | Lightweight client-side state management |
| **Radix UI** | Latest | Accessible, unstyled UI primitives |
| **Slither** | Latest | Solidity static analysis and vulnerability detection |
| **Solhint** | Latest | Solidity linter |
| **ESLint** | v9+ (flat config) | TypeScript/React linting |
| **Prettier** | v3+ | Code formatting (Solidity + TypeScript) |
| **GitHub Actions** | — | CI/CD pipeline automation |
| **Vercel** | — | Frontend deployment and preview environments |

---

> **This document is a living blueprint.** Update it as new modules, contracts, or features are added to the OnLoan protocol.
