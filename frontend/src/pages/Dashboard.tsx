import { useAccount } from 'wagmi';
import { usePoolState } from '@/hooks/usePoolState';
import { useLoan } from '@/hooks/useLoan';
import { useUserShares } from '@/hooks/useUserShares';
import { useInterestRates } from '@/hooks/useInterestRates';
import { POOLS } from '@/lib/constants';
import { Shell } from '@/components/layout/Shell';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { formatTokenAmount } from '@/lib/utils';
import { formatApr, formatUtilization, formatHealthFactor, getHealthStatus, formatDuration } from '@/lib/sdk';
import { Button } from '@/components/ui/Button';
import { Badge } from '@/components/ui/Badge';
import { Skeleton } from '@/components/ui/Skeleton';
import { Link } from 'react-router-dom';

export function Dashboard() {
  const { address } = useAccount();
  const { data: usdcPool, isLoading: loadingPool } = usePoolState(POOLS.USDC);
  const { loan, healthFactor, isLoading: loadingLoan } = useLoan(address as `0x${string}`);
  const { shares, isLoading: loadingShares } = useUserShares(POOLS.USDC);
  const { borrowRateBps, supplyRateBps, utilizationBps } = useInterestRates(POOLS.USDC);

  const globalTVL = usdcPool ? usdcPool.totalDeposited : 0n;
  const globalBorrows = usdcPool ? usdcPool.totalBorrowed : 0n;
  const availableLiquidity = usdcPool ? usdcPool.totalDeposited - usdcPool.totalBorrowed : 0n;

  const hasLoan = loan?.active === true;
  const hasDeposit = shares > 0n;

  // Estimate lender's deposit value from shares
  const estimatedDeposit = usdcPool && usdcPool.totalShares > 0n
    ? (shares * usdcPool.totalDeposited) / usdcPool.totalShares
    : 0n;

  return (
    <Shell>
      <div className="space-y-8">
        {/* Hero Header */}
        <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-violet-600/10 via-fuchsia-600/5 to-transparent border border-violet-500/10 p-8">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-violet-500/5 via-transparent to-transparent" />
          <div className="relative">
            <h1 className="text-3xl font-bold tracking-tight mb-1">Protocol Overview</h1>
            <p className="text-slate-400 text-sm">Real-time analytics for OnLoan on Unichain Sepolia</p>
          </div>
        </div>

        {/* Global Stats Grid */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <Card className="group hover:border-violet-500/20 transition-colors">
            <CardContent className="p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="h-9 w-9 rounded-lg bg-violet-500/10 flex items-center justify-center">
                  <svg className="w-4 h-4 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                  </svg>
                </div>
                <span className="text-xs font-medium text-slate-500 uppercase tracking-wider">Total Value Locked</span>
              </div>
              {loadingPool ? (
                <Skeleton className="h-8 w-32" />
              ) : (
                <div className="text-2xl font-bold text-slate-100">{formatTokenAmount(globalTVL, 6, 'USDC')}</div>
              )}
            </CardContent>
          </Card>

          <Card className="group hover:border-violet-500/20 transition-colors">
            <CardContent className="p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="h-9 w-9 rounded-lg bg-fuchsia-500/10 flex items-center justify-center">
                  <svg className="w-4 h-4 text-fuchsia-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
                <span className="text-xs font-medium text-slate-500 uppercase tracking-wider">Total Borrowed</span>
              </div>
              {loadingPool ? (
                <Skeleton className="h-8 w-32" />
              ) : (
                <div className="text-2xl font-bold text-slate-100">{formatTokenAmount(globalBorrows, 6, 'USDC')}</div>
              )}
            </CardContent>
          </Card>

          <Card className="group hover:border-green-500/20 transition-colors">
            <CardContent className="p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="h-9 w-9 rounded-lg bg-green-500/10 flex items-center justify-center">
                  <svg className="w-4 h-4 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                  </svg>
                </div>
                <span className="text-xs font-medium text-slate-500 uppercase tracking-wider">Supply APR</span>
              </div>
              <div className="text-2xl font-bold text-green-400">
                {supplyRateBps > 0n ? formatApr(supplyRateBps) : <span className="text-slate-500">--</span>}
              </div>
            </CardContent>
          </Card>

          <Card className="group hover:border-amber-500/20 transition-colors">
            <CardContent className="p-5">
              <div className="flex items-center gap-3 mb-3">
                <div className="h-9 w-9 rounded-lg bg-amber-500/10 flex items-center justify-center">
                  <svg className="w-4 h-4 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                </div>
                <span className="text-xs font-medium text-slate-500 uppercase tracking-wider">Utilization</span>
              </div>
              <div className="text-2xl font-bold text-amber-400">
                {formatUtilization(utilizationBps)}
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Protocol Info Row */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card className="border-slate-800/50">
            <CardContent className="p-5 flex items-center justify-between">
              <div>
                <div className="text-xs text-slate-500 mb-1">Available Liquidity</div>
                <div className="text-lg font-semibold">{formatTokenAmount(availableLiquidity > 0n ? availableLiquidity : 0n, 6, 'USDC')}</div>
              </div>
              <div className="h-10 w-10 rounded-full bg-blue-500/10 flex items-center justify-center">
                <svg className="w-5 h-5 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125" />
                </svg>
              </div>
            </CardContent>
          </Card>

          <Card className="border-slate-800/50">
            <CardContent className="p-5 flex items-center justify-between">
              <div>
                <div className="text-xs text-slate-500 mb-1">Borrow APR</div>
                <div className="text-lg font-semibold text-violet-400">{borrowRateBps > 0n ? formatApr(borrowRateBps) : <span className="text-slate-500">--</span>}</div>
              </div>
              <div className="h-10 w-10 rounded-full bg-violet-500/10 flex items-center justify-center">
                <svg className="w-5 h-5 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941" />
                </svg>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-gradient-to-br from-violet-600/10 to-fuchsia-600/5 border-violet-500/20">
            <CardContent className="p-5 flex items-center justify-between">
              <div>
                <div className="text-xs text-violet-300/70 mb-1">Network</div>
                <div className="text-lg font-semibold text-violet-100">Unichain Sepolia</div>
              </div>
              <Badge variant="outline" className="border-violet-500/30 text-violet-300">ID: 1301</Badge>
            </CardContent>
          </Card>
        </div>

        {/* User Positions */}
        {address ? (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Supply Position */}
            <Card className="overflow-hidden">
              <CardHeader className="border-b border-slate-800/50 pb-4 flex flex-row items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="h-7 w-7 rounded-full bg-green-500/10 flex items-center justify-center">
                    <svg className="w-3.5 h-3.5 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <CardTitle className="text-base">Your Supply</CardTitle>
                </div>
                {hasDeposit && <Badge variant="success">Active</Badge>}
              </CardHeader>
              <CardContent className="pt-5">
                {loadingShares ? (
                  <div className="space-y-3">
                    <Skeleton className="h-4 w-full" />
                    <Skeleton className="h-4 w-2/3" />
                  </div>
                ) : hasDeposit ? (
                  <div className="space-y-4">
                    <div className="flex items-center justify-between py-2 border-b border-slate-800/30">
                      <span className="text-sm text-slate-400">Deposited Value</span>
                      <span className="text-sm font-semibold text-slate-100">{formatTokenAmount(estimatedDeposit, 6, 'USDC')}</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-slate-800/30">
                      <span className="text-sm text-slate-400">Pool Shares</span>
                      <span className="text-sm font-mono text-slate-300">{shares.toString()}</span>
                    </div>
                    <div className="flex items-center justify-between py-2">
                      <span className="text-sm text-slate-400">Earning APR</span>
                      <span className="text-sm font-semibold text-green-400">{supplyRateBps > 0n ? formatApr(supplyRateBps) : '--'}</span>
                    </div>
                    <Link to="/lend" className="block mt-2">
                      <Button variant="secondary" className="w-full" size="sm">Manage Position</Button>
                    </Link>
                  </div>
                ) : (
                  <div className="flex flex-col items-center justify-center py-8 text-center">
                    <div className="h-12 w-12 rounded-full bg-slate-800/50 mb-4 flex items-center justify-center">
                      <svg className="w-6 h-6 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 6v12m-3-2.818l.879.659c1.171.879 3.07.879 4.242 0 1.172-.879 1.172-2.303 0-3.182C13.536 12.219 12.768 12 12 12c-.725 0-1.45-.22-2.003-.659-1.106-.879-1.106-2.303 0-3.182s2.9-.879 4.006 0l.415.33M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </div>
                    <p className="text-sm text-slate-400 mb-4">No active deposits</p>
                    <Link to="/lend">
                      <Button size="sm">Supply Assets</Button>
                    </Link>
                  </div>
                )}
              </CardContent>
            </Card>

            {/* Borrow Position */}
            <Card className="overflow-hidden">
              <CardHeader className="border-b border-slate-800/50 pb-4 flex flex-row items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="h-7 w-7 rounded-full bg-violet-500/10 flex items-center justify-center">
                    <svg className="w-3.5 h-3.5 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                  </div>
                  <CardTitle className="text-base">Your Borrow</CardTitle>
                </div>
                {hasLoan && healthFactor !== undefined && (
                  <Badge variant={
                    getHealthStatus(healthFactor) === 'safe' ? 'success' :
                    getHealthStatus(healthFactor) === 'liquidatable' ? 'danger' : 'warning'
                  }>
                    HF: {formatHealthFactor(healthFactor)}
                  </Badge>
                )}
              </CardHeader>
              <CardContent className="pt-5">
                {loadingLoan ? (
                  <div className="space-y-3">
                    <Skeleton className="h-4 w-full" />
                    <Skeleton className="h-4 w-2/3" />
                  </div>
                ) : hasLoan && loan ? (
                  <div className="space-y-4">
                    <div className="flex items-center justify-between py-2 border-b border-slate-800/30">
                      <span className="text-sm text-slate-400">Borrowed</span>
                      <span className="text-sm font-semibold text-slate-100">{formatTokenAmount(loan.borrowedAmount, 6, 'USDC')}</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-slate-800/30">
                      <span className="text-sm text-slate-400">Interest Accrued</span>
                      <span className="text-sm font-semibold text-amber-400">{formatTokenAmount(loan.accruedInterest, 6, 'USDC')}</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-slate-800/30">
                      <span className="text-sm text-slate-400">Collateral</span>
                      <span className="text-sm font-semibold text-slate-100">{formatTokenAmount(loan.collateralAmount, 18, 'WETH')}</span>
                    </div>
                    <div className="flex items-center justify-between py-2">
                      <span className="text-sm text-slate-400">Time Remaining</span>
                      <span className="text-sm font-semibold">
                        {(() => {
                          const now = BigInt(Math.floor(Date.now() / 1000));
                          const end = loan.startTime + loan.duration;
                          return end > now ? formatDuration(end - now) : <span className="text-red-400">Expired</span>;
                        })()}
                      </span>
                    </div>
                    <Link to="/borrow" className="block mt-2">
                      <Button variant="secondary" className="w-full" size="sm">Manage Loan</Button>
                    </Link>
                  </div>
                ) : (
                  <div className="flex flex-col items-center justify-center py-8 text-center">
                    <div className="h-12 w-12 rounded-full bg-slate-800/50 mb-4 flex items-center justify-center">
                      <svg className="w-6 h-6 text-slate-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                        <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                    </div>
                    <p className="text-sm text-slate-400 mb-4">No active loans</p>
                    <Link to="/borrow">
                      <Button variant="secondary" size="sm">Borrow Assets</Button>
                    </Link>
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        ) : (
          <Card className="border-dashed border-slate-700/50 bg-slate-900/20">
            <CardContent className="p-12 flex flex-col items-center justify-center text-center">
              <div className="h-16 w-16 rounded-2xl bg-violet-500/10 flex items-center justify-center mb-4">
                <svg className="w-8 h-8 text-violet-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
              </div>
              <h3 className="text-lg font-semibold text-slate-200 mb-2">Connect your wallet</h3>
              <p className="text-sm text-slate-500 max-w-sm">View your supplied assets, active loans, and health factors.</p>
            </CardContent>
          </Card>
        )}
      </div>
    </Shell>
  );
}
