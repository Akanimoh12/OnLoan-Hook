import { useReadContract, useReadContracts } from 'wagmi';
import { CONTRACTS, BLOCK_TIME_MS, HF_LIQUIDATION_THRESHOLD, HF_WARNING_THRESHOLD } from '@/lib/constants';
import { LoanManagerAbi, OnLoanHookAbi } from '@/lib/abis';
import { getHealthStatus } from '@/lib/sdk';
import type { BorrowerRiskRow } from '@/types';

interface UseLiquidationsResult {
  liquidatable: BorrowerRiskRow[];
  atRisk: BorrowerRiskRow[];
  all: BorrowerRiskRow[];
  isLoading: boolean;
  isError: boolean;
  refetch: () => void;
}

/**
 * Fetches all active borrowers from LoanManager, reads their health factors,
 * and classifies them into liquidatable and at-risk buckets.
 * Refreshes every 30 seconds.
 */
export function useLiquidations(): UseLiquidationsResult {
  const {
    data: rawBorrowers,
    isLoading: loadingBorrowers,
    isError: errorBorrowers,
    refetch,
  } = useReadContract({
    address: CONTRACTS.loanManager,
    abi: LoanManagerAbi,
    functionName: 'getActiveBorrowers',
    query: {
      refetchInterval: 30_000,
    },
  });

  const borrowers = (rawBorrowers as `0x${string}`[] | undefined) ?? [];

  // Multicall to read health factors for all active borrowers
  const {
    data: healthFactorsData,
    isLoading: loadingHF,
    isError: errorHF,
  } = useReadContracts({
    contracts: borrowers.map((borrower) => ({
      address: CONTRACTS.onLoanHook,
      abi: OnLoanHookAbi,
      functionName: 'getHealthFactor',
      args: [borrower],
    })),
    query: {
      enabled: borrowers.length > 0,
      refetchInterval: BLOCK_TIME_MS * 15,
    },
  });

  // Build risk rows from available data
  const rows: BorrowerRiskRow[] = borrowers.map((address, index) => {
    // Return early if multicall hasn't completed or reverted for this borrower
    const hfResult = healthFactorsData && healthFactorsData[index];
    const hf = hfResult?.status === 'success' && hfResult.result !== undefined 
        ? (hfResult.result as bigint) 
        : HF_WARNING_THRESHOLD;

    return {
      address,
      healthFactor: hf,
      status: getHealthStatus(hf),
      collateralValueUSD: 0n, // Populated via RiskEngine.assessRisk() in integration phase
      debtValueUSD: 0n,       // Populated via RiskEngine.assessRisk() in integration phase
    };
  });

  const liquidatable = rows.filter((r) => r.healthFactor < HF_LIQUIDATION_THRESHOLD);
  const atRisk       = rows.filter(
    (r) =>
      r.healthFactor >= HF_LIQUIDATION_THRESHOLD &&
      r.healthFactor < HF_WARNING_THRESHOLD,
  );

  return {
    liquidatable,
    atRisk,
    all: rows,
    isLoading: loadingBorrowers || loadingHF,
    isError: errorBorrowers || errorHF,
    refetch,
  };
}
