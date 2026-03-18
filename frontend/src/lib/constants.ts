// Contract addresses — sourced from deployments/addresses.json + risk-engine.json
// Target chain: Unichain Sepolia (chainId 1301)

export const CONTRACTS = {
  onLoanHook:        '0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0' as `0x${string}`,
  lendingPool:       '0xD3ebBdbEB12C656B9743b94384999E0ff7010f36' as `0x${string}`,
  loanManager:       '0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46' as `0x${string}`,
  collateralManager: '0xa97C9C8dD22db815a4AB3E3279562FD379F925c6' as `0x${string}`,
  priceOracle:       '0x1106661FB7104CFbd35E8477796D8CD9fB3806f2' as `0x${string}`,
  liquidationEngine: '0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6' as `0x${string}`,
  receiptToken:      '0xEAE3b6033d744b8E0e817269df92004F3069bfB1' as `0x${string}`,
  interestRateModel: '0xF2268d8133687e40AC174bCcA150677c42D74233' as `0x${string}`,
  riskEngine:        '0x1bdFc336373903E24BD46f8d22b14972f0fAEF83' as `0x${string}`,
  poolManager:       '0x000000000004444c5dc75cB358380D2e3dE08A90' as `0x${string}`,
} as const;

// Pool IDs
export const POOLS = {
  USDC: '0x0000000000000000000000000000000000000000000000000000000000000001' as `0x${string}`,
  WETH: '0x0000000000000000000000000000000000000000000000000000000000000002' as `0x${string}`,
} as const;

// Testnet token addresses — sourced from deployments/testnet-tokens.json
export const TOKENS = {
  USDC: { address: '0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6' as `0x${string}`, symbol: 'USDC', decimals: 6, icon: '💵' },
  WETH: { address: '0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D' as `0x${string}`, symbol: 'WETH', decimals: 18, icon: '⟠' },
  WBTC: { address: '0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8' as `0x${string}`, symbol: 'WBTC', decimals: 8, icon: '₿' },
} as const;

// Supported collateral tokens for the borrow form
export const SUPPORTED_COLLATERAL = [
  TOKENS.WETH,
  TOKENS.WBTC,
] as const;

// Default PoolKey for the USDC/WETH pool
export const DEFAULT_POOL_KEY = {
  currency0: TOKENS.USDC.address,
  currency1: TOKENS.WETH.address,
  fee: 3000,
  tickSpacing: 60,
  hooks: CONTRACTS.onLoanHook,
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

// Protocol fee rate in BPS (used for supply rate calculation)
export const PROTOCOL_FEE_BPS = 1000n; // 10%
