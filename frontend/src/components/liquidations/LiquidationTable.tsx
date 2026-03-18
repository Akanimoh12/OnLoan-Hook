import { useLiquidations } from '@/hooks/useLiquidations';
import { useLiquidate } from '@/hooks/useLiquidate';
import { shortenAddress, formatTokenAmount } from '@/lib/utils';
import { formatHealthFactor } from '@/lib/sdk';
import { Card, CardContent } from '@/components/ui/Card';
import { Badge } from '@/components/ui/Badge';
import { Button } from '@/components/ui/Button';
import { Spinner } from '@/components/ui/Spinner';

export function LiquidationTable() {
  const { all, isLoading, isError, refetch } = useLiquidations();
  const { liquidate, isPending: isLiquidating, targetBorrower } = useLiquidate();

  if (isError) {
    return (
      <Card className="border-red-500/20 bg-red-500/5">
        <CardContent className="p-6">
          <p className="text-sm text-red-400">Failed to load risk dashboard.</p>
          <Button onClick={() => refetch()} variant="ghost" className="mt-4">Retry</Button>
        </CardContent>
      </Card>
    );
  }

  if (isLoading) {
    return (
      <Card>
        <CardContent className="p-12 flex flex-col items-center justify-center">
          <Spinner className="h-8 w-8 mb-4" />
          <p className="text-sm text-slate-400">Scanning global risk positions...</p>
        </CardContent>
      </Card>
    );
  }

  if (all.length === 0) {
    return (
      <Card>
        <CardContent className="p-12 flex flex-col items-center justify-center">
          <svg className="w-12 h-12 text-slate-700 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p className="text-slate-400 font-medium">No active borrowers in the system.</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="overflow-hidden">
      <div className="overflow-x-auto">
        <table className="w-full text-sm text-left">
          <thead className="bg-slate-950/50 text-slate-400 border-b border-slate-800">
            <tr>
              <th className="px-6 py-4 font-medium">Borrower</th>
              <th className="px-6 py-4 font-medium text-right">Collateral Value</th>
              <th className="px-6 py-4 font-medium text-right">Debt Value</th>
              <th className="px-6 py-4 font-medium text-center">Health Factor</th>
              <th className="px-6 py-4 font-medium text-right">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/50">
            {all.map((row) => (
              <tr key={row.address} className="hover:bg-slate-800/20 transition-colors">
                <td className="px-6 py-4 font-mono text-slate-300">
                  <a 
                    href={`https://unichain-sepolia.blockscout.com/address/${row.address}`}
                    target="_blank"
                    rel="noreferrer"
                    className="hover:text-violet-400 hover:underline"
                  >
                    {shortenAddress(row.address)}
                  </a>
                </td>
                <td className="px-6 py-4 text-right font-mono">
                  {row.collateralValueUSD > 0n
                    ? `$${formatTokenAmount(row.collateralValueUSD, 8, '')}`
                    : <span className="text-slate-500">--</span>}
                </td>
                <td className="px-6 py-4 text-right font-mono">
                  {row.debtValueUSD > 0n
                    ? `$${formatTokenAmount(row.debtValueUSD, 8, '')}`
                    : <span className="text-slate-500">--</span>}
                </td>
                <td className="px-6 py-4 text-center">
                  <div className="flex flex-col items-center">
                    <span className={`font-bold text-lg mb-1 leading-none ${
                        row.status === 'safe' ? 'text-green-500' :
                        row.status === 'warning' ? 'text-amber-500' :
                        row.status === 'danger' ? 'text-orange-500' : 'text-red-500'
                    }`}>
                      {formatHealthFactor(row.healthFactor)}
                    </span>
                    <Badge variant={
                      row.status === 'safe' ? 'success' :
                      row.status === 'liquidatable' ? 'danger' : 'warning'
                    }>
                      {row.status}
                    </Badge>
                  </div>
                </td>
                <td className="px-6 py-4 text-right">
                  <Button 
                    variant={row.status === 'liquidatable' ? 'primary' : 'secondary'}
                    disabled={row.status !== 'liquidatable' || isLiquidating}
                    isLoading={isLiquidating && targetBorrower === row.address}
                    onClick={() => liquidate(row.address)}
                  >
                    Liquidate
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
