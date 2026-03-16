import * as React from 'react';
import { useAccount } from 'wagmi';
import { Shell } from '@/components/layout/Shell';
import { POOLS } from '@/lib/constants';
import { useDeposit } from '@/hooks/useDeposit';
import { useWithdraw } from '@/hooks/useWithdraw';
import { parseAmountInput } from '@/lib/utils';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { ErrorMessage } from '@/components/ui/ErrorMessage';

export function Lend() {
  const { address } = useAccount();
  const [depositAmt, setDepositAmt] = React.useState('');
  const [withdrawAmt, setWithdrawAmt] = React.useState('');

  const { deposit, isPending: isDepositing, error: depError } = useDeposit();
  const { withdraw, canWithdraw, isPending: isWithdrawing, error: wdError } = useWithdraw(POOLS.USDC);

  // MVP is hardcoded to USDC 6 decimals
  const depParsed = parseAmountInput(depositAmt, 6);
  const wdParsed = parseAmountInput(withdrawAmt, 6);

  return (
    <Shell>
      <div className="space-y-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight mb-2">Lend</h1>
          <p className="text-slate-400">Supply assets to the protocol to earn yield.</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Deposit Component */}
          <Card>
            <CardHeader className="border-b border-slate-800/50">
              <CardTitle>Deposit USDC</CardTitle>
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
                    className="w-full bg-slate-900 border border-slate-800 rounded-lg p-3 text-slate-100 focus:ring-2 focus:ring-violet-500 outline-none placeholder-slate-600"
                    value={depositAmt}
                    onChange={(e) => setDepositAmt(e.target.value)}
                  />
                  <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none text-slate-500 text-sm">
                    USDC
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

          {/* Withdraw Component */}
          <Card>
            <CardHeader className="border-b border-slate-800/50">
              <CardTitle>Withdraw USDC</CardTitle>
            </CardHeader>
            <CardContent className="pt-6 space-y-6">
              {!canWithdraw && address && (
                 <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-lg text-sm text-amber-200">
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
                    className="w-full bg-slate-900 border border-slate-800 rounded-lg p-3 text-slate-100 focus:ring-2 focus:ring-violet-500 outline-none disabled:opacity-50 placeholder-slate-600"
                    value={withdrawAmt}
                    onChange={(e) => setWithdrawAmt(e.target.value)}
                  />
                  <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none text-slate-500 text-sm">
                    Shares
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
