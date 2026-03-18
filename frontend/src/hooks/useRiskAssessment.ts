import { useReadContract } from 'wagmi';
import { CONTRACTS, BLOCK_TIME_MS } from '@/lib/constants';
import { RiskEngineAbi } from '@/lib/abis';
import type { RiskAssessment } from '@/types';

interface UseRiskAssessmentResult {
  assessment: RiskAssessment | undefined;
  isLoading: boolean;
  isError: boolean;
}

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as const;

/**
 * Reads RiskEngine.assessRisk(borrower) to get a full risk snapshot
 * including collateral/debt USD values, health factor, and flags.
 */
export function useRiskAssessment(borrower: `0x${string}` | undefined): UseRiskAssessmentResult {
  const enabled = Boolean(borrower && borrower !== ZERO_ADDRESS);

  const { data: raw, isLoading, isError } = useReadContract({
    address: CONTRACTS.riskEngine,
    abi: RiskEngineAbi,
    functionName: 'assessRisk',
    args: borrower ? [borrower] : undefined,
    query: {
      enabled,
      refetchInterval: BLOCK_TIME_MS * 6,
    },
  });

  let assessment: RiskAssessment | undefined;
  if (raw) {
    const r = raw as {
      borrower: `0x${string}`;
      healthFactor: bigint;
      collateralValueUSD: bigint;
      debtValueUSD: bigint;
      liquidationThreshold: bigint;
      isLiquidatable: boolean;
      isExpired: boolean;
      isWarning: boolean;
    };
    assessment = {
      borrower: r.borrower,
      healthFactor: r.healthFactor,
      collateralValueUSD: r.collateralValueUSD,
      debtValueUSD: r.debtValueUSD,
      liquidationThreshold: r.liquidationThreshold,
      isLiquidatable: r.isLiquidatable,
      isExpired: r.isExpired,
      isWarning: r.isWarning,
    };
  }

  return { assessment, isLoading, isError };
}
