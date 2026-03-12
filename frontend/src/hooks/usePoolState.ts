import { useReadContract } from 'wagmi';
import { CONTRACTS, BLOCK_TIME_MS } from '@/lib/constants';
import { LendingPoolAbi } from '@/lib/abis';
import type { LendingPoolState } from '@/types';

interface UsePoolStateResult {
  data: LendingPoolState | undefined;
  isLoading: boolean;
  isError: boolean;
  refetch: () => void;
}

/**
 * Reads LendingPool.getPoolState(poolId) on a per-block interval.
 * Returns a typed LendingPoolState, remapped from the raw contract tuple.
 */
export function usePoolState(poolId: `0x${string}` | undefined): UsePoolStateResult {
  const enabled = Boolean(poolId);

  const { data: raw, isLoading, isError, refetch } = useReadContract({
    address: CONTRACTS.lendingPool,
    abi: LendingPoolAbi,
    functionName: 'getPoolState',
    args: poolId ? [poolId] : undefined,
    query: {
      enabled,
      refetchInterval: BLOCK_TIME_MS * 6, // Refresh every ~6 blocks (12s)
    },
  });

  let data: LendingPoolState | undefined;
  if (raw) {
    const t = raw as readonly [bigint, bigint, bigint, bigint, bigint];
    data = {
      totalDeposited:           t[0],
      totalBorrowed:            t[1],
      totalShares:              t[2],
      lastUpdateTime:           t[3],
      accumulatedProtocolFees:  t[4],
    };
  }

  return { data, isLoading, isError, refetch };
}
