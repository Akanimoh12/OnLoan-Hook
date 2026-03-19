# Contract Reference

Complete reference for all OnLoan smart contracts. All contracts are deployed on Unichain Sepolia (Chain ID 1301) unless noted.

---

## OnLoanHook

**Address:** `0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0`
**Source:** `contracts/src/hook/OnLoanHook.sol`

The central orchestrator. Implements the full Uniswap v4 hook interface and coordinates all lending lifecycle events.

### Hook Callbacks

| Callback | Trigger | Action |
|----------|---------|--------|
| `beforeInitialize` | Pool creation | Validate hook configuration |
| `afterInitialize` | Pool creation | Register pool in LendingPool |
| `afterAddLiquidity` | LP deposits | Forward deposit to LendingPool |
| `afterRemoveLiquidity` | LP withdrawals | Forward withdrawal from LendingPool |
| `beforeSwap` | Any swap | Decode and process borrow requests |
| `afterSwap` | Any swap | Post-swap reconciliation |
| `afterDonate` | Donate call | Decode and process repayments |

### Key Functions

```solidity
// Called by LiquidationEngine / LiquidationRSC callback
function liquidateLoan(address borrower) external;

// Returns hook permissions flags
function getHookPermissions() external pure returns (Hooks.Permissions);
```

### hookData Encoding

Borrow request:
```solidity
// flag = 0x01 = BORROW
bytes memory hookData = abi.encode(
    uint8(0x01),
    borrower,        // address
    collateralToken, // address
    collateralAmount,// uint256
    borrowAmount,    // uint256
    duration         // uint256 (seconds)
);
```

Repay request:
```solidity
// flag = 0x02 = REPAY
bytes memory hookData = abi.encode(
    uint8(0x02),
    borrower         // address
);
```

---

## LendingPool

**Address:** `0xD3ebBdbEB12C656B9743b94384999E0ff7010f36`
**Source:** `contracts/src/lending/LendingPool.sol`

Manages pool state and lender share accounting per Uniswap PoolId.

### Functions

```solidity
// Initialize a new lending pool for a Uniswap pool
function initializePool(
    PoolId poolId,
    InterestRateConfig calldata rateConfig,
    PoolConfig calldata config
) external;

// Deposit funds — mints ERC-6909 shares to lender
function deposit(PoolId poolId, address lender, uint256 amount) external;

// Withdraw funds — burns ERC-6909 shares
function withdraw(PoolId poolId, address lender, uint256 shares) external returns (uint256 amount);

// Record a new borrow — increases totalBorrowed
function recordBorrow(PoolId poolId, uint256 amount) external;

// Record repayment — decreases totalBorrowed, distributes interest
function recordRepayment(
    PoolId poolId,
    uint256 principal,
    uint256 interest
) external;

// Read pool state
function getPoolState(PoolId poolId) external view returns (LendingPoolState memory);
function getLenderPosition(PoolId poolId, address lender) external view returns (LenderPosition memory);
function getUtilization(PoolId poolId) external view returns (uint256 bps);
```

### Events

```solidity
event LenderDeposited(PoolId indexed poolId, address indexed lender, uint256 amount, uint256 shares);
event LenderWithdrew(PoolId indexed poolId, address indexed lender, uint256 shares, uint256 amount);
event BorrowRecorded(PoolId indexed poolId, uint256 amount);
event RepaymentRecorded(PoolId indexed poolId, uint256 principal, uint256 interest);
```

---

## LoanManager

**Address:** `0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46`
**Source:** `contracts/src/lending/LoanManager.sol`

Manages per-borrower loan state. Each address may hold at most one active loan.

### Functions

```solidity
// Create a new loan
function createLoan(
    address borrower,
    PoolId poolId,
    address collateralToken,
    uint256 collateralAmount,
    uint256 borrowAmount,
    uint256 interestRate,   // BPS
    uint256 duration        // seconds
) external;

// Accrue interest up to current timestamp
function accrueInterest(address borrower) external;

// Repay a loan — reduces or clears debt
function repayLoan(address borrower, uint256 repayAmount) external;

// Mark loan as liquidated (called by LiquidationEngine)
function markLoanLiquidated(address borrower) external;

// Read functions
function getLoan(address borrower) external view returns (Loan memory);
function getHealthFactor(address borrower) external view returns (uint256 hfBps);
function isLiquidatable(address borrower) external view returns (bool);
function getActiveBorrowers() external view returns (address[] memory);
```

