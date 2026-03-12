import * as React from 'react';

export function UtilizationBar({ utilizationBps }: { utilizationBps: bigint }) {
  // Cap at 100% for the bar visual
  const percentage = Math.min(Number(utilizationBps) / 100, 100);

  // Gradient transitions based on utilization severity
  let barColor = 'bg-violet-500';
  if (percentage > 80) barColor = 'bg-orange-500';
  if (percentage > 95) barColor = 'bg-red-500';

  return (
    <div className="w-full h-2 bg-slate-800 rounded-full overflow-hidden flex">
      <div 
        className={`h-full ${barColor} transition-all duration-500 ease-out`} 
        style={{ width: `${percentage}%` }}
      />
    </div>
  );
}
