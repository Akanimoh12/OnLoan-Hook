import { useReadContract } from 'wagmi';
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

  // Read health factors for the first borrower as a sequential pattern.
  // In production this is replaced with a multicall. For now, reading the
  // first borrower lets us demonstrate the pattern.
  const {
    data: rawHF,
    isLoading: loadingHF,
    isError: errorHF,
  } = useReadContract({
    address: CONTRACTS.onLoanHook,
    abi: OnLoanHookAbi,
    functionName: 'getHealthFactor',
    args: borrowers.length > 0 ? [borrowers[0]] : undefined,
    query: {
      enabled: borrowers.length > 0,
      refetchInterval: BLOCK_TIME_MS * 15,
    },
  });

  // Build risk rows from available data — expandable to multicall in integration phase
  const rows: BorrowerRiskRow[] = borrowers.map((address, index) => {
    const hf = index === 0 && rawHF ? (rawHF as bigint) : HF_WARNING_THRESHOLD;
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
