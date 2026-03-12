import * as React from 'react';
import { useAccount } from 'wagmi';
import { useBorrow } from '@/hooks/useBorrow';
import { usePoolState } from '@/hooks/usePoolState';
import { parseAmountInput } from '@/lib/utils';
import { Button } from '@/components/ui/Button';
import { ErrorMessage } from '@/components/ui/ErrorMessage';
import type { BorrowFormState } from '@/types';

// Hardcoded for demo MVP; in reality fetched from CollateralManager
const SUPPORTED_COLLATERAL = [
  { address: '0x123...abc', symbol: 'WETH', decimals: 18 },
  { address: '0x456...def', symbol: 'WBTC', decimals: 8 },
];

export function BorrowForm({ poolId }: { poolId: `0x${string}` }) {
  const { address } = useAccount();
  const { borrow, isPending, error } = useBorrow();
  const { data: poolState } = usePoolState(poolId);
  
  const [form, setForm] = React.useState<BorrowFormState>({
    collateralToken: '',
    collateralAmount: '',
    borrowAmount: '',
    durationDays: 30, // Default to 30 days
  });

  const availableLiquidity = poolState 
    ? poolState.totalDeposited - poolState.totalBorrowed 
    : 0n;

  // Derive bigints for validation
  const selToken = SUPPORTED_COLLATERAL.find(t => t.address === form.collateralToken);
  const borrowParsed = parseAmountInput(form.borrowAmount, 18); // Assume USDC/ETH 18 dec pool for MVP
  const colParsed = selToken ? parseAmountInput(form.collateralAmount, selToken.decimals) : 0n;

  const isExceedingLiquidity = borrowParsed > availableLiquidity;
  const isValid = form.collateralToken !== '' && colParsed > 0n && borrowParsed > 0n && !isExceedingLiquidity && address;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isValid && address) {
      borrow(form, address);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-slate-300 mb-2">Collateral Asset</label>
          <select 
            className="w-full bg-slate-900 border border-slate-800 rounded-lg p-3 text-slate-100 focus:ring-2 focus:ring-violet-500 outline-none"
            value={form.collateralToken}
            onChange={(e) => setForm({ ...form, collateralToken: e.target.value as `0x${string}` })}
          >
            <option value="" disabled>Select collateral token...</option>
            {SUPPORTED_COLLATERAL.map(t => (
              <option key={t.address} value={t.address}>{t.symbol}</option>
            ))}
          </select>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">Collateral Amount</label>
            <input 
              type="number" 
              step="any"
              min="0"
              className="w-full bg-slate-900 border border-slate-800 rounded-lg p-3 text-slate-100 focus:ring-2 focus:ring-violet-500 outline-none placeholder-slate-600"
              placeholder="0.00"
              value={form.collateralAmount}
              onChange={(e) => setForm({ ...form, collateralAmount: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-slate-300 mb-2">Borrow Amount</label>
            <input 
              type="number" 
              step="any"
              min="0"
              className={`w-full bg-slate-900 border rounded-lg p-3 text-slate-100 focus:ring-2 outline-none placeholder-slate-600 ${
                isExceedingLiquidity ? 'border-red-500/50 focus:ring-red-500' : 'border-slate-800 focus:ring-violet-500'
              }`}
              placeholder="0.00"
              value={form.borrowAmount}
              onChange={(e) => setForm({ ...form, borrowAmount: e.target.value })}
            />
            {isExceedingLiquidity && (
              <p className="text-red-400 text-xs mt-1">Exceeds available pool liquidity</p>
            )}
          </div>
        </div>

        <div>
           <label className="block text-sm font-medium text-slate-300 mb-2 flex justify-between">
             <span>Duration</span>
             <span className="text-violet-400">{form.durationDays} days</span>
           </label>
           <input 
             type="range" 
             min="1" 
             max="365" 
             className="w-full accent-violet-500"
             value={form.durationDays}
             onChange={(e) => setForm({ ...form, durationDays: parseInt(e.target.value) })}
           />
        </div>
      </div>

      {error && <ErrorMessage message={error} />}

      <Button 
        type="submit" 
        className="w-full" 
        size="lg" 
        disabled={!isValid || !address} 
        isLoading={isPending}
      >
        {!address ? 'Connect Wallet' : 'Initiate Borrow'}
      </Button>
    </form>
  );
}
