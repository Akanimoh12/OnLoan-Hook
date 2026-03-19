# OnLoan Protocol Architecture

## Overview

OnLoan is a **hook-native lending protocol** — the entire lending lifecycle (deposits, collateralized borrowing, interest accrual, repayment, and liquidation) is embedded inside a Uniswap v4 pool via its hook interface. Capital that would otherwise sit idle in a lending vault instead earns both AMM swap fees and lending interest simultaneously.

---

## System Components

```
┌──────────────────────────────────────────────────────────────┐
│                        Unichain Sepolia                      │
│                                                              │
│  ┌─────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │ LendingPool │◄───│ OnLoanHook   │───►│ LoanManager  │    │
│  │             │    │              │    │              │    │
│  │ totalDeposited   │ beforeSwap   │    │ createLoan   │    │
│  │ totalBorrowed    │ afterSwap    │    │ repayLoan    │    │
│  │ totalShares  │   │ afterDonate  │    │ accrueInterest    │
│  └──────┬──────┘    │ afterAdd     │    └──────┬───────┘    │
│         │           │  Liquidity   │           │            │
│         ▼           └──────┬───────┘           ▼            │
│  ┌─────────────┐           │         ┌──────────────┐       │
│  │ Receipt6909 │           │         │ Collateral   │       │
│  │  (ERC-6909) │           │         │ Manager      │       │
│  └─────────────┘           │         └──────┬───────┘       │
│                            │                │               │
│  ┌─────────────┐           │         ┌──────▼───────┐       │
│  │ Interest    │◄──────────┤         │ PriceOracle  │       │
│  │ RateModel   │           │         │ TWAPOracle   │       │
│  └─────────────┘           │         └──────────────┘       │
│                            │                                │
│  ┌─────────────┐           │         ┌──────────────┐       │
│  │ Liquidation │◄──────────┘         │ RiskEngine   │       │
│  │ Engine      │                     │              │       │
│  └─────────────┘                     └──────────────┘       │
└──────────────────────────────────────────────────────────────┘
           ▲  events                         ▲
           │                                 │
┌──────────┴──────────────────────────────── ┴ ────────────────┐
│                    Reactive Network (Kopli)                   │
│                                                              │
│  ┌─────────────────────────┐   ┌──────────────────────────┐  │
│  │    LiquidationRSC       │   │  CrossChainCollateral    │  │
│  │                         │   │  Watcher                 │  │
│  │  subscribes:            │   │                          │  │
│  │  - LoanCreated          │   │  - monitors prices       │  │
│  │  - PriceUpdated         │   │    across chains         │  │
│  │  - CollateralDeposited  │   └──────────────────────────┘  │
│  │  - LoanFullyRepaid      │                                 │
│  │  - LoanLiquidated       │                                 │
│  │                         │                                 │
│  │  on PriceUpdated:       │                                 │
│  │    recalculate all HFs  │                                 │
│  │    if HF < 1.0:         │                                 │
│  │      emit Callback ─────┼──────► liquidateLoan() on Unichain
│  └─────────────────────────┘                                 │
└──────────────────────────────────────────────────────────────┘
```

---

## Hook Lifecycle

### Pool Initialization
```
PoolManager.initialize(poolKey, sqrtPriceX96, hookData)
  └── OnLoanHook.beforeInitialize()
        └── validate hook flags, pool config
  └── OnLoanHook.afterInitialize()
        └── LendingPool.initializePool(poolId, rateConfig, poolConfig)
```

### Lender Deposit
```
PoolManager.modifyLiquidity(poolKey, addParams, hookData)
  └── OnLoanHook.afterAddLiquidity(sender, params, delta, hookData)
        └── extract USDC delta from liquidity delta
        └── LendingPool.deposit(poolId, lender, usdcAmount)
              └── shares = usdcAmount * totalShares / totalDeposited
              └── LendingReceipt6909.mint(lender, poolTokenId, shares)
              └── LenderPosition stored with cooldown timestamp
```

