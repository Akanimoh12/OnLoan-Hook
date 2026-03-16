import { getHealthStatus } from '@/lib/sdk';

export function LiquidationWarning({ healthFactor }: { healthFactor: bigint | undefined }) {
  if (healthFactor === undefined) return null;
  
  const status = getHealthStatus(healthFactor);
  if (status === 'safe') return null;

  const isLiquidatable = status === 'liquidatable';

  return (
    <div className={`p-4 rounded-xl border flex items-start space-x-3 mb-6 animate-in fade-in slide-in-from-top-4 ${
      isLiquidatable 
        ? 'bg-red-500/10 border-red-500/30 text-red-200' 
        : 'bg-orange-500/10 border-orange-500/30 text-orange-200'
    }`}>
      <svg className={`h-6 w-6 shrink-0 mt-0.5 ${isLiquidatable ? 'text-red-500' : 'text-orange-500'}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
      </svg>
      <div>
        <h3 className={`text-sm font-bold ${isLiquidatable ? 'text-red-400' : 'text-orange-400'}`}>
          {isLiquidatable ? 'Liquidation Imminent' : 'High Liquidation Risk'}
        </h3>
        <p className="text-sm mt-1 opacity-90">
          {isLiquidatable 
            ? 'Your health factor has dropped below 1.0. Your position is eligible for liquidation.' 
            : 'Your health factor is in danger. Deposit more collateral or repay some debt to secure your position.'}
        </p>
      </div>
    </div>
  );
}
