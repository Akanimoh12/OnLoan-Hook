# Testing Guide

OnLoan has **211+ tests** across five suites: unit, integration, fuzz, simulation, and gas benchmarks. All tests run with Foundry.

---

## Quick Start

```bash
cd contracts

# Install dependencies
forge install

# Build
forge build

# Run all tests
forge test

# Run with verbosity (see traces on failure)
forge test -vvv

# Gas report
forge test --gas-report
```

---

## Test Organization

```
test/
├── unit/
│   ├── lending/
│   │   ├── LendingPool.t.sol        # deposit, withdraw, share math, interest distribution
│   │   ├── LoanManager.t.sol        # loan creation, accrual, repayment, uniqueness
│   │   ├── CollateralManager.t.sol  # deposit, lock, unlock, seize, LTV enforcement
│   │   └── InterestRateModel.t.sol  # kinked model, utilization bands, edge cases
│   ├── oracle/
│   │   ├── PriceOracle.t.sol        # price updates, staleness, decimals
│   │   └── TWAPOracle.t.sol         # ring buffer, TWAP window, heartbeat, deviation
│   ├── liquidation/
│   │   └── LiquidationEngine.t.sol  # liquidation trigger, bonus calc, authorization
│   ├── risk/
│   │   └── RiskEngine.t.sol         # single assessment, batch scan, price impact sim
│   ├── reactive/
│   │   ├── LiquidationRSC.t.sol     # event subscription, HF evaluation, cooldown
│   │   └── CrossChainWatcher.t.sol  # multi-chain subscription, callback routing
│   ├── tokens/
│   │   └── LendingReceipt6909.t.sol # ERC-6909 mint, burn, transfer, approval
│   └── hook/
│       └── OnLoanHook.t.sol         # hook permissions, initialization, flag decoding
├── integration/
│   ├── LendAndBorrow.t.sol          # Full: deposit → borrow → repay → withdraw
│   ├── RepaymentFlow.t.sol          # Interest accrual across time, partial repayment
│   └── LiquidationFlow.t.sol        # Price crash → health factor breach → liquidation
├── fuzz/
│   ├── HealthFactor.fuzz.t.sol      # HF monotonicity with collateral/debt
│   ├── CollateralRatio.fuzz.t.sol   # LTV constraints across random collateral values
│   └── InterestRateModel.fuzz.t.sol # Rate model continuity and bounds
├── simulation/
│   └── MarketCrashSimulation.t.sol  # 50% price crash — N active positions
└── gas/
    └── GasBenchmarks.t.sol          # Core operation gas measurements
```

---

## Running Specific Suites

```bash
# Unit tests only
forge test --match-path "test/unit/**"

# Integration tests only
forge test --match-path "test/integration/**"

# Fuzz tests only
forge test --match-path "test/fuzz/**"

# Single test file
forge test --match-path "test/unit/lending/LendingPool.t.sol"

# Single test function
forge test --match-test "test_deposit_mintsCorrectShares"

# Verbose output (show call traces)
forge test -vvv --match-test "test_liquidation_happyPath"
```

---

## Key Test Scenarios

### Happy Path — LendAndBorrow.t.sol

```
1. Lender deposits 50,000 USDC → receives shares
2. Borrower locks 5 WETH collateral (oracle: $3,000/WETH)
   max borrow = 5 × 3000 × 75% = $11,250
3. Borrower borrows 5,000 USDC (HF = 5×3000×0.80/5000 = 2.4 → safe)
4. vm.warp(15 days) — interest accrues
5. Borrower repays: principal + interest → WETH returned
6. vm.warp(+1 day) — lender withdrawal cooldown elapses
7. Lender withdraws: receives > 50,000 USDC (earned interest)
```

### Liquidation Flow — LiquidationFlow.t.sol

```
1. Lender deposits 50,000 USDC
2. Borrower locks 5 WETH ($3,000/WETH), borrows 10,000 USDC
   HF = 5×3000×0.80/10000 = 1.20 (safe)
3. Oracle price update: WETH → $1,500
   HF = 5×1500×0.80/10000 = 0.60 (liquidatable)
4. LiquidationEngine.liquidateLoan(borrower) called
5. Assert: loan.active == false
6. Assert: borrower collateral = 0
7. Assert: liquidator received 5% bonus
8. Assert: LendingPool.totalBorrowed decreased
```

### Fuzz — HealthFactor.fuzz.t.sol

```solidity
function testFuzz_healthFactor_monotonicWithCollateral(
    uint256 collateral,       // bound: 1e15 to 1000 ether
    uint256 debt,             // bound: 1 to 1_000_000 USDC
    uint256 price             // bound: 1 to 100_000 USD
) public {
    // HF must increase as collateral increases (debt and price fixed)
    uint256 hf1 = calculateHF(collateral, debt, price);
    uint256 hf2 = calculateHF(collateral * 2, debt, price);
    assertGt(hf2, hf1);
}
```

### Market Crash Simulation — MarketCrashSimulation.t.sol

```
1. Setup: 20 borrowers with varied positions
2. Price crash: WETH -50%, WBTC -40%
3. Assert: all positions with HF < 1.0 before crash are liquidated
4. Assert: all positions with HF > 1.0 after crash remain active
5. Assert: LendingPool has no bad debt (total deposited ≥ total borrowed)
```

---

## Test Helpers

`test/helpers/TestSetup.sol` provides shared fixtures:

```solidity
contract TestSetup is Test {
    OnLoanHook hook;
    LendingPool lendingPool;
    LoanManager loanManager;
    CollateralManager collateralManager;
    LiquidationEngine liquidationEngine;
    PriceOracle priceOracle;
    MockERC20 usdc;
    MockERC20 weth;
    MockERC20 wbtc;

    address lender = makeAddr("lender");
    address borrower = makeAddr("borrower");
    address liquidator = makeAddr("liquidator");

    function setUp() public virtual {
        // Deploy full protocol
        // Set oracle prices: WETH=$3000, WBTC=$50000, USDC=$1
        // Fund test addresses
        // Authorize liquidator
    }
}
```

---

## Gas Benchmarks

```bash
forge test --gas-report --match-path "test/gas/GasBenchmarks.t.sol"
```

Expected gas costs for core operations:

| Operation | ~Gas |
|-----------|------|
| `deposit(poolId, lender, amount)` | ~85,000 |
| `borrow via swap(hookData)` | ~210,000 |
| `repay via donate(hookData)` | ~160,000 |
| `liquidateLoan(borrower)` | ~130,000 |
| `withdraw(poolId, lender, shares)` | ~75,000 |

---

## Writing New Tests

Follow the existing patterns:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestSetup } from "../../helpers/TestSetup.sol";

contract MyFeatureTest is TestSetup {
    function setUp() public override {
        super.setUp();
        // additional setup
    }

    function test_myFeature_doesExpectedThing() public {
        // Arrange
        vm.startPrank(lender);
        usdc.approve(address(lendingPool), 1000e6);
        // Act
        lendingPool.deposit(poolId, lender, 1000e6);
        // Assert
        assertEq(lendingPool.getPoolState(poolId).totalDeposited, 1000e6);
        vm.stopPrank();
    }
}
```

**Naming conventions:**
- `test_<function>_<scenario>` — normal tests
- `testFuzz_<property>_<invariant>` — fuzz tests
- `testRevert_<function>_<condition>` — expected reverts
