import { useAccount } from 'wagmi';
import { Shell } from '@/components/layout/Shell';
import { BorrowForm } from '@/components/borrow/BorrowForm';
import { LoanCard } from '@/components/borrow/LoanCard';
import { LiquidationWarning } from '@/components/health/LiquidationWarning';
import { useLoan } from '@/hooks/useLoan';
import { useInterestRates } from '@/hooks/useInterestRates';
import { POOLS } from '@/lib/constants';
import { formatApr } from '@/lib/sdk';
import { Card, CardContent } from '@/components/ui/Card';

export function Borrow() {
  const { address } = useAccount();
  const { healthFactor } = useLoan(address as `0x${string}`);
  const { borrowRateBps } = useInterestRates(POOLS.USDC);

  return (
    <Shell>
      <div className="space-y-8">
        {/* Page Header */}
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-violet-600/10 via-fuchsia-600/5 to-transparent border border-violet-500/10 p-8">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-violet-500/5 via-transparent to-transparent" />
          <div className="relative flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold tracking-tight mb-1">Borrow</h1>
              <p className="text-slate-400 text-sm">Lock collateral to borrow assets against your position.</p>
            </div>
            {borrowRateBps > 0n && (
              <div className="text-right">
                <div className="text-xs text-slate-500 mb-1">Current Borrow APR</div>
                <div className="text-2xl font-bold text-violet-400">{formatApr(borrowRateBps)}</div>
              </div>
            )}
          </div>
        </div>

        {address ? (
          <>
            <LiquidationWarning healthFactor={healthFactor} />
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div className="order-2 lg:order-1 space-y-6">
                <h3 className="text-lg font-semibold border-b border-slate-800 pb-2 flex items-center gap-2">
                  <svg className="w-4 h-4 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
                  </svg>
                  New Position
                </h3>
                <BorrowForm poolId={POOLS.USDC} />
              </div>
              <div className="order-1 lg:order-2 space-y-6">
                <h3 className="text-lg font-semibold border-b border-slate-800 pb-2 flex items-center gap-2">
                  <svg className="w-4 h-4 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                  Your Loan
                </h3>
                <LoanCard borrower={address} assetSymbol="USDC" assetDecimals={6} />
              </div>
            </div>
          </>
        ) : (
          <Card className="border-dashed border-slate-700/50 bg-slate-900/20">
            <CardContent className="p-12 flex flex-col items-center justify-center text-center">
              <div className="h-16 w-16 rounded-2xl bg-violet-500/10 flex items-center justify-center mb-4">
                <svg className="w-8 h-8 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-semibold text-slate-200 mb-2">Wallet Disconnected</h3>
              <p className="text-sm text-slate-500 max-w-sm">Please connect your wallet to view or manage your borrow positions.</p>
            </CardContent>
          </Card>
        )}
      </div>
    </Shell>
  );
}
