// Contract addresses — sourced from deployments/addresses.json + risk-engine.json
// Target chain: Unichain Sepolia (chainId 1301)

export const CONTRACTS = {
  onLoanHook:        '0x6358d4C2d2AbA1aBca6Fe290AF9E744d37a07fF0' as `0x${string}`,
  lendingPool:       '0x34d3c4f89d594F465f744b4f46cF81948Db0A660' as `0x${string}`,
  loanManager:       '0x89Abddbe65452b61c8595002117c7f52b9C6d254' as `0x${string}`,
  collateralManager: '0x5D7E254B613544E4083705430EB2C2B276DD681C' as `0x${string}`,
  priceOracle:       '0x5f9A7a10ce0274de1Fcaeb68eEf76393A5454776' as `0x${string}`,
  liquidationEngine: '0xC078178C19050Cf0a2f5e6A57Ac5CC6eb518140F' as `0x${string}`,
  receiptToken:      '0x4236A66B6Cdb320b33F560b24135FE9B6948DF42' as `0x${string}`,
  interestRateModel: '0xB76D52c1953EFB877FD519d7A3a830000c6dE69a' as `0x${string}`,
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
