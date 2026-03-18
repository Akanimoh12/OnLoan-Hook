import { useLoan } from '@/hooks/useLoan';
import { useRepay } from '@/hooks/useRepay';
import { formatTokenAmount } from '@/lib/utils';
import { formatDuration, formatHealthFactor, getHealthStatus } from '@/lib/sdk';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
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
          <div className="h-14 w-14 rounded-full bg-slate-800/50 flex items-center justify-center mb-4">
            <svg className="w-7 h-7 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div className="text-slate-300 font-semibold mb-1">No active loan</div>
          <p className="text-sm text-slate-500 max-w-xs">You don't have any outstanding debt in this pool.</p>
        </CardContent>
      </Card>
    );
  }

  const now = BigInt(Math.floor(Date.now() / 1000));
  const endTime = loan.startTime + loan.duration;
  const remaining = endTime > now ? endTime - now : 0n;
  const isExpired = remaining === 0n;
  const hfStatus = healthFactor !== undefined ? getHealthStatus(healthFactor) : 'safe';
  const totalOwed = loan.borrowedAmount + loan.accruedInterest;

  return (
    <Card className={`overflow-hidden ${hfStatus === 'liquidatable' ? 'border-red-500/30' : ''}`}>
      <CardHeader className="pb-4 border-b border-slate-800/50 flex flex-row items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="h-7 w-7 rounded-full bg-violet-500/10 flex items-center justify-center">
            <svg className="w-3.5 h-3.5 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
          </div>
          <CardTitle>Active Loan</CardTitle>
        </div>
        {healthFactor !== undefined && (
          <Badge variant={
            hfStatus === 'safe' ? 'success' :
            hfStatus === 'liquidatable' ? 'danger' : 'warning'
          }>
            HF: {formatHealthFactor(healthFactor)}
          </Badge>
        )}
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
            value={<span className="text-amber-400">{formatTokenAmount(loan.accruedInterest, assetDecimals, assetSymbol)}</span>}
            className="border-b border-slate-800/30"
          />
          <StatRow 
            label="Total Owed" 
            value={<span className="font-bold">{formatTokenAmount(totalOwed, assetDecimals, assetSymbol)}</span>}
            className="border-b border-slate-800/30"
          />
          <StatRow 
            label="Collateral Locked" 
            value={formatTokenAmount(loan.collateralAmount, 18, 'WETH')}
            className="border-b border-slate-800/30"
          />
          <StatRow 
            label="Time Remaining" 
            value={isExpired ? <span className="text-red-400 font-semibold">Expired</span> : formatDuration(remaining)}
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
