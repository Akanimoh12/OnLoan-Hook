# OnLoan

A Uniswap v4 Hook-powered lending protocol with cross-chain automation via Reactive Network.

## Overview

OnLoan is a decentralized lending protocol built as a **Uniswap v4 Hook** that transforms AMM liquidity pools into lending markets. By hooking directly into the Uniswap v4 `PoolManager` lifecycle, OnLoan enables lenders to earn dual yield (swap fees + lending interest) and borrowers to access capital without leaving the Uniswap ecosystem. **Reactive Network** provides autonomous cross-chain event monitoring for automated liquidations, health factor tracking, and loan lifecycle management — no off-chain bots or manual intervention required.

> **Submission for:** Atrium Academy UHI8 Hookathon  
> **Sponsor Integration:** Reactive Network  
> **Chain:** Unichain (Uniswap's native L2)

---

## Problem

Current DeFi lending and AMM liquidity exist as siloed systems:

- **Fragmented Capital** — Liquidity providers must choose between earning swap fees on Uniswap OR yield on lending protocols like Aave/Compound, but not both simultaneously
- **Idle Collateral** — Borrowed assets sit in lending vaults generating zero swap fee revenue for lenders
- **Liquidation Failures** — Traditional lending relies on off-chain bots for liquidations, creating single points of failure, MEV extraction, and cascading bad debt during high volatility
- **No Cross-Chain Awareness** — Lending positions on one chain have zero visibility into collateral price movements or events on other chains
- **Complex UX** — Users must bridge, approve, deposit, and manage positions across multiple dApps and chains manually

## Solution

OnLoan hooks directly into Uniswap v4's swap and liquidity lifecycle, unifying lending and AMM liquidity into a single protocol:

- **Dual Yield** — Lenders deposit into Uniswap v4 pools via the hook and earn swap fees + lending interest simultaneously
- **Hook-Native Lending** — Borrowers post collateral and borrow directly through the hook's `beforeSwap` / `afterSwap` logic, no separate lending contract needed
- **Reactive Liquidations** — Reactive Network's autonomous smart contracts monitor collateral health factors across chains in real-time, triggering liquidations on-chain without off-chain bots
- **Cross-Chain Collateral** — Reactive Smart Contracts (RSCs) watch collateral value events across origin and destination chains, enabling cross-chain collateral management
- **One-Click UX** — Unified interface for lending, borrowing, and liquidity provision through a single Uniswap v4 pool

---

## Why Reactive Network (Sponsor Integration)

OnLoan integrates **Reactive Network** as its cross-chain automation layer. Here's why Reactive Network is the ideal sponsor integration for a lending hook:

| Reactive Network Feature | OnLoan Application |
|---|---|
| **Reactive Smart Contracts (RSCs)** | Autonomously monitor loan health factors and trigger liquidations without off-chain bots |
| **Cross-Chain Event Listening** | Watch collateral price feeds and loan events across Unichain, Ethereum, and other chains |
| **Inversion of Control (IoC)** | Liquidation logic reacts to on-chain events automatically — no human poke required |
| **Parallelized EVM** | Handle high-throughput liquidation checks during volatile markets without congestion |
| **No Off-Chain Dependencies** | Eliminates reliance on centralized keeper bots, oracles, or external infrastructure |

### Reactive Network Integration Points

1. **Liquidation Monitoring RSC** — A Reactive Smart Contract subscribes to `CollateralDeposited`, `LoanInitiated`, and price oracle update events. When a loan's health factor drops below the liquidation threshold, the RSC autonomously calls `liquidateLoan()` on the OnLoan hook via a callback to Unichain.

2. **Cross-Chain Collateral Watcher** — An RSC monitors collateral token events on origin chains (e.g., ETH on Ethereum Mainnet) and relays price/state updates to the OnLoan hook on Unichain, ensuring real-time cross-chain awareness.

3. **Loan Lifecycle Automation** — RSCs listen for `LoanFullyRepaid` events on Unichain and trigger `releaseCollateral()` callbacks, or detect `LoanExpired` events to initiate automatic liquidation flows — all without off-chain intervention.

```
Reactive Network Integration Flow:

┌──────────────┐    Events     ┌──────────────────┐   Callbacks   ┌──────────────┐
│  Unichain    │──────────────▶│  Reactive Network │──────────────▶│  Unichain    │
│  OnLoan Hook │  LoanCreated  │  RSC (Monitoring) │  liquidate()  │  OnLoan Hook │
│  Price Oracle│  PriceUpdated │  RSC (Liquidator) │  release()    │  Collateral  │
└──────────────┘               └──────────────────┘               └──────────────┘
        │                              │
        │         Cross-Chain          │
        └──────────────────────────────┘
          Watches events on any chain
```

---

## How It Works

### Uniswap v4 Hook Lifecycle

OnLoan implements the following Uniswap v4 hook callbacks:

| Hook Callback | OnLoan Logic |
|---|---|
| `beforeInitialize` | Register pool as a lending market, set collateral parameters (LTV, liquidation threshold, interest rate model) |
| `afterInitialize` | Emit `LendingPoolCreated` event for Reactive Network RSC subscription |
| `beforeAddLiquidity` | Validate lender deposits, register lending position, calculate share of lending pool |
| `afterAddLiquidity` | Mint lending receipt tokens (ERC-6909), emit `LenderDeposited` event |
| `beforeRemoveLiquidity` | Check if lender's capital is locked in active loans, enforce withdrawal cooldowns |
| `afterRemoveLiquidity` | Burn lending receipt tokens, settle earned interest |
| `beforeSwap` | Validate borrow requests encoded as swaps, check collateral sufficiency, calculate max borrowable |
| `afterSwap` | Finalize loan creation, lock collateral, emit `LoanCreated` event for RSC monitoring |
| `beforeDonate` | Accept interest repayments and loan repayments as donations to the pool |
| `afterDonate` | Update loan state, check if fully repaid, emit `LoanRepaid` / `LoanFullyRepaid` events |

### For Lenders

1. **Deposit** — Add liquidity to an OnLoan-hooked Uniswap v4 pool
2. **Earn** — Automatically receive swap fees from normal Uniswap trading + interest from borrowers
3. **Withdraw** — Remove liquidity and claim accumulated interest (subject to utilization limits)

### For Borrowers

1. **Collateralize** — Deposit collateral (e.g., ETH, WBTC) into the hook contract
2. **Borrow** — Execute a swap through the OnLoan pool to receive borrowed tokens (e.g., USDC)
3. **Repay** — Donate tokens back to the pool to repay principal + interest
4. **Reclaim** — Withdraw collateral after full repayment

### Liquidation (Reactive Network Powered)

Reactive Smart Contracts autonomously handle liquidations:

1. **Monitor** — RSC subscribes to price oracle events and loan state events on Unichain
2. **Detect** — When collateral value drops and health factor falls below threshold (e.g., < 1.2), RSC triggers
3. **Execute** — RSC sends a callback transaction to Unichain calling `liquidateLoan()` on the hook
4. **Distribute** — Collateral is sold through the Uniswap v4 pool, lenders are repaid, and the liquidator RSC receives a bonus

```
Liquidation Flow (No Off-Chain Bots):

Price drops ──▶ Oracle emits PriceUpdated event
                        │
                        ▼
              ┌───────────────────┐
              │  Reactive Network │
              │  Liquidation RSC  │
              │                   │
              │ health = collateral│
              │          / debt   │
              │ if health < 1.2:  │
              │   callback →      │
              │   liquidate()     │
              └───────────────────┘
                        │
                        ▼
              ┌───────────────────┐
              │  OnLoan Hook      │
              │  liquidateLoan()  │
              │  ├─ Seize collat. │
              │  ├─ Swap → USDC   │
              │  ├─ Repay lenders │
              │  └─ Emit event    │
              └───────────────────┘
```

---

## Key Features

| Feature | Description |
|---|---|
| **Hook-Native Lending** | Lending logic lives entirely within Uniswap v4 hook callbacks — no separate lending contracts |
| **Dual Yield Engine** | Lenders earn Uniswap swap fees + borrower interest simultaneously on the same capital |
| **Reactive Liquidations** | Reactive Network RSCs replace off-chain keeper bots, ensuring trustless and MEV-resistant liquidations |
| **Cross-Chain Collateral Monitoring** | RSCs watch collateral events across any EVM chain, enabling future cross-chain lending |
| **Dynamic Interest Rates** | Interest rates adjust based on pool utilization via the hook's `beforeSwap` logic |
| **Flash Accounting Integration** | Leverages Uniswap v4's EIP-1153 transient storage for gas-efficient loan settlement |
| **ERC-6909 Lending Receipts** | Lender positions tracked as multi-token receipts, composable with other DeFi protocols |
| **Health Factor Alerts** | RSC emits warning events before liquidation threshold, enabling proactive position management |
| **Non-Custodial** | All collateral and lending capital managed by the hook contract — no intermediaries |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          UNICHAIN (L2)                              │
│                                                                     │
│  ┌────────────┐    ┌──────────────────────┐    ┌────────────────┐  │
│  │  Lenders   │───▶│  Uniswap v4          │◀───│  Borrowers     │  │
│  │  (USDC)    │    │  PoolManager         │    │  (ETH/WBTC)    │  │
│  └────────────┘    │  ┌──────────────────┐ │    └────────────────┘  │
│                    │  │  OnLoan Hook     │ │                        │
│                    │  │  ├─ Lending Pool │ │                        │
│                    │  │  ├─ Collateral   │ │                        │
│                    │  │  ├─ Interest     │ │                        │
│                    │  │  └─ Liquidation  │ │                        │
│                    │  └──────────────────┘ │                        │
│                    └──────────────────────┘                         │
│                              │ Events                               │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      REACTIVE NETWORK                                │
│                                                                      │
│  ┌─────────────────────┐    ┌─────────────────────────────────────┐  │
│  │  Liquidation RSC    │    │  Cross-Chain Collateral Watcher RSC │  │
│  │  ├─ Subscribe to    │    │  ├─ Watch price feeds on Ethereum   │  │
│  │  │  PriceUpdated    │    │  ├─ Watch collateral on L1/L2s      │  │
│  │  ├─ Calculate health│    │  └─ Relay state to Unichain         │  │
│  │  └─ Callback:       │    └─────────────────────────────────────┘  │
│  │     liquidate()     │                                             │
│  └─────────────────────┘                                             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Smart Contract Design

### OnLoanHook.sol (Uniswap v4 Hook)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";

contract OnLoanHook is BaseHook {
    struct Loan {
        address borrower;
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
        bool active;
    }

    struct LendingPool {
        uint256 totalDeposited;
        uint256 totalBorrowed;
        uint256 utilizationRate;
        uint256 baseInterestRate;
    }

    mapping(PoolId => LendingPool) public lendingPools;
    mapping(address => Loan) public loans;

    // Events for Reactive Network RSC subscriptions
    event LendingPoolCreated(PoolId indexed poolId, uint256 baseRate);
    event LenderDeposited(PoolId indexed poolId, address indexed lender, uint256 amount);
    event LoanCreated(address indexed borrower, uint256 collateral, uint256 borrowed);
    event LoanRepaid(address indexed borrower, uint256 amount);
    event LoanFullyRepaid(address indexed borrower);
    event LoanLiquidated(address indexed borrower, uint256 collateralSeized);
    event CollateralReleased(address indexed borrower, uint256 amount);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true,
            befreSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Hook implementations handle lending logic at each lifecycle point
    // See full implementation in /contracts/src/OnLoanHook.sol
}
```

### ReactiveMonitor.sol (Reactive Network RSC)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AbstractReactive} from "@reactive-network/contracts/AbstractReactive.sol";
import {IReactive} from "@reactive-network/contracts/IReactive.sol";

contract ReactiveMonitor is AbstractReactive {
    // Unichain chain ID
    uint256 constant UNICHAIN_ID = 130;
    
    // OnLoan Hook address on Unichain
    address public onLoanHook;
    
    // Event topic hashes
    uint256 constant LOAN_CREATED_TOPIC = 0x...; // keccak256("LoanCreated(address,uint256,uint256)")
    uint256 constant PRICE_UPDATED_TOPIC = 0x...; // keccak256("PriceUpdated(address,uint256)")
    
    // Health factor threshold (1.2 = 120%)
    uint256 constant LIQUIDATION_THRESHOLD = 120;

    constructor(address _onLoanHook) {
        onLoanHook = _onLoanHook;
        
        // Subscribe to LoanCreated events on Unichain
        subscribe(UNICHAIN_ID, _onLoanHook, LOAN_CREATED_TOPIC);
        
        // Subscribe to price oracle updates
        subscribe(UNICHAIN_ID, PRICE_ORACLE, PRICE_UPDATED_TOPIC);
    }

    function react(LogRecord calldata log) external override {
        if (log.topic_0 == PRICE_UPDATED_TOPIC) {
            // Check all active loans against new price
            // If health factor < threshold, trigger liquidation callback
            bytes memory payload = abi.encodeWithSignature(
                "liquidateLoan(address)",
                borrowerAtRisk
            );
            emit Callback(UNICHAIN_ID, onLoanHook, payload);
        }
    }
}
```

---

## Fee Structure

| Fee Type | Rate | Description |
|---|---|---|
| Borrower Interest | Variable APR (5–20%) | Based on pool utilization rate |
| Lender Yield | Interest - Protocol Fee | Net yield after protocol commission |
| Protocol Fee | 10% of interest earned | Sustains development and insurance fund |
| Liquidation Bonus | 5% of collateral | Incentive for Reactive Network RSC execution |
| Swap Fees | Pool-defined (e.g., 0.3%) | Standard Uniswap v4 swap fees for lenders |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Chain** | Unichain (Uniswap's L2) |
| **AMM** | Uniswap v4 (PoolManager + Hooks) |
| **Automation** | Reactive Network (Reactive Smart Contracts) |
| **Smart Contracts** | Solidity ^0.8.26 |
| **Hook Framework** | v4-periphery BaseHook |
| **Testing** | Foundry (forge test) |
| **Frontend** | Vite + React + TypeScript |
| **Wallet** | wagmi + viem |
| **Deployment** | Vercel (frontend) + forge script (contracts) |

---

## Loan Parameters

| Parameter | Value | Description |
|---|---|---|
| Collateral Ratio | 150% | Minimum collateral-to-loan ratio |
| Liquidation Threshold | 120% | Health factor below which liquidation triggers |
| Max LTV | 66.7% | Maximum loan-to-value ratio (1/1.5) |
| Liquidation Bonus | 5% | Bonus for liquidators |
| Min Loan Duration | 1 day | Minimum active loan period |
| Max Loan Duration | 365 days | Maximum before auto-expiry |
| Supported Collateral | ETH, WBTC, WETH | Initial supported collateral tokens |
| Borrow Asset | USDC | Primary lending asset |

---

## Deployment Plan

### Smart Contract Addresses

| Contract | Network | Address |
|---|---|---|
| OnLoanHook | Unichain | `TBD` |
| ReactiveMonitor (Liquidation RSC) | Reactive Network | `TBD` |
| ReactiveMonitor (Collateral RSC) | Reactive Network | `TBD` |
| PriceOracle | Unichain | `TBD` |

---

## Getting Started

```bash
# Clone repository
git clone https://github.com/your-org/onloan.git
cd onloan

# Install Foundry (if not installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test

# Deploy to Unichain testnet
forge script script/DeployOnLoan.s.sol --rpc-url $UNICHAIN_RPC --broadcast

# Frontend
cd frontend
npm install
npm run dev
```

---

## Security

- **Over-Collateralization** — 150% minimum collateral ratio prevents under-collateralized loans
- **Reactive Liquidations** — No reliance on off-chain bots; RSCs trigger liquidations autonomously on-chain
- **MEV Resistance** — Reactive Network's callback mechanism reduces MEV extraction during liquidations
- **Health Factor Monitoring** — Continuous on-chain monitoring via RSC event subscriptions
- **Flash Loan Protection** — Hook validates collateral state across multiple blocks to prevent flash loan attacks
- **Access Control** — Only authorized RSC callbacks can trigger liquidation functions
- **Reentrancy Guards** — All state-changing functions protected with reentrancy locks
- **Audit Status** — Smart contract audit planned pre-mainnet launch

---

## Roadmap

- [x] Protocol design and architecture
- [x] Uniswap v4 Hook interface design
- [x] Reactive Network RSC integration design
- [ ] OnLoanHook.sol — Core hook implementation
- [ ] ReactiveMonitor.sol — Liquidation RSC
- [ ] Interest rate model implementation
- [ ] Foundry test suite (unit + integration + fork tests)
- [ ] Frontend development (Vite + React)
- [ ] Unichain testnet deployment
- [ ] Reactive Network testnet RSC deployment
- [ ] End-to-end integration testing
- [ ] Security audit
- [ ] Unichain mainnet launch

---

## Why OnLoan Wins

| Advantage | Impact |
|---|---|
| **First Lending Hook on Uniswap v4** | Captures the untapped intersection of AMM + lending |
| **Dual Yield for Lenders** | Swap fees + interest = higher returns than standalone lending or LP |
| **Reactive Network Liquidations** | Trustless, autonomous, MEV-resistant — no off-chain infrastructure |
| **Native to Unichain** | Built on Uniswap's own L2 for lowest latency and deepest liquidity |
| **Hook-Native Architecture** | No external lending contracts — everything runs through PoolManager |
| **Cross-Chain Ready** | Reactive Network enables future cross-chain collateral and lending |

---

## References

- [Uniswap v4 Hooks Documentation](https://docs.uniswap.org/contracts/v4/concepts/hooks)
- [Uniswap v4 Whitepaper](https://app.uniswap.org/whitepaper-v4.pdf)
- [Reactive Network Documentation](https://dev.reactive.network/)
- [Reactive Network Cross-Chain Lending Demo](https://blog.reactive.network/cross-chain-lending-protocol/)
- [Reactive Network Liquidation Protection](https://blog.reactive.network/liquidation-protection-building-continuity-into-defi-lending/)
- [v4-core Repository](https://github.com/Uniswap/v4-core)
- [v4-periphery Repository](https://github.com/Uniswap/v4-periphery)
- [Reactive Smart Contract Demos](https://github.com/Reactive-Network/reactive-smart-contract-demos)

---

## Contributing

Contributions welcome. Please read our contributing guidelines before submitting PRs.

## License

MIT

---

Built for the Atrium Academy UHI8 Hookathon — Uniswap v4 Hooks + Reactive Network
