import { useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/constants';
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
      refetchInterval: 30_000,
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
      refetchInterval: 30_000,
    },
  });

  let loan: Loan | undefined;
  if (rawLoan) {
    // Cast to the expected tuple return type from OnLoanHook.getLoan
    // [borrower, collateralToken, collateralAmount, borrowedAmount, accruedInterest, interestRateAtOrigination, startTime, lastAccrualTime, duration, active]
    const r = rawLoan as readonly [
      `0x${string}`, // borrower
      `0x${string}`, // collateralToken
      bigint,        // collateralAmount
      bigint,        // borrowedAmount
      bigint,        // accruedInterest
      bigint,        // interestRateAtOrigination
      bigint,        // startTime
      bigint,        // lastAccrualTime
      bigint,        // duration
      boolean,       // active
    ] | {
      borrower: `0x${string}`;
      collateralToken: `0x${string}`;
      collateralAmount: bigint;
      borrowedAmount: bigint;
      accruedInterest: bigint;
      interestRateAtOrigination: bigint;
      startTime: bigint;
      lastAccrualTime: bigint;
      duration: bigint;
      active: boolean;
    };
    
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore - wagmi returns an array with named properties, so we check both
    loan = {
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      borrower:                  r.borrower !== undefined ? r.borrower : r[0],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      collateralToken:           r.collateralToken !== undefined ? r.collateralToken : r[1],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      collateralAmount:          r.collateralAmount !== undefined ? r.collateralAmount : r[2],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      borrowedAmount:            r.borrowedAmount !== undefined ? r.borrowedAmount : r[3],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      accruedInterest:           r.accruedInterest !== undefined ? r.accruedInterest : r[4],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      interestRateAtOrigination: r.interestRateAtOrigination !== undefined ? r.interestRateAtOrigination : r[5],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      startTime:                 r.startTime !== undefined ? r.startTime : r[6],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      lastAccrualTime:           r.lastAccrualTime !== undefined ? r.lastAccrualTime : r[7],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      duration:                  r.duration !== undefined ? r.duration : r[8],
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
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
