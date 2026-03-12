import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS } from '@/lib/constants';
import { LendingPoolAbi } from '@/lib/abis';

interface UseDepositResult {
  deposit: (poolId: `0x${string}`, lender: `0x${string}`, amount: bigint) => void;
  isPending: boolean;
  isSuccess: boolean;
  error: string | null;
}

/**
 * Calls LendingPool.deposit(poolId, lender, amount).
 * On success, invalidates usePoolState queries to reflect the updated pool state.
 */
export function useDeposit(): UseDepositResult {
  const queryClient = useQueryClient();

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

  const deposit = (poolId: `0x${string}`, lender: `0x${string}`, amount: bigint) => {
    if (amount === 0n) return;
    writeContract({
      address: CONTRACTS.lendingPool,
      abi: LendingPoolAbi,
      functionName: 'deposit',
      args: [poolId, lender, amount],
    });
  };

  const errorMessage = writeError
    ? (writeError.message.includes('User rejected')
        ? 'Transaction rejected in wallet.'
        : 'Deposit failed. Check your balance and try again.')
    : null;

  return {
    deposit,
    isPending: isWritePending || isConfirming,
    isSuccess,
    error: errorMessage,
  };
}
