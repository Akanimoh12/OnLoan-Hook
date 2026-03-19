import { useAccount, useReadContracts } from 'wagmi';
import { Shell } from '@/components/layout/Shell';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Spinner } from '@/components/ui/Spinner';
import { ErrorMessage } from '@/components/ui/ErrorMessage';
import { TOKENS } from '@/lib/constants';
import { MockERC20Abi } from '@/lib/abis';
import { useMintTokens } from '@/hooks/useMintTokens';
import { formatTokenAmount } from '@/lib/utils';

// Amount sent to the user per claim
const CLAIM_AMOUNTS: Record<string, bigint> = {
  USDC: 10_000n * 10n ** 6n,   // 10,000 USDC
  WETH: 10n * 10n ** 18n,       // 10 WETH
  WBTC: 5n * 10n ** 7n,         // 0.5 WBTC
};

const TOKEN_LIST = [TOKENS.USDC, TOKENS.WETH, TOKENS.WBTC] as const;

export function Faucet() {
  const { address, isConnected } = useAccount();
  const { mint, states } = useMintTokens();

  const balanceContracts = TOKEN_LIST.map((token) => ({
    address: token.address,
    abi: MockERC20Abi,
    functionName: 'balanceOf',
    args: [address ?? '0x0000000000000000000000000000000000000000'],
  }));

  const { data: balances, isLoading: loadingBalances } = useReadContracts({
    contracts: balanceContracts,
    query: { enabled: isConnected && !!address },
  });

  return (
    <Shell>
      <div className="space-y-8 max-w-2xl mx-auto">
        {/* Header */}
        <div className="relative overflow-hidden rounded-2xl bg-linear-to-br from-emerald-600/10 via-teal-600/5 to-transparent border border-emerald-500/10 p-8">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,var(--tw-gradient-stops))] from-emerald-500/5 via-transparent to-transparent" />
          <div className="relative">
            <h1 className="text-3xl font-bold tracking-tight mb-1">Testnet Faucet</h1>
            <p className="text-slate-400 text-sm">
              Claim free testnet tokens to interact with the OnLoan protocol on Unichain Sepolia.
            </p>
          </div>
        </div>

        {/* Warning banner */}
        <div className="flex items-start gap-3 rounded-xl border border-amber-500/20 bg-amber-500/5 px-4 py-3 text-sm text-amber-300">
          <svg className="w-4 h-4 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
          </svg>
          These are mock tokens on Unichain Sepolia — they have no real value. For testing only.
        </div>

        {!isConnected ? (
          <Card className="border-dashed border-slate-700/50 bg-slate-900/20">
            <CardContent className="p-12 flex flex-col items-center justify-center text-center">
              <div className="h-14 w-14 rounded-2xl bg-emerald-500/10 flex items-center justify-center mb-4">
                <svg className="w-7 h-7 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-semibold text-slate-200 mb-2">Connect your wallet</h3>
              <p className="text-sm text-slate-500">Connect to claim testnet tokens.</p>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-4">
            {TOKEN_LIST.map((token, idx) => {
              const state = states[token.address];
              const claimAmount = CLAIM_AMOUNTS[token.symbol];
              const balance = balances?.[idx]?.result as bigint | undefined;

              return (
                <Card key={token.address} className="group hover:border-emerald-500/20 transition-colors">
                  <CardHeader className="border-b border-slate-800/50 pb-4 flex flex-row items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="h-10 w-10 rounded-full bg-slate-800 flex items-center justify-center text-lg font-bold">
                        {token.icon}
                      </div>
                      <div>
                        <CardTitle className="text-base">{token.symbol}</CardTitle>
                        <p className="text-xs text-slate-500 font-mono mt-0.5">
                          {token.address.slice(0, 6)}…{token.address.slice(-4)}
                        </p>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-xs text-slate-500 mb-0.5">Your Balance</div>
                      {loadingBalances ? (
                        <div className="h-4 w-20 bg-slate-800 rounded animate-pulse" />
                      ) : (
                        <div className="text-sm font-semibold text-slate-200">
                          {balance !== undefined
                            ? formatTokenAmount(balance, token.decimals, token.symbol)
                            : '--'}
                        </div>
                      )}
                    </div>
                  </CardHeader>
                  <CardContent className="pt-4 flex items-center justify-between gap-4">
                    <div className="text-sm text-slate-400">
                      Claim{' '}
                      <span className="text-slate-200 font-semibold">
                        {formatTokenAmount(claimAmount, token.decimals, token.symbol)}
                      </span>{' '}
                      per transaction
                    </div>
                    <div className="flex flex-col items-end gap-1.5 min-w-30">
                      <Button
                        size="sm"
                        variant={state.isSuccess ? 'secondary' : 'primary'}
                        disabled={state.isPending}
                        onClick={() => mint(token.address, address!, claimAmount)}
                        className="w-full"
                      >
                        {state.isPending ? (
                          <span className="flex items-center gap-2">
                            <Spinner className="w-3 h-3" />
                            Minting…
                          </span>
                        ) : state.isSuccess ? (
                          <span className="flex items-center gap-2 text-emerald-400">
                            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                              <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                            </svg>
                            Claimed!
                          </span>
                        ) : (
                          'Claim Tokens'
                        )}
                      </Button>
                      {state.error && <ErrorMessage message={state.error} />}
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </Shell>
  );
}
