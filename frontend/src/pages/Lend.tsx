import * as React from 'react';
import { useAccount } from 'wagmi';
import { Shell } from '@/components/layout/Shell';
import { POOLS } from '@/lib/constants';
import { useDeposit } from '@/hooks/useDeposit';
import { useWithdraw } from '@/hooks/useWithdraw';
import { useUserShares } from '@/hooks/useUserShares';
import { useInterestRates } from '@/hooks/useInterestRates';
import { usePoolState } from '@/hooks/usePoolState';
import { parseAmountInput, formatTokenAmount } from '@/lib/utils';
import { formatApr, formatUtilization } from '@/lib/sdk';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { ErrorMessage } from '@/components/ui/ErrorMessage';
import { Skeleton } from '@/components/ui/Skeleton';

export function Lend() {
  const { address } = useAccount();
  const [depositAmt, setDepositAmt] = React.useState('');
  const [withdrawAmt, setWithdrawAmt] = React.useState('');

  const { deposit, isPending: isDepositing, error: depError } = useDeposit();
  const { withdraw, canWithdraw, isPending: isWithdrawing, error: wdError } = useWithdraw(POOLS.USDC);
  const { shares, isLoading: loadingShares } = useUserShares(POOLS.USDC);
  const { supplyRateBps, utilizationBps } = useInterestRates(POOLS.USDC);
  const { data: poolState, isLoading: loadingPool } = usePoolState(POOLS.USDC);

  const depParsed = parseAmountInput(depositAmt, 6);
  const wdParsed = parseAmountInput(withdrawAmt, 6);

  const estimatedDeposit = poolState && poolState.totalShares > 0n
    ? (shares * poolState.totalDeposited) / poolState.totalShares
    : 0n;

  return (
    <Shell>
      <div className="space-y-8">
        {/* Page Header */}
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-green-600/10 via-emerald-600/5 to-transparent border border-green-500/10 p-8">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-green-500/5 via-transparent to-transparent" />
          <div className="relative flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold tracking-tight mb-1">Lend</h1>
              <p className="text-slate-400 text-sm">Supply USDC to earn yield from borrowers.</p>
            </div>
            {supplyRateBps > 0n && (
              <div className="text-right">
                <div className="text-xs text-slate-500 mb-1">Current Supply APR</div>
                <div className="text-2xl font-bold text-green-400">{formatApr(supplyRateBps)}</div>
              </div>
            )}
          </div>
        </div>

        {/* Position Summary */}
        {address && (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Card className="border-slate-800/50">
              <CardContent className="p-4">
                <div className="text-xs text-slate-500 mb-1">Your Deposit Value</div>
                {loadingShares || loadingPool ? (
                  <Skeleton className="h-6 w-24" />
                ) : (
                  <div className="text-lg font-bold text-slate-100">{formatTokenAmount(estimatedDeposit, 6, 'USDC')}</div>
                )}
              </CardContent>
            </Card>
            <Card className="border-slate-800/50">
              <CardContent className="p-4">
                <div className="text-xs text-slate-500 mb-1">Your Shares</div>
                {loadingShares ? (
                  <Skeleton className="h-6 w-20" />
                ) : (
                  <div className="text-lg font-bold text-slate-100 font-mono">{shares.toString()}</div>
                )}
              </CardContent>
            </Card>
            <Card className="border-slate-800/50">
              <CardContent className="p-4">
                <div className="text-xs text-slate-500 mb-1">Pool Utilization</div>
                <div className="text-lg font-bold text-amber-400">{formatUtilization(utilizationBps)}</div>
              </CardContent>
            </Card>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Deposit */}
          <Card>
            <CardHeader className="border-b border-slate-800/50 flex flex-row items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="h-7 w-7 rounded-full bg-green-500/10 flex items-center justify-center">
                  <svg className="w-3.5 h-3.5 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
                  </svg>
                </div>
                <CardTitle>Deposit USDC</CardTitle>
              </div>
              <Badge variant="success">Earn Yield</Badge>
            </CardHeader>
            <CardContent className="pt-6 space-y-6">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Amount to Supply</label>
                <div className="relative">
                  <input 
                    type="number" 
                    step="any"
                    min="0"
                    placeholder="0.00"
                    className="w-full bg-slate-900 border border-slate-800 rounded-lg p-3 pr-16 text-slate-100 focus:ring-2 focus:ring-green-500 outline-none placeholder-slate-600"
                    value={depositAmt}
                    onChange={(e) => setDepositAmt(e.target.value)}
                  />
                  <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                    <Badge variant="outline" className="text-slate-400">USDC</Badge>
                  </div>
                </div>
              </div>

              {depError && <ErrorMessage message={depError} />}

              <Button 
                className="w-full" 
                size="lg"
                disabled={!address || depParsed === 0n}
                isLoading={isDepositing}
                onClick={() => address && deposit(POOLS.USDC, address, depParsed)}
              >
                {!address ? 'Connect Wallet' : 'Supply Assets'}
              </Button>
            </CardContent>
          </Card>

          {/* Withdraw */}
          <Card>
            <CardHeader className="border-b border-slate-800/50 flex flex-row items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="h-7 w-7 rounded-full bg-amber-500/10 flex items-center justify-center">
                  <svg className="w-3.5 h-3.5 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M20 12H4" />
                  </svg>
                </div>
                <CardTitle>Withdraw USDC</CardTitle>
              </div>
            </CardHeader>
            <CardContent className="pt-6 space-y-6">
              {!canWithdraw && address && (
                 <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-lg text-sm text-amber-200 flex items-center gap-2">
                   <svg className="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                     <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                   </svg>
                   Withdrawals for your account are currently in cooldown.
                 </div>
              )}

              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">Shares to Withdraw</label>
                <div className="relative">
                   <input 
                    type="number" 
                    step="any"
                    min="0"
                    placeholder="0.00"
                    disabled={!canWithdraw && !!address}
                    className="w-full bg-slate-900 border border-slate-800 rounded-lg p-3 pr-20 text-slate-100 focus:ring-2 focus:ring-violet-500 outline-none disabled:opacity-50 placeholder-slate-600"
                    value={withdrawAmt}
                    onChange={(e) => setWithdrawAmt(e.target.value)}
                  />
                  <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                    <Badge variant="outline" className="text-slate-400">Shares</Badge>
                  </div>
                </div>
              </div>

               {wdError && <ErrorMessage message={wdError} />}

              <Button 
                variant="secondary"
                className="w-full" 
                size="lg"
                disabled={!address || wdParsed === 0n || !canWithdraw}
                isLoading={isWithdrawing}
                onClick={() => withdraw(POOLS.USDC, wdParsed)}
              >
                {!address ? 'Connect Wallet' : 'Withdraw Shares'}
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </Shell>
  );
}
