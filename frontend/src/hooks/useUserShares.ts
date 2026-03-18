import { useReadContract } from 'wagmi';
import { useAccount } from 'wagmi';
import { CONTRACTS } from '@/lib/constants';
import { LendingPoolAbi } from '@/lib/abis';

interface UseUserSharesResult {
  shares: bigint;
  isLoading: boolean;
}

/**
 * Reads the connected user's share balance for a given pool from LendingPool.
 * Uses getLenderShares(poolId, lender).
 */
export function useUserShares(poolId: `0x${string}` | undefined): UseUserSharesResult {
  const { address } = useAccount();
  const enabled = Boolean(poolId && address);

  const { data: raw, isLoading } = useReadContract({
    address: CONTRACTS.lendingPool,
    abi: LendingPoolAbi,
    functionName: 'getLenderShares',
    args: poolId && address ? [poolId, address] : undefined,
    query: {
      enabled,
      refetchInterval: 30_000,
    },
  });

  return {
    shares: (raw as bigint) ?? 0n,
    isLoading,
  };
}
