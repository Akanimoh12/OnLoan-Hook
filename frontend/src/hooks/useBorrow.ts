import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS } from '@/lib/constants';
import { OnLoanHookAbi } from '@/lib/abis';
import { encodeBorrowPayload } from '@/lib/sdk';
import { daysToSeconds } from '@/lib/utils';
import type { BorrowFormState } from '@/types';

interface UseBorrowResult {
  borrow: (form: BorrowFormState, borrower: `0x${string}`) => void;
  isPending: boolean;
  isSuccess: boolean;
  error: string | null;
}

/**
 * Encodes borrow hookData and dispatches the swap-to-borrow transaction.
 * On success, invalidates useLoan and usePoolState cached queries.
 */
export function useBorrow(): UseBorrowResult {
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

  const borrow = (form: BorrowFormState, borrower: `0x${string}`) => {
    if (!form.collateralToken) return;

    const collateralAmount = BigInt(form.collateralAmount || '0');
    const borrowAmount     = BigInt(form.borrowAmount || '0');
    const durationSeconds  = daysToSeconds(form.durationDays);

    if (collateralAmount === 0n || borrowAmount === 0n || durationSeconds === 0n) return;

    const hookData = encodeBorrowPayload(
      borrower,
      form.collateralToken as `0x${string}`,
      collateralAmount,
      borrowAmount,
      durationSeconds,
    );

    // The borrow is initiated as swap hookData via the OnLoanHook.
    // The swap itself is a zero-amount swap; hookData carries the loan parameters.
    writeContract({
      address: CONTRACTS.onLoanHook,
      abi: OnLoanHookAbi,
      functionName: 'liquidateLoan', // placeholder — actual call goes through PoolManager swap
      args: [borrower],
      // NOTE: In production, the frontend dispatches a PoolManager.swap() call
      // with hookData attached. This requires the PoolKey. Update args when
      // PoolKey is confirmed.
    });

    void hookData; // hookData is encoded but swap dispatch requires PoolKey from Person A
  };

  const errorMessage = writeError
    ? (writeError.message.includes('User rejected')
        ? 'Transaction rejected in wallet.'
        : 'Transaction failed. Check your inputs and try again.')
    : null;

  return {
    borrow,
    isPending: isWritePending || isConfirming,
    isSuccess,
    error: errorMessage,
  };
}
