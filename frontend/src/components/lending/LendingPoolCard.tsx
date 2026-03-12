import { usePoolState } from '@/hooks/usePoolState';
import { formatTokenAmount, formatUSD } from '@/lib/utils';
import { formatUtilization, formatApr } from '@/lib/sdk';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { StatRow } from '@/components/ui/StatRow';
import { Skeleton } from '@/components/ui/Skeleton';
import { UtilizationBar } from './UtilizationBar';

interface LendingPoolCardProps {
  poolId: `0x${string}`;
  assetSymbol: string;
  decimals: number;
}

export function LendingPoolCard({ poolId, assetSymbol, decimals }: LendingPoolCardProps) {
  const { data: state, isLoading, isError } = usePoolState(poolId);

  if (isError) {
    return (
      <Card className="border-red-500/20 bg-red-500/5">
        <CardContent className="p-6">
          <p className="text-sm text-red-400">Failed to load pool state. Retrying...</p>
        </CardContent>
      </Card>
    );
  }

  if (isLoading || !state) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-32" />
        </CardHeader>
        <CardContent className="space-y-4">
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-full" />
        </CardContent>
      </Card>
    );
  }

  // Derive utilization: totalBorrowed / totalDeposited
  // In a real integration, the hook reads `getUtilizationRate()` directly from the contract.
  // For the MVP, we compute it purely for display if not fetching the raw rate.
  const utilizationBps = state.totalDeposited > 0n 
    ? (state.totalBorrowed * 10_000n) / state.totalDeposited 
    : 0n;

  // Placeholder static APR until InterestRateModel integration is complete
  const borrowAprBps = 1200n; // 12%
  const supplyAprBps = 950n;  // 9.5%

  const availableLiquidity = state.totalDeposited - state.totalBorrowed;

  return (
    <Card>
      <CardHeader className="pb-4 border-b border-slate-800/50 flex flex-row items-center justify-between">
        <div className="flex items-center space-x-3">
          <div className="h-8 w-8 rounded-full bg-violet-500/20 flex items-center justify-center text-violet-400 font-bold border border-violet-500/30">
            {assetSymbol[0]}
          </div>
          <CardTitle>{assetSymbol} Pool</CardTitle>
        </div>
        <div className="text-right">
          <div className="text-xs text-slate-400 mb-1">Utilization</div>
          <div className="font-mono text-sm">{formatUtilization(utilizationBps)}</div>
        </div>
      </CardHeader>
      
      <CardContent className="pt-6 space-y-5">
        <UtilizationBar utilizationBps={utilizationBps} />

        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1 p-3 rounded-lg bg-slate-950/50 border border-slate-800/50">
            <div className="text-xs text-slate-400">Total Supplied</div>
            <div className="font-semibold">{formatTokenAmount(state.totalDeposited, decimals, assetSymbol)}</div>
            <div className="text-xs text-green-400 mt-1">{formatApr(supplyAprBps)} Supply APR</div>
          </div>
          <div className="space-y-1 p-3 rounded-lg bg-slate-950/50 border border-slate-800/50">
            <div className="text-xs text-slate-400">Total Borrowed</div>
            <div className="font-semibold">{formatTokenAmount(state.totalBorrowed, decimals, assetSymbol)}</div>
            <div className="text-xs text-violet-400 mt-1">{formatApr(borrowAprBps)} Borrow APR</div>
          </div>
        </div>

        <div className="pt-4 border-t border-slate-800/50 space-y-1">
          <StatRow 
            label="Available Liquidity" 
            value={formatTokenAmount(availableLiquidity < 0n ? 0n : availableLiquidity, decimals, assetSymbol)} 
          />
        </div>
      </CardContent>
    </Card>
  );
}
