import * as React from 'react';

export interface StatRowProps {
  label: string;
  value: React.ReactNode;
  subValue?: string;
  className?: string;
}

export function StatRow({ label, value, subValue, className = '' }: StatRowProps) {
  return (
    <div className={`flex items-center justify-between py-2 ${className}`}>
      <span className="text-sm font-medium text-slate-400">{label}</span>
      <div className="flex flex-col items-end">
        <span className="text-sm font-semibold text-slate-100">{value}</span>
        {subValue && <span className="text-xs text-slate-500 mt-0.5">{subValue}</span>}
      </div>
    </div>
  );
}
