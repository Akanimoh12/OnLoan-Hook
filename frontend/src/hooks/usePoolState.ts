import { useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/constants';
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
      refetchInterval: 30_000,
    },
  });

  let data: LendingPoolState | undefined;
  if (raw) {
    const r = raw as readonly [bigint, bigint, bigint, bigint, bigint] | {
      totalDeposited: bigint;
      totalBorrowed: bigint;
      totalShares: bigint;
      lastUpdateTime: bigint;
      accumulatedProtocolFees: bigint;
    };
    
    data = {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      totalDeposited:           r.totalDeposited !== undefined ? r.totalDeposited : r[0],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      totalBorrowed:            r.totalBorrowed !== undefined ? r.totalBorrowed : r[1],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      totalShares:              r.totalShares !== undefined ? r.totalShares : r[2],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      lastUpdateTime:           r.lastUpdateTime !== undefined ? r.lastUpdateTime : r[3],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      accumulatedProtocolFees:  r.accumulatedProtocolFees !== undefined ? r.accumulatedProtocolFees : r[4],
    };
  }

  return { data, isLoading, isError, refetch };
}
