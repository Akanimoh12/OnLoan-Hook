import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS } from '@/lib/constants';
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

    // Hardcoded PoolKey for the MVP integration (USDC/WETH pair)
    const currency0 = '0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6' as `0x${string}`; // USDC
    const currency1 = '0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D' as `0x${string}`; // WETH

    const poolKey = {
      currency0,
      currency1,
      fee: 3000,
      tickSpacing: 60,
      hooks: CONTRACTS.onLoanHook,
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
