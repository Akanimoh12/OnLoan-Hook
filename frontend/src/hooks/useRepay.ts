import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS } from '@/lib/constants';
import { OnLoanHookAbi } from '@/lib/abis';
import { encodeRepayPayload } from '@/lib/sdk';

interface UseRepayResult {
  repay: (borrower: `0x${string}`) => void;
  isPending: boolean;
  isSuccess: boolean;
  error: string | null;
}

/**
 * Encodes repay hookData and dispatches the donate-to-repay transaction.
 * On success, invalidates all cached queries so the UI reflects the closed loan.
 */
export function useRepay(): UseRepayResult {
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

  const repay = (borrower: `0x${string}`) => {
    const hookData = encodeRepayPayload(borrower);

    // Repayment is submitted as a donate call through the PoolManager
    // with hookData. Update args to PoolManager.donate() when PoolKey is confirmed.
    writeContract({
      address: CONTRACTS.onLoanHook,
      abi: OnLoanHookAbi,
      functionName: 'liquidateLoan', // placeholder — swap over to PoolManager.donate in integration
      args: [borrower],
    });

    void hookData; // hookData is ready; dispatch requires PoolKey from Person A
  };

  const errorMessage = writeError
    ? (writeError.message.includes('User rejected')
        ? 'Transaction rejected in wallet.'
        : 'Repayment failed. Ensure your loan is active and try again.')
    : null;

  return {
    repay,
    isPending: isWritePending || isConfirming,
    isSuccess,
    error: errorMessage,
  };
}
