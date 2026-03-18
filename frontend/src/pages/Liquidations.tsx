import { Shell } from '@/components/layout/Shell';
import { LiquidationTable } from '@/components/liquidations/LiquidationTable';

export function Liquidations() {
  return (
    <Shell>
      <div className="space-y-8">
        {/* Page Header */}
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-red-600/10 via-orange-600/5 to-transparent border border-red-500/10 p-8">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-red-500/5 via-transparent to-transparent" />
          <div className="relative">
            <h1 className="text-3xl font-bold tracking-tight mb-1">Liquidations</h1>
            <p className="text-slate-400 text-sm">Monitor borrower health and execute liquidations on undercollateralized positions to earn a bonus.</p>
          </div>
        </div>

        <LiquidationTable />
      </div>
    </Shell>
  );
}
