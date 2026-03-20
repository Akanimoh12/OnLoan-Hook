import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { CONTRACTS, TOKENS, BLOCK_TIME_MS } from '@/lib/constants';
import { OnLoanHookAbi, MockERC20Abi } from '@/lib/abis';

interface UseDepositResult {
  /** Current USDC allowance the hook contract can spend */
  allowance: bigint;
  /** Send an ERC-20 approve TX for `amount` */
  approve: (amount: bigint) => void;
  isApproving: boolean;
  isApproveConfirmed: boolean;
  approveError: string | null;
  /** Send the depositDirect TX */
  deposit: (poolId: `0x${string}`, amount: bigint) => void;
  isDepositing: boolean;
  isDepositConfirmed: boolean;
  depositError: string | null;
}

export function useDeposit(): UseDepositResult {
  const queryClient = useQueryClient();
  const { address } = useAccount();

  // ---- Allowance read ----
  const { data: allowanceRaw } = useReadContract({
    address: TOKENS.USDC.address,
    abi: MockERC20Abi,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.onLoanHook] : undefined,
    query: { enabled: Boolean(address), refetchInterval: BLOCK_TIME_MS * 2 },
  });
  const allowance = (allowanceRaw as bigint) ?? 0n;

  // ---- Approve TX (standalone) ----
  const {
    writeContract: writeApprove,
    data: approveTxHash,
    isPending: isApproveSending,
    error: approveWriteErr,
    reset: resetApprove,
  } = useWriteContract();

  const {
    isLoading: isApproveMining,
    isSuccess: isApproveConfirmed,
    error: approveReceiptErr,
  } = useWaitForTransactionReceipt({ hash: approveTxHash });

  // Invalidate queries once approval lands so allowance refreshes
  if (isApproveConfirmed) {
    queryClient.invalidateQueries();
  }

  const approve = (amount: bigint) => {
    resetApprove();
    writeApprove({
      address: TOKENS.USDC.address,
      abi: MockERC20Abi,
      functionName: 'approve',
      args: [CONTRACTS.onLoanHook, amount],
    });
  };

  // ---- Deposit TX (standalone) ----
  const {
    writeContract: writeDeposit,
    data: depositTxHash,
    isPending: isDepositSending,
    error: depositWriteErr,
    reset: resetDeposit,
  } = useWriteContract();

  const {
    isLoading: isDepositMining,
    isSuccess: isDepositConfirmed,
    error: depositReceiptErr,
  } = useWaitForTransactionReceipt({ hash: depositTxHash });

  if (isDepositConfirmed) {
    queryClient.invalidateQueries();
  }

  const deposit = (poolId: `0x${string}`, amount: bigint) => {
    resetDeposit();
    writeDeposit({
      address: CONTRACTS.onLoanHook,
      abi: OnLoanHookAbi,
      functionName: 'depositDirect',
      args: [poolId, amount],
    });
  };

  // ---- Error formatting ----
  const fmtErr = (e: Error | null) => {
    if (!e) return null;
    if (e.message.includes('User rejected') || e.message.includes('User denied'))
      return 'Transaction rejected in wallet.';
    return e.message.length > 120 ? e.message.slice(0, 120) + '…' : e.message;
  };

  return {
    allowance,
    approve,
    isApproving: isApproveSending || isApproveMining,
    isApproveConfirmed,
    approveError: fmtErr(approveWriteErr) ?? fmtErr(approveReceiptErr),
    deposit,
    isDepositing: isDepositSending || isDepositMining,
    isDepositConfirmed,
    depositError: fmtErr(depositWriteErr) ?? fmtErr(depositReceiptErr),
  };
}
  };
}
