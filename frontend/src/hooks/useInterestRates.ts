import { useReadContract } from 'wagmi';
import { CONTRACTS, PROTOCOL_FEE_BPS } from '@/lib/constants';
import { InterestRateModelAbi } from '@/lib/abis';
import { usePoolState } from './usePoolState';

interface UseInterestRatesResult {
  borrowRateBps: bigint;
  supplyRateBps: bigint;
  utilizationBps: bigint;
  isLoading: boolean;
  isError: boolean;
}

/**
 * Reads live borrow and supply APRs from the InterestRateModel contract
 * based on current pool utilization.
 */
export function useInterestRates(poolId: `0x${string}` | undefined): UseInterestRatesResult {
  const { data: poolState, isLoading: loadingPool } = usePoolState(poolId);

  const totalDeposited = poolState?.totalDeposited ?? 0n;
  const totalBorrowed = poolState?.totalBorrowed ?? 0n;
  const hasData = Boolean(poolState) && totalDeposited > 0n;

  const { data: borrowRate, isLoading: loadingBorrow, isError: errorBorrow } = useReadContract({
    address: CONTRACTS.interestRateModel,
    abi: InterestRateModelAbi,
    functionName: 'getBorrowRate',
    args: poolId ? [poolId, totalDeposited, totalBorrowed] : undefined,
    query: {
      enabled: hasData && Boolean(poolId),
      refetchInterval: 30_000,
    },
  });

  const { data: supplyRate, isLoading: loadingSupply, isError: errorSupply } = useReadContract({
    address: CONTRACTS.interestRateModel,
    abi: InterestRateModelAbi,
    functionName: 'getSupplyRate',
    args: poolId ? [poolId, totalDeposited, totalBorrowed, PROTOCOL_FEE_BPS] : undefined,
    query: {
      enabled: hasData && Boolean(poolId),
      refetchInterval: 30_000,
    },
  });

  const utilizationBps = totalDeposited > 0n
    ? (totalBorrowed * 10_000n) / totalDeposited
    : 0n;

  return {
    borrowRateBps: (borrowRate as bigint) ?? 0n,
    supplyRateBps: (supplyRate as bigint) ?? 0n,
    utilizationBps,
    isLoading: loadingPool || loadingBorrow || loadingSupply,
    isError: errorBorrow || errorSupply,
  };
}
