import { Shell } from '@/components/layout/Shell';
import { LiquidationTable } from '@/components/liquidations/LiquidationTable';

export function Liquidations() {
  return (
    <Shell>
      <div className="space-y-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight mb-2">Liquidations</h1>
          <p className="text-slate-400">Monitor active borrowers and execute liquidations on undercollateralized positions to earn a bonus.</p>
        </div>

        <LiquidationTable />
      </div>
    </Shell>
  );
}
