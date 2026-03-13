import { useReadContract } from 'wagmi';
import { CONTRACTS, BLOCK_TIME_MS } from '@/lib/constants';
import { OnLoanHookAbi } from '@/lib/abis';
import type { Loan } from '@/types';

interface UseLoanResult {
  loan: Loan | undefined;
  healthFactor: bigint | undefined;
  isLoading: boolean;
  isError: boolean;
  refetch: () => void;
}

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as const;

/**
 * Reads OnLoanHook.getLoan(borrower) and OnLoanHook.getHealthFactor(borrower).
 * Only fetches when a valid, non-zero borrower address is provided.
 */
export function useLoan(borrower: `0x${string}` | undefined): UseLoanResult {
  const enabled = Boolean(borrower && borrower !== ZERO_ADDRESS);

  const {
    data: rawLoan,
    isLoading: loadingLoan,
    isError: errorLoan,
    refetch,
  } = useReadContract({
    address: CONTRACTS.onLoanHook,
    abi: OnLoanHookAbi,
    functionName: 'getLoan',
    args: borrower ? [borrower] : undefined,
    query: {
      enabled,
      refetchInterval: BLOCK_TIME_MS * 6,
    },
  });

  const {
    data: rawHF,
    isLoading: loadingHF,
    isError: errorHF,
  } = useReadContract({
    address: CONTRACTS.onLoanHook,
    abi: OnLoanHookAbi,
    functionName: 'getHealthFactor',
    args: borrower ? [borrower] : undefined,
    query: {
      enabled,
      refetchInterval: BLOCK_TIME_MS * 6,
    },
  });

  let loan: Loan | undefined;
  if (rawLoan) {
    const r = rawLoan as any;
    loan = {
      borrower:                  r.borrower !== undefined ? r.borrower : r[0],
      collateralToken:           r.collateralToken !== undefined ? r.collateralToken : r[1],
      collateralAmount:          r.collateralAmount !== undefined ? r.collateralAmount : r[2],
      borrowedAmount:            r.borrowedAmount !== undefined ? r.borrowedAmount : r[3],
      accruedInterest:           r.accruedInterest !== undefined ? r.accruedInterest : r[4],
      interestRateAtOrigination: r.interestRateAtOrigination !== undefined ? r.interestRateAtOrigination : r[5],
      startTime:                 r.startTime !== undefined ? r.startTime : r[6],
      lastAccrualTime:           r.lastAccrualTime !== undefined ? r.lastAccrualTime : r[7],
      duration:                  r.duration !== undefined ? r.duration : r[8],
      active:                    r.active !== undefined ? r.active : r[9],
    };
  }

  return {
    loan,
    healthFactor: rawHF as bigint | undefined,
    isLoading: loadingLoan || loadingHF,
    isError: errorLoan || errorHF,
    refetch,
  };
}
