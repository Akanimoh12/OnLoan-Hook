import { formatUnits, type Address } from 'viem';

/**
 * Shortens an Ethereum address to 0x1234...abcd format.
 */
export function shortenAddress(address: Address): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Formats a raw bigint token amount using the token's decimals and appends the symbol.
 */
export function formatTokenAmount(raw: bigint, decimals: number, symbol: string): string {
  const formatted = parseFloat(formatUnits(raw, decimals));
  return `${formatted.toLocaleString('en-US', { maximumFractionDigits: 6 })} ${symbol}`;
}

/**
 * Formats a raw bigint USD price (8 decimal precision as returned by the oracle)
 * to a locale-formatted dollar string.
 */
export function formatUSD(raw: bigint, decimals = 8): string {
  const val = parseFloat(formatUnits(raw, decimals));
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val);
}

/**
 * Converts a duration in days (number) to seconds as a bigint.
 */
export function daysToSeconds(days: number): bigint {
  return BigInt(Math.round(days)) * 86_400n;
}

/**
 * Returns a truncated string if it exceeds maxLength, appending ellipsis.
 */
export function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength)}...`;
}

/**
 * Returns a block explorer transaction URL for Unichain Sepolia.
 */
export function explorerTxUrl(hash: `0x${string}`): string {
  return `https://sepolia.uniscan.xyz/tx/${hash}`;
}

/**
 * Returns a block explorer address URL for Unichain Sepolia.
 */
export function explorerAddressUrl(address: Address): string {
  return `https://sepolia.uniscan.xyz/address/${address}`;
}

/**
 * Safely parses a decimal string input as a bigint with the given token decimals.
 * Returns 0n on invalid input.
 */
export function parseAmountInput(value: string, decimals: number): bigint {
  if (!value || value.trim() === '') return 0n;
  try {
    const [whole, frac = ''] = value.split('.');
    const fracPadded = frac.padEnd(decimals, '0').slice(0, decimals);
    return BigInt(whole + fracPadded);
  } catch {
    return 0n;
  }
}
