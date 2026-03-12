import { useAccount } from 'wagmi';
import { usePoolState } from '@/hooks/usePoolState';
import { POOLS } from '@/lib/constants';
import { Shell } from '@/components/layout/Shell';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { StatRow } from '@/components/ui/StatRow';
import { formatTokenAmount } from '@/lib/utils';
import { formatApr } from '@/lib/sdk';
import { Button } from '@/components/ui/Button';
import { Link } from 'react-router-dom';

export function Dashboard() {
  const { address } = useAccount();

  // For the MVP dashboard, aggregate the core USDC pool stats
  const { data: usdcPool } = usePoolState(POOLS.USDC);

  // Mock global tvl/borrows based on the single pool for now
  const globalTVL = usdcPool ? usdcPool.totalDeposited : 0n;
  const globalBorrows = usdcPool ? usdcPool.totalBorrowed : 0n;

  return (
    <Shell>
      <div className="space-y-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight mb-2">Protocol Overview</h1>
          <p className="text-slate-400">Welcome to OnLoan on Unichain Sepolia.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-slate-400 text-sm font-medium">Global TVL</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{formatTokenAmount(globalTVL, 6, 'USDC')}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-slate-400 text-sm font-medium">Total Borrowed</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{formatTokenAmount(globalBorrows, 6, 'USDC')}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-slate-400 text-sm font-medium">Active Markets</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">1</div>
            </CardContent>
          </Card>
          <Card className="bg-gradient-to-br from-violet-600/20 to-fuchsia-600/20 border-violet-500/30">
            <CardHeader className="pb-2">
              <CardTitle className="text-violet-300 text-sm font-medium">Network</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-xl font-bold text-violet-100 mb-1">Unichain Testnet</div>
              <div className="text-xs text-violet-300/70 border border-violet-500/30 rounded inline-block px-1.5 py-0.5">Chain ID: 1301</div>
            </CardContent>
          </Card>
        </div>

        {address ? (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader className="border-b border-slate-800/50 pb-4">
                <CardTitle>Your Supply</CardTitle>
              </CardHeader>
              <CardContent className="pt-6">
                <div className="flex flex-col items-center justify-center py-8 text-center">
                  <div className="h-12 w-12 rounded-full bg-slate-800 mb-4 flex items-center justify-center pb-1 text-2xl">🌱</div>
                  <p className="text-slate-400 mb-6">No active deposits found for this wallet.</p>
                  <Link to="/lend">
                    <Button>Supply Assets</Button>
                  </Link>
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="border-b border-slate-800/50 pb-4">
                <CardTitle>Your Borrows</CardTitle>
              </CardHeader>
              <CardContent className="pt-6">
                 <div className="flex flex-col items-center justify-center py-8 text-center">
                  <div className="h-12 w-12 rounded-full bg-slate-800 mb-4 flex items-center justify-center pb-1 text-2xl">⚡</div>
                  <p className="text-slate-400 mb-6">No active loans found for this wallet.</p>
                  <Link to="/borrow">
                    <Button variant="secondary">Borrow Assets</Button>
                  </Link>
                </div>
              </CardContent>
            </Card>
          </div>
        ) : (
          <Card className="border-dashed border-slate-700 bg-slate-900/30">
            <CardContent className="p-12 text-center">
              <h3 className="text-lg font-medium text-slate-300 mb-2">Connect your wallet to view your positions</h3>
              <p className="text-sm text-slate-500 max-w-sm mx-auto">Track your supplied assets, active loans, and health factors directly from the dashboard.</p>
            </CardContent>
          </Card>
        )}

      </div>
    </Shell>
  );
}
