import { encodeAbiParameters, parseAbiParameters } from 'viem';
import type { HealthStatus } from '@/types';
import { HF_LIQUIDATION_THRESHOLD, HF_DANGER_THRESHOLD, HF_WARNING_THRESHOLD } from '@/lib/constants';

// Must match the flag bytes defined in OnLoanHook.sol exactly.
const BORROW_FLAG = '0x01' as const;
const REPAY_FLAG  = '0x02' as const;

// ---------------------------------------------------------------------------
// Payload encoders
// ---------------------------------------------------------------------------

/**
 * Encodes hookData for a borrow-via-swap call.
 * Mirrors: abi.decode(hookData, (bytes1, address, address, uint256, uint256, uint256))
 *
 * Parameter order is fixed by the contract — do not reorder.
 */
export function encodeBorrowPayload(
  borrower: `0x${string}`,
  collateralToken: `0x${string}`,
  collateralAmount: bigint,
  borrowAmount: bigint,
  durationSeconds: bigint,
): `0x${string}` {
  return encodeAbiParameters(
    parseAbiParameters('bytes1, address, address, uint256, uint256, uint256'),
    [BORROW_FLAG, borrower, collateralToken, collateralAmount, borrowAmount, durationSeconds],
  );
}

/**
 * Encodes hookData for a repay-via-donate call.
 * Mirrors: abi.decode(hookData, (bytes1, address))
 */
export function encodeRepayPayload(borrower: `0x${string}`): `0x${string}` {
  return encodeAbiParameters(
    parseAbiParameters('bytes1, address'),
    [REPAY_FLAG, borrower],
  );
}

// ---------------------------------------------------------------------------
// Health factor utilities
// ---------------------------------------------------------------------------

/**
 * Classifies a raw on-chain health factor (4 BPS decimals, 10_000 = 1.0)
 * into a status string used to drive UI colour and copy.
 */
export function getHealthStatus(healthFactor: bigint): HealthStatus {
  if (healthFactor < HF_LIQUIDATION_THRESHOLD) return 'liquidatable';
  if (healthFactor < HF_DANGER_THRESHOLD)      return 'danger';
  if (healthFactor < HF_WARNING_THRESHOLD)     return 'warning';
  return 'safe';
}

/**
 * Formats a raw BPS health factor to a 4-decimal string.
 * 10_000n => "1.0000", 12_500n => "1.2500"
 */
export function formatHealthFactor(healthFactor: bigint): string {
  if (healthFactor === 0n) return '0.0000';
  const whole = healthFactor / 10_000n;
  const frac  = healthFactor % 10_000n;
  return `${whole}.${frac.toString().padStart(4, '0')}`;
}

/**
 * Converts a health factor bigint to a floating-point number capped at 2.0
 * for gauge arc scaling purposes.
 */
export function healthFactorToFloat(healthFactor: bigint): number {
  return Math.min(Number(healthFactor) / 10_000, 2.0);
}

// ---------------------------------------------------------------------------
// Rate formatting utilities
// ---------------------------------------------------------------------------

/**
 * Formats a raw BPS utilization rate (10_000 = 100%) to a percentage string.
 */
export function formatUtilization(rateBps: bigint): string {
  const pct = Number(rateBps) / 100;
  return `${pct.toFixed(2)}%`;
}

/**
 * Formats a raw BPS interest rate (10_000 = 100%) to an APR string.
 */
export function formatApr(rateBps: bigint): string {
  const pct = Number(rateBps) / 100;
  return `${pct.toFixed(2)}% APR`;
}

/**
 * Converts a duration in seconds to a human-readable string.
 */
export function formatDuration(seconds: bigint): string {
  const days = Number(seconds) / 86_400;
  if (days < 1) return `${Math.round(Number(seconds) / 3600)}h`;
  if (days === 1) return '1 day';
  return `${Math.round(days)} days`;
}
