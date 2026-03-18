import * as React from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS } from '@/lib/constants';
import { LiquidationEngineAbi } from '@/lib/abis';

interface UseLiquidateResult {
  liquidate: (borrower: `0x${string}`) => void;
  isPending: boolean;
  isSuccess: boolean;
  error: string | null;
  targetBorrower: `0x${string}` | null;
}

/**
 * Calls LiquidationEngine.liquidateLoan(borrower) to execute a liquidation.
 * On success, invalidates all queries to reflect collateral seizure and loan closure.
 */
export function useLiquidate(): UseLiquidateResult {
  const queryClient = useQueryClient();
  const [targetBorrower, setTargetBorrower] = React.useState<`0x${string}` | null>(null);

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
    setTargetBorrower(null);
    reset();
  }

  const liquidate = (borrower: `0x${string}`) => {
    setTargetBorrower(borrower);
    writeContract({
      address: CONTRACTS.liquidationEngine,
      abi: LiquidationEngineAbi,
      functionName: 'liquidateLoan',
      args: [borrower],
    });
  };

  const errorMessage = writeError
    ? (writeError.message.includes('User rejected')
        ? 'Transaction rejected in wallet.'
        : writeError.message.includes('HealthFactorAboveThreshold')
          ? 'Position is not liquidatable — health factor is above threshold.'
          : 'Liquidation failed. The position may no longer be liquidatable.')
    : null;

  return {
    liquidate,
    isPending: isWritePending || isConfirming,
    isSuccess,
    error: errorMessage,
    targetBorrower,
  };
}
