import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { MockERC20Abi } from '@/lib/abis';

type MintState = {
  isPending: boolean;
  isSuccess: boolean;
  error: string | null;
};

type UseMintTokensResult = {
  mint: (tokenAddress: `0x${string}`, to: `0x${string}`, amount: bigint) => void;
  states: Record<string, MintState>;
};

/**
 * Calls MockERC20.mint(to, amount) on any testnet token.
 * Tracks per-token pending/success/error state keyed by token address.
 */
export function useMintTokens(): UseMintTokensResult {
  const queryClient = useQueryClient();
  const [mintingToken, setMintingToken] = useState<`0x${string}` | null>(null);
  const [successToken, setSuccessToken] = useState<`0x${string}` | null>(null);
  const [errorState, setErrorState] = useState<{ address: `0x${string}`; message: string } | null>(null);

  const {
    writeContract,
    data: txHash,
    isPending: isWritePending,
    reset,
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  if (isSuccess && mintingToken) {
    queryClient.invalidateQueries();
    setSuccessToken(mintingToken);
    setMintingToken(null);
    reset();
    setTimeout(() => setSuccessToken(null), 3000);
  }

  const mint = (tokenAddress: `0x${string}`, to: `0x${string}`, amount: bigint) => {
    setErrorState(null);
    setSuccessToken(null);
    setMintingToken(tokenAddress);
    writeContract(
      {
        address: tokenAddress,
        abi: MockERC20Abi,
        functionName: 'mint',
        args: [to, amount],
      },
      {
        onError: (err) => {
          const message = err.message.includes('User rejected')
            ? 'Transaction rejected in wallet.'
            : 'Mint failed. Please try again.';
          setErrorState({ address: tokenAddress, message });
          setMintingToken(null);
        },
      },
    );
  };

  const buildState = (address: `0x${string}`): MintState => ({
    isPending: (mintingToken === address && (isWritePending || isConfirming)),
    isSuccess: successToken === address,
    error: errorState?.address === address ? errorState.message : null,
  });

  return { mint, states: new Proxy({} as Record<string, MintState>, { get: (_, key) => buildState(key as `0x${string}`) }) };
}
