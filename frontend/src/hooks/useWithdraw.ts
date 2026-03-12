import { useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { useAccount } from 'wagmi';
import { CONTRACTS, BLOCK_TIME_MS } from '@/lib/constants';
import { LendingPoolAbi } from '@/lib/abis';

interface UseWithdrawResult {
  withdraw: (poolId: `0x${string}`, shares: bigint) => void;
  canWithdraw: boolean;
  isPending: boolean;
  isSuccess: boolean;
  error: string | null;
}

/**
 * Checks LendingPool.canWithdraw(poolId, lender) before exposing the withdraw action.
 * Surfaces a human-readable error if the cooldown has not elapsed.
 */
export function useWithdraw(poolId: `0x${string}` | undefined): UseWithdrawResult {
  const queryClient = useQueryClient();
  const { address } = useAccount();

  const enabled = Boolean(poolId && address);

  const { data: canWithdrawRaw } = useReadContract({
    address: CONTRACTS.lendingPool,
    abi: LendingPoolAbi,
    functionName: 'canWithdraw',
    args: poolId && address ? [poolId, address] : undefined,
    query: {
      enabled,
      refetchInterval: BLOCK_TIME_MS * 6,
    },
  });

  const canWithdraw = Boolean(canWithdrawRaw);

  const {
    writeContract,
    data: txHash,
    isPending: isWritePending,
    error: writeError,
    reset,
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  if (isSuccess) {
    queryClient.invalidateQueries();
    reset();
  }

  const withdraw = (poolId: `0x${string}`, shares: bigint) => {
    if (!canWithdraw) return;
    if (shares === 0n || !address) return;
    writeContract({
      address: CONTRACTS.lendingPool,
      abi: LendingPoolAbi,
      functionName: 'withdraw',
      args: [poolId, address, shares],
    });
  };

  let errorMessage: string | null = null;
  if (!canWithdraw && poolId && address) {
    errorMessage = 'Withdrawal cooldown has not elapsed. Please wait before withdrawing.';
  } else if (writeError) {
    errorMessage = writeError.message.includes('User rejected')
      ? 'Transaction rejected in wallet.'
      : 'Withdrawal failed. Try again.';
  }

  return {
    withdraw,
    canWithdraw,
    isPending: isWritePending || isConfirming,
    isSuccess,
    error: errorMessage,
  };
}
