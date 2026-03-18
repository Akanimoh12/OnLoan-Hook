import { useReadContract } from 'wagmi';
import { CONTRACTS, BLOCK_TIME_MS, HF_LIQUIDATION_THRESHOLD, HF_WARNING_THRESHOLD } from '@/lib/constants';
import { LoanManagerAbi, RiskEngineAbi } from '@/lib/abis';
import { getHealthStatus } from '@/lib/sdk';
import type { BorrowerRiskRow, RiskAssessment } from '@/types';

interface UseLiquidationsResult {
  liquidatable: BorrowerRiskRow[];
  atRisk: BorrowerRiskRow[];
  all: BorrowerRiskRow[];
  isLoading: boolean;
  isError: boolean;
  refetch: () => void;
}

/**
 * Fetches all active borrowers from LoanManager, then uses RiskEngine.batchAssessRisk() 
 * to get full risk data (health factor, collateral/debt USD) for each borrower.
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

  // Use RiskEngine.batchAssessRisk() to get full risk data for all borrowers
  const {
    data: rawAssessments,
    isLoading: loadingRisk,
    isError: errorRisk,
  } = useReadContract({
    address: CONTRACTS.riskEngine,
    abi: RiskEngineAbi,
    functionName: 'batchAssessRisk',
    args: borrowers.length > 0 ? [borrowers] : undefined,
    query: {
      enabled: borrowers.length > 0,
      refetchInterval: BLOCK_TIME_MS * 15,
    },
  });

  const assessments = (rawAssessments as RiskAssessment[] | undefined) ?? [];

  // Build risk rows from RiskEngine data
  const rows: BorrowerRiskRow[] = borrowers.map((address, index) => {
    const a = assessments[index];
    const hf = a?.healthFactor ?? HF_WARNING_THRESHOLD;

    return {
      address,
      healthFactor: hf,
      status: getHealthStatus(hf),
      collateralValueUSD: a?.collateralValueUSD ?? 0n,
      debtValueUSD: a?.debtValueUSD ?? 0n,
      isLiquidatable: a?.isLiquidatable ?? false,
      isExpired: a?.isExpired ?? false,
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
    isLoading: loadingBorrowers || loadingRisk,
    isError: errorBorrowers || errorRisk,
    refetch,
  };
}
