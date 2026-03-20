import { useRef, useEffect, useCallback } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS, TOKENS, BLOCK_TIME_MS } from '@/lib/constants';
import { OnLoanHookAbi, MockERC20Abi } from '@/lib/abis';

interface UseDepositResult {
  deposit: (poolId: `0x${string}`, amount: bigint) => void;
  needsApproval: boolean;
  approve: () => void;
  isPending: boolean;
  isApproving: boolean;
  isSuccess: boolean;
  error: string | null;
}

export function useDeposit(): UseDepositResult {
  const queryClient = useQueryClient();
  const { address } = useAccount();

  // Persist deposit intent across renders
  const pendingPoolId = useRef<`0x${string}` | null>(null);
  const pendingAmount = useRef<bigint>(0n);

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

  // Approval transaction
  const {
    writeContract: writeApprove,
    data: approveTxHash,
    isPending: isApprovePending,
    error: approveError,
    reset: resetApprove,
  } = useWriteContract();

  const { isLoading: isApproveConfirming, isSuccess: isApproveSuccess } =
    useWaitForTransactionReceipt({ hash: approveTxHash });

  // Deposit transaction
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

  // After approval confirms, auto-trigger the deposit
  useEffect(() => {
    if (isApproveSuccess && pendingPoolId.current && pendingAmount.current > 0n) {
      resetApprove();
      refetchAllowance().then(() => {
        writeContract({
          address: CONTRACTS.onLoanHook,
          abi: OnLoanHookAbi,
          functionName: 'depositDirect',
          args: [pendingPoolId.current!, pendingAmount.current],
        });
        pendingPoolId.current = null;
        pendingAmount.current = 0n;
      });
    }
  }, [isApproveSuccess]);

  // After deposit confirms, invalidate caches
  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries();
      reset();
    }
  }, [isSuccess]);

  const needsApproval = pendingAmount.current > 0n && currentAllowance < pendingAmount.current;

  const approve = useCallback(() => {
    writeApprove({
      address: TOKENS.USDC.address,
      abi: MockERC20Abi,
      functionName: 'approve',
      args: [CONTRACTS.onLoanHook, pendingAmount.current],
    });
  }, [writeApprove]);

  const deposit = useCallback((poolId: `0x${string}`, amount: bigint) => {
    if (amount === 0n) return;
    pendingPoolId.current = poolId;
    pendingAmount.current = amount;

    // If insufficient allowance, approve first — deposit auto-fires after approval
    if (currentAllowance < amount) {
      writeApprove({
        address: TOKENS.USDC.address,
        abi: MockERC20Abi,
        functionName: 'approve',
        args: [CONTRACTS.onLoanHook, amount],
      });
      return;
    }

    writeContract({
      address: CONTRACTS.onLoanHook,
      abi: OnLoanHookAbi,
      functionName: 'depositDirect',
      args: [poolId, amount],
    });
  }, [currentAllowance, writeApprove, writeContract]);

  const errorMessage = (writeError || approveError)
    ? ((writeError || approveError)!.message.includes('User rejected')
        ? 'Transaction rejected in wallet.'
        : 'Deposit failed. Make sure you have approved USDC and have sufficient balance.')
    : null;

  return {
    deposit,
    needsApproval,
    approve,
    isPending: isWritePending || isConfirming,
    isApproving: isApprovePending || isApproveConfirming,
    isSuccess,
    error: errorMessage,
  };
}
