// Contract addresses — sourced from deployments/addresses.json
// Target chain: Unichain Sepolia (chainId 1301)

export const CONTRACTS = {
  onLoanHook:        '0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0' as `0x${string}`,
  lendingPool:       '0xD3ebBdbEB12C656B9743b94384999E0ff7010f36' as `0x${string}`,
  loanManager:       '0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46' as `0x${string}`,
  collateralManager: '0xa97C9C8dD22db815a4AB3E3279562FD379F925c6' as `0x${string}`,
  priceOracle:       '0x1106661FB7104CFbd35E8477796D8CD9fB3806f2' as `0x${string}`,
  liquidationEngine: '0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6' as `0x${string}`,
  receiptToken:      '0xEAE3b6033d744b8E0e817269df92004F3069bfB1' as `0x${string}`,
  // Populated once the PoolManager address is confirmed from the Uniswap v4 deployment
  poolManager:       '' as `0x${string}`,
} as const;

// Health factor thresholds — stored as BPS (1.0 = 10_000)
export const HF_LIQUIDATION_THRESHOLD = 10_000n;
export const HF_DANGER_THRESHOLD      = 12_000n;
export const HF_WARNING_THRESHOLD     = 15_000n;

// Precision constants
export const BPS_DENOMINATOR = 10_000n;
export const WAD              = 10n ** 18n;

// Block time on Unichain (ms) — used for query refresh intervals
export const BLOCK_TIME_MS = 2_000;

// Loan duration bounds (seconds)
export const MIN_LOAN_DURATION_SECONDS = 86_400n;           // 1 day
export const MAX_LOAN_DURATION_SECONDS = 86_400n * 365n;    // 365 days
