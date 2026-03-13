import { useLoan } from '@/hooks/useLoan';
import { useRepay } from '@/hooks/useRepay';
import { formatTokenAmount } from '@/lib/utils';
import { formatDuration } from '@/lib/sdk';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { ErrorMessage } from '@/components/ui/ErrorMessage';
import { HealthFactorGauge } from '@/components/health/HealthFactorGauge';
import { StatRow } from '@/components/ui/StatRow';

interface LoanCardProps {
  borrower: `0x${string}`;
  assetSymbol: string;
  assetDecimals: number;
}

export function LoanCard({ borrower, assetSymbol, assetDecimals }: LoanCardProps) {
  const { loan, healthFactor, isLoading } = useLoan(borrower);
  const { repay, isPending: isRepaying, error: repayError } = useRepay();

  if (isLoading) {
    return <Card className="p-6 h-64 animate-pulse bg-slate-900/50" />;
  }

  if (!loan || !loan.active) {
    return (
      <Card className="border-slate-800 bg-slate-900/30 border-dashed">
        <CardContent className="p-12 flex flex-col items-center justify-center text-center">
          <svg className="w-12 h-12 text-slate-700 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div className="text-slate-400 font-medium">No active loan</div>
          <p className="text-sm text-slate-500 mt-1 max-w-xs">You're all clear. You don't have any outstanding debt in this pool.</p>
        </CardContent>
      </Card>
    );
  }

  // Contract stores block.timestamp as seconds since epoch
  const now = BigInt(Math.floor(Date.now() / 1000));
  const endTime = loan.startTime + loan.duration;
  const remaining = endTime > now ? endTime - now : 0n;

  return (
    <Card>
      <CardHeader className="pb-4 border-b border-slate-800/50">
        <CardTitle>Active Loan Position</CardTitle>
      </CardHeader>
      
      <CardContent className="pt-6 grid grid-cols-1 lg:grid-cols-2 gap-8">
        
        <div className="space-y-2">
          <StatRow 
            label="Borrowed Amount" 
            value={formatTokenAmount(loan.borrowedAmount, assetDecimals, assetSymbol)}
            className="border-b border-slate-800/30"
          />
          <StatRow 
            label="Accrued Interest" 
            value={formatTokenAmount(loan.accruedInterest, assetDecimals, assetSymbol)}
            className="border-b border-slate-800/30"
          />
          <StatRow 
            label="Collateral Locked" 
            value={formatTokenAmount(loan.collateralAmount, 18, 'WETH')} // Hardcoded collateral decs for MVP
             className="border-b border-slate-800/30"
          />
          <StatRow 
            label="Time Remaining" 
            value={remaining > 0n ? formatDuration(remaining) : <span className="text-red-400">Expired</span>}
          />

          <div className="pt-6 mt-4 border-t border-slate-800/50">
            {repayError && <ErrorMessage message={repayError} className="mb-4" />}
            <Button 
              className="w-full" 
              onClick={() => repay(borrower)}
              isLoading={isRepaying}
              variant="secondary"
            >
              Repay Full Balance
            </Button>
          </div>
        </div>

        <div className="flex flex-col justify-center border border-slate-800/50 rounded-xl bg-slate-950/30 p-2">
           <HealthFactorGauge healthFactor={healthFactor ?? 0n} />
        </div>

      </CardContent>
    </Card>
  );
}
