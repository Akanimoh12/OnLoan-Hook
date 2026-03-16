import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS } from '@/lib/constants';
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

    // Hardcoded PoolKey for the MVP integration (USDC/WETH pair)
    // We assume currency0 is USDC and currency1 is WETH for demonstration.
    // In a production environment with multiple pools, this would be computed
    // dynamically based on token addresses.
    const currency0 = '0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6' as `0x${string}`; // USDC
    const currency1 = '0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D' as `0x${string}`; // WETH

    const poolKey = {
      currency0,
      currency1,
      fee: 3000,
      tickSpacing: 60,
      hooks: CONTRACTS.onLoanHook,
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