### Events

```solidity
event LoanCreated(address indexed borrower, uint256 collateral, uint256 borrowed, uint256 duration);
event LoanFullyRepaid(address indexed borrower);
event LoanLiquidated(address indexed borrower);
event InterestAccrued(address indexed borrower, uint256 interest);
```

---

## CollateralManager

**Address:** `0xa97C9C8dD22db815a4AB3E3279562FD379F925c6`
**Source:** `contracts/src/lending/CollateralManager.sol`

Holds and manages collateral for all borrowers. Enforces LTV ratios.

### Functions

```solidity
// Deposit collateral (borrower must approve first)
function depositCollateral(address token, uint256 amount) external;

// Withdraw unlocked collateral
function withdrawCollateral(address token, uint256 amount) external;

// Lock collateral for a loan (called by hook)
function lockCollateral(address borrower, address token, uint256 amount) external;

// Unlock collateral after repayment (called by hook)
function unlockCollateral(address borrower, address token, uint256 amount) external;

// Seize collateral on liquidation (called by LiquidationEngine)
function seizeCollateral(address borrower, address token) external returns (uint256 amount);

// Read functions
function getCollateralBalance(address borrower, address token) external view returns (uint256);
function getLockedCollateral(address borrower, address token) external view returns (uint256);
function getCollateralValueUSD(address borrower, address token) external view returns (uint256);

// Admin — configure supported collateral
function setSupportedCollateral(
    address token,
    uint256 liquidationThreshold, // BPS
    uint256 maxLTV,               // BPS
    uint256 liquidationBonus      // BPS
) external;
```

### Events

```solidity
event CollateralDeposited(address indexed borrower, address indexed token, uint256 amount);
event CollateralWithdrawn(address indexed borrower, address indexed token, uint256 amount);
event CollateralLocked(address indexed borrower, address indexed token, uint256 amount);
event CollateralSeized(address indexed borrower, address indexed token, uint256 amount);
```

---

## InterestRateModel

**Address:** `0xF2268d8133687e40AC174bCcA150677c42D74233`
**Source:** `contracts/src/lending/InterestRateModel.sol`

Kinked interest rate model. Rates are expressed in BPS per year.

### Functions

```solidity
// Get borrow rate at a given utilization
function getBorrowRate(uint256 utilizationBps) external view returns (uint256 rateBps);

// Get supply rate (borrow rate × utilization × (1 - protocolFee))
function getSupplyRate(
    uint256 utilizationBps,
    uint256 protocolFeeRateBps
) external view returns (uint256 rateBps);

// Per-pool rate config
function setRateConfig(PoolId poolId, InterestRateConfig calldata config) external;
function getRateConfig(PoolId poolId) external view returns (InterestRateConfig memory);
```

### Default Configuration

```solidity
InterestRateConfig({
    baseRate: 200,         // 2% APR at 0% utilization
    kinkRate: 1000,        // 10% APR at 80% utilization
    maxRate: 2000,         // 20% APR at 100% utilization
    kinkUtilization: 8000  // kink at 80%
})
```

---

## LiquidationEngine

**Address:** `0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6`
**Source:** `contracts/src/liquidation/LiquidationEngine.sol`

Executes liquidations. Can be called by any authorized liquidator (including LiquidationRSC callbacks).

### Functions

```solidity
// Liquidate an undercollateralized or expired loan
function liquidateLoan(address borrower) external;

// Check if a borrower is currently liquidatable
function isLiquidatable(address borrower) external view returns (bool);

// Admin — manage authorized liquidators
function setAuthorizedLiquidator(address liquidator, bool authorized) external;
```

### Liquidation Process

