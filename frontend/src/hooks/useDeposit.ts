import { useState, useCallback } from 'react';
import { useWriteContract, useReadContract, useAccount, usePublicClient } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS, TOKENS, BLOCK_TIME_MS } from '@/lib/constants';
import { OnLoanHookAbi, MockERC20Abi } from '@/lib/abis';

type Step = 'idle' | 'approving' | 'depositing' | 'success';

interface UseDepositResult {
  deposit: (poolId: `0x${string}`, amount: bigint) => void;
  isPending: boolean;
  isApproving: boolean;
  isSuccess: boolean;
  error: string | null;
}

export function useDeposit(): UseDepositResult {
  const queryClient = useQueryClient();
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync } = useWriteContract();

  const [step, setStep] = useState<Step>('idle');
  const [error, setError] = useState<string | null>(null);

  // Read current allowance
  const { data: allowance } = useReadContract({
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

  const deposit = useCallback(async (poolId: `0x${string}`, amount: bigint) => {
    if (amount === 0n || !publicClient) return;
    setError(null);

    try {
      // Step 1: Approve if needed
      if (currentAllowance < amount) {
        setStep('approving');
        const approveHash = await writeContractAsync({
          address: TOKENS.USDC.address,
          abi: MockERC20Abi,
          functionName: 'approve',
          args: [CONTRACTS.onLoanHook, amount],
        });
        await publicClient.waitForTransactionReceipt({ hash: approveHash });
      }

      // Step 2: Deposit
      setStep('depositing');
      const depositHash = await writeContractAsync({
        address: CONTRACTS.onLoanHook,
        abi: OnLoanHookAbi,
        functionName: 'depositDirect',
        args: [poolId, amount],
      });
      await publicClient.waitForTransactionReceipt({ hash: depositHash });

      // Done
      setStep('success');
      queryClient.invalidateQueries();
      setTimeout(() => setStep('idle'), 3000);
    } catch (err: unknown) {
      const msg = err instanceof Error && (err.message.includes('User rejected') || err.message.includes('User denied'))
        ? 'Transaction rejected in wallet.'
        : 'Deposit failed. Check your USDC balance and try again.';
      setError(msg);
      setStep('idle');
    }
  }, [currentAllowance, publicClient, writeContractAsync, queryClient]);

  return {
    deposit,
    isPending: step === 'depositing',
    isApproving: step === 'approving',
    isSuccess: step === 'success',
    error,
  };
}
