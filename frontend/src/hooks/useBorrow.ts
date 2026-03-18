import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS, DEFAULT_POOL_KEY } from '@/lib/constants';
import { PoolManagerAbi } from '@/lib/abis';
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

    // Use the centralized pool key configuration
    const poolKey = {
      currency0: DEFAULT_POOL_KEY.currency0,
      currency1: DEFAULT_POOL_KEY.currency1,
      fee: DEFAULT_POOL_KEY.fee,
      tickSpacing: DEFAULT_POOL_KEY.tickSpacing,
      hooks: DEFAULT_POOL_KEY.hooks,
    };

    // Swap parameters for a zero-amount swap
    const swapParams = {
      zeroForOne: true,
      amountSpecified: 0n,
      sqrtPriceLimitX96: 0n, // Unused in zero-amount swaps, but required by struct
    };

    // The borrow is initiated as swap hookData via the OnLoanHook.
    // The swap itself is a zero-amount swap; hookData carries the loan parameters.
    writeContract({
      address: CONTRACTS.poolManager,
      abi: PoolManagerAbi,
      functionName: 'swap',
      args: [poolKey, swapParams, hookData],
    });
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
