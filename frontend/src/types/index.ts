// All shared TypeScript types for the OnLoan frontend.
// Structs mirror on-chain definitions exactly to prevent encoding mismatches.

// ---------------------------------------------------------------------------
// On-chain struct mirrors
// ---------------------------------------------------------------------------

/** Mirrors LoanTypes.sol :: Loan */
export interface Loan {
  borrower: `0x${string}`;
  collateralToken: `0x${string}`;
  collateralAmount: bigint;
  borrowedAmount: bigint;
  accruedInterest: bigint;
  interestRateAtOrigination: bigint;
  startTime: bigint;
  lastAccrualTime: bigint;
  duration: bigint;
  active: boolean;
}

/** Mirrors LoanTypes.sol :: CollateralInfo */
export interface CollateralInfo {
  token: `0x${string}`;
  isSupported: boolean;
  liquidationThreshold: bigint;
  maxLTV: bigint;
  liquidationBonus: bigint;
}

/** Mirrors LoanTypes.sol :: LenderPosition */
export interface LenderPosition {
  deposited: bigint;
  shares: bigint;
  lastDepositTime: bigint;
}

/** Mirrors PoolTypes.sol :: LendingPoolState */
export interface LendingPoolState {
  totalDeposited: bigint;
  totalBorrowed: bigint;
  totalShares: bigint;
  lastUpdateTime: bigint;
  accumulatedProtocolFees: bigint;
}

/** Mirrors PoolTypes.sol :: InterestRateConfig */
export interface InterestRateConfig {
  baseRate: bigint;
  kinkRate: bigint;
  maxRate: bigint;
  kinkUtilization: bigint;
}

/** Mirrors PoolTypes.sol :: PoolConfig */
export interface PoolConfig {
  interestRateConfig: InterestRateConfig;
  protocolFeeRate: bigint;
  minLoanDuration: bigint;
  maxLoanDuration: bigint;
  withdrawalCooldown: bigint;
  isActive: boolean;
}

/** Mirrors IRiskEngine.sol :: RiskAssessment */
export interface RiskAssessment {
  borrower: `0x${string}`;
  healthFactor: bigint;
  collateralValueUSD: bigint;
  debtValueUSD: bigint;
  liquidationThreshold: bigint;
  isLiquidatable: boolean;
  isExpired: boolean;
  isWarning: boolean;
}

/** Mirrors IRiskEngine.sol :: StressResult */
export interface StressResult {
  borrower: `0x${string}`;
  currentHealthFactor: bigint;
  stressedHealthFactor: bigint;
  wouldBeLiquidatable: boolean;
}

// ---------------------------------------------------------------------------
// UI-only types
// ---------------------------------------------------------------------------

/** Derived health classification used to drive colour/copy in the gauge. */
export type HealthStatus = 'safe' | 'warning' | 'danger' | 'liquidatable';

/** Form state for the borrow flow. Amounts are string to allow free-typing. */
export interface BorrowFormState {
  collateralToken: `0x${string}` | '';
  collateralAmount: string;
  borrowAmount: string;
  durationDays: number;
}

/** Form state for the lend/deposit flow. */
export interface LendFormState {
  amount: string;
}

/** Form state for the withdraw flow. */
export interface WithdrawFormState {
  shares: string;
}

/** Enriched borrower row displayed in the liquidations table. */
export interface BorrowerRiskRow {
  address: `0x${string}`;
  healthFactor: bigint;
  status: HealthStatus;
  collateralValueUSD: bigint;
  debtValueUSD: bigint;
}

/** Notification toast payload. */
export interface ToastPayload {
  title: string;
  description?: string;
  variant: 'default' | 'destructive';
}