### Borrowing via Swap
```
PoolManager.swap(poolKey, swapParams, hookData)
  └── OnLoanHook.beforeSwap(sender, key, params, hookData)
        └── if hookData.flag == BORROW:
              └── decode: borrower, collateralToken, collateralAmount, borrowAmount, duration
              └── CollateralManager.lockCollateral(borrower, token, amount)
              └── PriceOracle.getPrice(collateralToken) → validate LTV
              └── InterestRateModel.getBorrowRate(poolId) → get current rate
              └── LoanManager.createLoan(borrower, ...)
              └── LendingPool.recordBorrow(poolId, amount)
  └── swap executes: USDC flows to borrower
```

### Repayment via Donate
```
PoolManager.donate(poolKey, amount0, amount1, hookData)
  └── OnLoanHook.afterDonate(sender, key, amount0, amount1, hookData)
        └── if hookData.flag == REPAY:
              └── decode: borrower
              └── LoanManager.accrueInterest(borrower) → calculate total owed
              └── LoanManager.repayLoan(borrower, totalOwed)
              └── LendingPool.recordRepayment(poolId, principal, interest)
                    └── lenderShare = interest * 90%
                    └── protocolShare = interest * 10%
                    └── totalDeposited += lenderShare  ← interest compounds for LPs
              └── CollateralManager.unlockCollateral(borrower, token, amount)
```

### Liquidation via LiquidationEngine
```
LiquidationEngine.liquidateLoan(borrower)
  └── LoanManager.getHealthFactor(borrower)
  └── require: HF < 1.0 OR loan.expired
  └── CollateralManager.seizeCollateral(borrower, collateralToken)
  └── calculate liquidatorBonus = seizedValue * liquidationBonus / BPS
  └── transfer bonus to liquidator
  └── LendingPool.recordRepayment(poolId, principal, remainingInterest)
  └── LoanManager.markLoanLiquidated(borrower)
```

---

## Data Structures

### Loan
```solidity
struct Loan {
    address borrower;
    address collateralToken;
    uint256 collateralAmount;         // locked collateral in token units
    uint256 borrowedAmount;           // principal in USDC (6 decimals)
    uint256 accruedInterest;          // accrued interest in USDC
    uint256 interestRateAtOrigination; // rate in BPS when loan created
    uint256 startTime;                // unix timestamp
    uint256 lastAccrualTime;          // last interest accrual
    uint256 duration;                 // loan term in seconds
    bool active;
}
```

### LendingPoolState
```solidity
struct LendingPoolState {
    uint256 totalDeposited;           // total USDC deposited by lenders
    uint256 totalBorrowed;            // total USDC currently lent out
    uint256 totalShares;              // total ERC-6909 shares outstanding
    uint256 lastUpdateTime;           // last interest distribution
    uint256 accumulatedProtocolFees;  // unclaimed protocol fees
}
```

### CollateralInfo
```solidity
struct CollateralInfo {
    address token;
    bool isSupported;
    uint256 liquidationThreshold; // BPS — threshold at which position is liquidatable
    uint256 maxLTV;               // BPS — max borrow against this collateral
    uint256 liquidationBonus;     // BPS — liquidator reward
}
```

### PoolConfig
```solidity
struct PoolConfig {
    InterestRateConfig interestRateConfig;
    uint256 protocolFeeRate;      // 1000 = 10%
    uint256 minLoanDuration;      // 86400 = 1 day
    uint256 maxLoanDuration;      // 31536000 = 365 days
    uint256 withdrawalCooldown;   // 86400 = 1 day
    bool isActive;
}
```

---

## Health Factor

