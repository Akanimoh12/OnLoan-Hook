import { useReadContract } from 'wagmi';
import { CONTRACTS, BLOCK_TIME_MS } from '@/lib/constants';
import { PriceOracleAbi } from '@/lib/abis';

interface UsePriceResult {
  price: bigint;
  isLoading: boolean;
  isError: boolean;
}

/**
 * Reads the current price for a token from PriceOracle.getPrice(token).
 * Returns price in 8-decimal USD format.
 */
export function usePrice(token: `0x${string}` | undefined): UsePriceResult {
  const enabled = Boolean(token);

  const { data: raw, isLoading, isError } = useReadContract({
    address: CONTRACTS.priceOracle,
    abi: PriceOracleAbi,
    functionName: 'getPrice',
    args: token ? [token] : undefined,
    query: {
      enabled,
      refetchInterval: BLOCK_TIME_MS * 15,
    },
  });

  return {
    price: (raw as bigint) ?? 0n,
    isLoading,
    isError,
  };
}
