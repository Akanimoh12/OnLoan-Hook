import { useState, useEffect, useCallback, useRef } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS, TOKENS, BLOCK_TIME_MS } from '@/lib/constants';
import { OnLoanHookAbi, MockERC20Abi } from '@/lib/abis';

type Phase = 'idle' | 'approving' | 'waitingApproval' | 'depositing' | 'waitingDeposit' | 'success';

interface UseDepositResult {
  deposit: (poolId: `0x${string}`, amount: bigint) => void;
  isPending: boolean;
  isApproving: boolean;
  isSuccess: boolean;
  error: string | null;
  resetState: () => void;
}

export function useDeposit(): UseDepositResult {
  const queryClient = useQueryClient();
  const { address } = useAccount();

  const [phase, setPhase] = useState<Phase>('idle');
  const [error, setError] = useState<string | null>(null);

  // Store deposit intent so it survives across renders
  const poolIdRef = useRef<`0x${string}` | null>(null);
  const amountRef = useRef<bigint>(0n);

  // Read current allowance of USDC for the OnLoanHook
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: TOKENS.USDC.address,
    abi: MockERC20Abi,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.onLoanHook] : undefined,
    query: {
      enabled: Boolean(address),
      refetchInterval: BLOCK_TIME_MS * 3,
    },
  });

  const currentAllowance = (allowance as bigint) ?? 0n;

  // --- Approve TX ---
  const {
    writeContract: sendApprove,
    data: approveTxHash,
    isPending: isApproveSending,
    error: approveWriteError,
    reset: resetApprove,
  } = useWriteContract();

  const {
    isLoading: isApproveMining,
    isSuccess: isApproveConfirmed,
    error: approveReceiptError,
  } = useWaitForTransactionReceipt({ hash: approveTxHash });

  // --- Deposit TX ---
  const {
    writeContract: sendDeposit,
    data: depositTxHash,
    isPending: isDepositSending,
    error: depositWriteError,
    reset: resetDeposit,
  } = useWriteContract();

  const {
    isLoading: isDepositMining,
    isSuccess: isDepositConfirmed,
    error: depositReceiptError,
  } = useWaitForTransactionReceipt({ hash: depositTxHash });

  // --- Phase: approval confirmed → fire the deposit ---
  useEffect(() => {
    if (phase === 'waitingApproval' && isApproveConfirmed) {
      setPhase('depositing');
      // Refetch allowance, then fire deposit
      refetchAllowance().then(() => {
        if (poolIdRef.current && amountRef.current > 0n) {
          sendDeposit({
            address: CONTRACTS.onLoanHook,
            abi: OnLoanHookAbi,
            functionName: 'depositDirect',
            args: [poolIdRef.current, amountRef.current],
          });
          setPhase('waitingDeposit');
        }
      });
    }
  }, [phase, isApproveConfirmed, refetchAllowance, sendDeposit]);

  // --- Phase: deposit confirmed → done ---
  useEffect(() => {
    if (phase === 'waitingDeposit' && isDepositConfirmed) {
      setPhase('success');
      queryClient.invalidateQueries();
      // Auto-reset after a short delay so the UI can show "success"
      const timer = setTimeout(() => {
        resetApprove();
        resetDeposit();
        poolIdRef.current = null;
        amountRef.current = 0n;
        setPhase('idle');
      }, 2000);
      return () => clearTimeout(timer);
    }
  }, [phase, isDepositConfirmed, queryClient, resetApprove, resetDeposit]);

  // --- Catch errors at any stage ---
  useEffect(() => {
    const err = approveWriteError || approveReceiptError || depositWriteError || depositReceiptError;
    if (err && phase !== 'idle') {
      const msg = err.message?.includes('User rejected') || err.message?.includes('User denied')
        ? 'Transaction rejected in wallet.'
        : 'Deposit failed. Make sure you have approved USDC and have sufficient balance.';
      setError(msg);
      // Reset everything so user can retry
      resetApprove();
      resetDeposit();
      setPhase('idle');
    }
  }, [approveWriteError, approveReceiptError, depositWriteError, depositReceiptError, phase, resetApprove, resetDeposit]);

  // --- Entry point ---
  const deposit = useCallback((poolId: `0x${string}`, amount: bigint) => {
    if (amount === 0n) return;
    setError(null);

    poolIdRef.current = poolId;
    amountRef.current = amount;

    if (currentAllowance < amount) {
      // Need approval first
      setPhase('approving');
      sendApprove({
        address: TOKENS.USDC.address,
        abi: MockERC20Abi,
        functionName: 'approve',
        args: [CONTRACTS.onLoanHook, amount],
      });
      setPhase('waitingApproval');
    } else {
      // Allowance sufficient — deposit directly
      setPhase('depositing');
      sendDeposit({
        address: CONTRACTS.onLoanHook,
        abi: OnLoanHookAbi,
        functionName: 'depositDirect',
        args: [poolId, amount],
      });
      setPhase('waitingDeposit');
    }
  }, [currentAllowance, sendApprove, sendDeposit]);

  const resetState = useCallback(() => {
    resetApprove();
    resetDeposit();
    poolIdRef.current = null;
    amountRef.current = 0n;
    setPhase('idle');
    setError(null);
  }, [resetApprove, resetDeposit]);

  return {
    deposit,
    isPending: phase === 'depositing' || phase === 'waitingDeposit' || isDepositSending || isDepositMining,
    isApproving: phase === 'approving' || phase === 'waitingApproval' || isApproveSending || isApproveMining,
    isSuccess: phase === 'success',
    error,
    resetState,
  };
}
