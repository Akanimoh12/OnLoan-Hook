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
    const t = rawLoan as readonly [
      `0x${string}`, `0x${string}`,
      bigint, bigint, bigint, bigint,
      bigint, bigint, bigint,
      boolean,
    ];
    loan = {
      borrower:                  t[0],
      collateralToken:           t[1],
      collateralAmount:          t[2],
      borrowedAmount:            t[3],
      accruedInterest:           t[4],
      interestRateAtOrigination: t[5],
      startTime:                 t[6],
      lastAccrualTime:           t[7],
      duration:                  t[8],
      active:                    t[9],
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
