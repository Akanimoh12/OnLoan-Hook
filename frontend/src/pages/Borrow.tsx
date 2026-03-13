import { useAccount } from 'wagmi';
import { Shell } from '@/components/layout/Shell';
import { BorrowForm } from '@/components/borrow/BorrowForm';
import { LoanCard } from '@/components/borrow/LoanCard';
import { LiquidationWarning } from '@/components/health/LiquidationWarning';
import { useLoan } from '@/hooks/useLoan';
import { POOLS } from '@/lib/constants';

export function Borrow() {
  const { address } = useAccount();
  const { healthFactor } = useLoan(address as `0x${string}`);

  return (
    <Shell>
      <div className="space-y-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight mb-2">Borrow</h1>
          <p className="text-slate-400">Lock collateral to borrow assets against your position.</p>
        </div>

        {address ? (
          <>
            <LiquidationWarning healthFactor={healthFactor} />
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              <div className="order-2 lg:order-1 space-y-6">
                <h3 className="text-lg font-semibold border-b border-slate-800 pb-2">New Position</h3>
                <BorrowForm poolId={POOLS.USDC} />
              </div>
              <div className="order-1 lg:order-2 space-y-6">
                <h3 className="text-lg font-semibold border-b border-slate-800 pb-2">Your Loan</h3>
                <LoanCard borrower={address} assetSymbol="USDC" assetDecimals={6} />
              </div>
            </div>
          </>
        ) : (
          <div className="flex flex-col items-center justify-center p-12 border border-slate-800 border-dashed rounded-xl bg-slate-900/30">
            <h3 className="text-lg font-medium text-slate-300 mb-2">Wallet Disconnected</h3>
            <p className="text-sm text-slate-500 text-center max-w-sm">Please connect your wallet to view or manage your borrow positions.</p>
          </div>
        )}
      </div>
    </Shell>
  );
}
