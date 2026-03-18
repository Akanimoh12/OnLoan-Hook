import { Shell } from '@/components/layout/Shell';
import { LendingPoolCard } from '@/components/lending/LendingPoolCard';
import { POOLS } from '@/lib/constants';

export function Markets() {
  return (
    <Shell>
      <div className="space-y-8">
        {/* Page Header */}
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-blue-600/10 via-cyan-600/5 to-transparent border border-blue-500/10 p-8">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-blue-500/5 via-transparent to-transparent" />
          <div className="relative">
            <h1 className="text-3xl font-bold tracking-tight mb-1">Markets</h1>
            <p className="text-slate-400 text-sm">Real-time utilization, liquidity, and APRs across all isolated pools.</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
          <LendingPoolCard 
            poolId={POOLS.USDC}
            assetSymbol="USDC"
            decimals={6}
          />
        </div>
      </div>
    </Shell>
  );
}