1. Verify caller is authorized
2. Call `LoanManager.isLiquidatable(borrower)` — requires `HF < 1.0` OR loan expired
3. Call `CollateralManager.seizeCollateral(borrower, token)` — transfers collateral to LiquidationEngine
4. Calculate liquidator bonus: `bonus = seizedValue × liquidationBonus / BPS`
5. Transfer bonus to `msg.sender` (or RSC relay address)
6. Transfer remaining seized collateral to settle debt with LendingPool
7. Call `LoanManager.markLoanLiquidated(borrower)`

### Events

```solidity
event LoanLiquidated(
    address indexed borrower,
    address indexed liquidator,
    address collateralToken,
    uint256 collateralSeized,
    uint256 debtCleared
);
```

---

## RiskEngine

**Address:** `0x1bdFc336373903E24BD46f8d22b14972f0fAEF83`
**Source:** `contracts/src/risk/RiskEngine.sol`

Risk assessment and monitoring. Used by the frontend and Reactive RSC.

### Functions

```solidity
// Full risk assessment for one borrower
function assessRisk(address borrower) external view returns (RiskAssessment memory);

// Batch scan all active borrowers
function scanAtRiskBorrowers() external view returns (RiskAssessment[] memory);

// Simulate a price change and return affected positions
function simulatePriceImpact(
    address token,
    uint256 newPrice
) external view returns (RiskAssessment[] memory affected);
```

### RiskAssessment Struct

```solidity
struct RiskAssessment {
    address borrower;
    uint256 healthFactor;         // BPS (1.0 = 10_000)
    uint256 collateralValueUSD;
    uint256 debtValueUSD;
    uint256 liquidationThreshold; // BPS
    bool isLiquidatable;
    bool isWarning;               // HF < 1.3
    bool isDanger;                // HF < 1.2
}
```

---

## PriceOracle

**Address:** `0x1106661FB7104CFbd35E8477796D8CD9fB3806f2`
**Source:** `contracts/src/oracle/PriceOracle.sol`

Testnet price oracle with staleness guards.

### Functions

```solidity
// Read price for a token
function getPrice(address token) external view returns (uint256 price, uint256 timestamp);

// Admin — update price
function setPrice(address token, uint256 price) external;

// Configure token decimals
function setTokenDecimals(address token, uint8 decimals) external;
```

---

## TWAPOracle

**Source:** `contracts/src/oracle/TWAPOracle.sol`

Production-grade oracle with TWAP, heartbeat, and max deviation guards.

### Functions

```solidity
// Read TWAP over configured window
function getTWAP(address token) external view returns (uint256 twapPrice);

// Push a new observation (authorized price feed only)
function updatePrice(address token, uint256 price) external;

// Configure per-token parameters
function configureToken(
    address token,
    uint256 heartbeat,          // seconds — max time between updates
    uint256 maxDeviationBps,    // max single-update price change
    uint8 decimals,
    uint16 bufferSize           // ring buffer length
) external;
```

---

## LendingReceipt6909

**Address:** `0xEAE3b6033d744b8E0e817269df92004F3069bfB1`
**Source:** `contracts/src/tokens/LendingReceipt6909.sol`

ERC-6909 semi-fungible receipt token. Token ID = `uint256(keccak256(poolId))`.

### Functions

```solidity
// ERC-6909 standard
function balanceOf(address owner, uint256 id) external view returns (uint256);
function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);
function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
function approve(address spender, uint256 id, uint256 amount) external returns (bool);

// Mint / burn — called by LendingPool only
function mint(address to, uint256 id, uint256 amount) external;
function burn(address from, uint256 id, uint256 amount) external;

// Helper — convert PoolId to token ID
function poolIdToTokenId(PoolId poolId) external pure returns (uint256);
```

---

## Mock Tokens (Testnet Only)

**Source:** `test/helpers/MockERC20.sol`

Standard ERC-20 with a permissionless `mint()` — anyone can claim tokens on testnet.

| Token | Address | Decimals |
|-------|---------|----------|
| USDC | `0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6` | 6 |
| WETH | `0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D` | 18 |
| WBTC | `0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8` | 8 |

```solidity
// Permissionless — no access control
function mint(address to, uint256 amount) external;
```

Use the **Faucet** page at `/faucet` in the frontend for a one-click mint of all three tokens.
