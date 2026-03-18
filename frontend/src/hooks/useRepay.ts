import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS, DEFAULT_POOL_KEY } from '@/lib/constants';
import { PoolManagerAbi } from '@/lib/abis';
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

    const poolKey = {
      currency0: DEFAULT_POOL_KEY.currency0,
      currency1: DEFAULT_POOL_KEY.currency1,
      fee: DEFAULT_POOL_KEY.fee,
      tickSpacing: DEFAULT_POOL_KEY.tickSpacing,
      hooks: DEFAULT_POOL_KEY.hooks,
    };

    // Repayment is submitted as a zero-amount donate call through the PoolManager
    // with hookData to trigger beforeDonate/afterDonate on the OnLoanHook.
    writeContract({
      address: CONTRACTS.poolManager,
      abi: PoolManagerAbi,
      functionName: 'donate',
      args: [poolKey, 0n, 0n, hookData],
    });
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