```
HF = (collateralValueUSD × liquidationThreshold) / totalDebt

Where:
  collateralValueUSD = collateralAmount × oraclePrice / 10^tokenDecimals
  totalDebt = borrowedAmount + accruedInterest
  liquidationThreshold = per-token BPS (e.g., 8000 for WETH = 80%)

Examples:
  5 WETH @ $3,000, borrowed $10,000 USDC (WETH threshold = 80%)
  HF = (5 × 3000 × 0.80) / 10000 = 1.20  ← safe

  5 WETH @ $1,500, borrowed $10,000 USDC
  HF = (5 × 1500 × 0.80) / 10000 = 0.60  ← liquidatable
```

---

## Interest Rate Model

OnLoan uses a **two-segment kinked model**:

```
Rate (APR)
20% │                                    ╱
    │                                  ╱
10% │                        ╱────────
    │                      ╱
 2% │──────────────────────
    └──────────────────────────────────── Utilization
    0%                   80%           100%

Segment 1 (0–80%):  rate = baseRate + (kinkRate - baseRate) × utilization / kinkUtilization
Segment 2 (80–100%): rate = kinkRate + (maxRate - kinkRate) × (utilization - kink) / (1 - kink)
```

The kink at 80% is a sharp rate escalation designed to:
1. Incentivize borrowers to repay before the pool runs dry
2. Attract new deposits when the pool is in high demand
3. Protect LPs from a sudden liquidity shortage

---

## ERC-6909 Receipt Tokens

OnLoan uses ERC-6909 (semi-fungible) for lender shares instead of ERC-20 because:

1. **One contract for all pools** — Each pool gets a unique token ID (`keccak256(poolId)`), so a single ERC-6909 contract tracks shares across all lending pools
2. **Transferable positions** — Lenders can transfer or sell their share position without unwrapping
3. **Composable** — Other protocols can hold or build on ERC-6909 positions

---

## Oracle Design

### PriceOracle
- Simple manual-update oracle for testnet
- Staleness guard: reverts if price is older than 1 hour
- Admin-controlled price updates

### TWAPOracle
- Ring buffer stores the last N price observations per token
- Configurable window size (e.g., 30 minutes TWAP)
- Heartbeat enforcement: reverts if no update within heartbeat period
- Max deviation guard: rejects updates that move price > X% from previous
- Designed for production deployments where a price feed pushes updates

The two-oracle architecture allows testnet simplicity (PriceOracle) with a clean upgrade path to production TWAP feeds.

---

## Authorization Model

```
Owner
  ├── sets authorized liquidators in LiquidationEngine
  ├── configures collateral parameters in CollateralManager
  └── sets interest rate configs in InterestRateModel

OnLoanHook (authorized)
  ├── calls LendingPool.deposit / withdraw / recordBorrow / recordRepayment
  ├── calls LoanManager.createLoan / repayLoan
  └── calls CollateralManager.lockCollateral / unlockCollateral / seizeCollateral

LiquidationEngine (authorized)
  ├── calls CollateralManager.seizeCollateral
  ├── calls LoanManager.markLoanLiquidated
  └── calls LendingPool.recordRepayment

LiquidationRSC (Reactive Network) → authorized liquidator in LiquidationEngine
```

---

## Security Considerations

1. **Reentrancy** — All state changes follow checks-effects-interactions. Collateral seizure and repayment happen before any token transfers.

2. **Price Manipulation** — The TWAPOracle's max deviation guard prevents flash loan–driven oracle manipulation. Stale price guards prevent stale data exploitation.

3. **Dual Health Check** — The RSC performs an off-chain HF check to trigger the callback, but `LiquidationEngine.liquidateLoan()` performs an independent on-chain HF check before executing. The RSC cannot force a liquidation that doesn't satisfy on-chain conditions.

4. **Withdrawal Cooldown** — LPs cannot withdraw immediately after deposit. A 1-day cooldown prevents deposit-borrow-withdraw attacks where an LP could drain the pool.

5. **Per-Pool Isolation** — Each Uniswap PoolId has completely isolated state in `LendingPool`. A failure or exploit in one pool does not affect others.

6. **Loan Uniqueness** — Each address may hold only one active loan at a time, preventing positions from fragmenting across many loans to avoid liquidation.
