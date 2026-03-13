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
    const r = raw as any;
    data = {
      totalDeposited:           r.totalDeposited !== undefined ? r.totalDeposited : r[0],
      totalBorrowed:            r.totalBorrowed !== undefined ? r.totalBorrowed : r[1],
      totalShares:              r.totalShares !== undefined ? r.totalShares : r[2],
      lastUpdateTime:           r.lastUpdateTime !== undefined ? r.lastUpdateTime : r[3],
      accumulatedProtocolFees:  r.accumulatedProtocolFees !== undefined ? r.accumulatedProtocolFees : r[4],
    };
  }

  return { data, isLoading, isError, refetch };
}
