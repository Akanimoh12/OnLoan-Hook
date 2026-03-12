import { Shell } from '@/components/layout/Shell';
import { LendingPoolCard } from '@/components/lending/LendingPoolCard';
import { POOLS } from '@/lib/constants';

export function Markets() {
  return (
    <Shell>
      <div className="space-y-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight mb-2">Markets</h1>
          <p className="text-slate-400">View real-time utilization, liquidity, and APRs across all isolated pools.</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
          <LendingPoolCard 
            poolId={POOLS.USDC}
            assetSymbol="USDC"
            decimals={6}
          />
          {/* Real deployment handles multiple pools, MVP focuses on USDC */}
        </div>
      </div>
    </Shell>
  );
}
