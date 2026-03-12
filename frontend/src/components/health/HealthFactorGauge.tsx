import * as React from 'react';
import { getHealthStatus, formatHealthFactor, healthFactorToFloat } from '@/lib/sdk';
import { Card, CardContent } from '@/components/ui/Card';
import { StatRow } from '@/components/ui/StatRow';

interface HealthFactorGaugeProps {
  healthFactor: bigint;
  className?: string;
}

export function HealthFactorGauge({ healthFactor, className = '' }: HealthFactorGaugeProps) {
  const status = getHealthStatus(healthFactor);
  const formatted = formatHealthFactor(healthFactor);
  const floatVal = healthFactorToFloat(healthFactor);
  
  // Radial mapping: 0 to 2.0 map to 0 to 180 degrees
  const angle = (floatVal / 2.0) * 180;
  
  const statusColors = {
    safe: 'text-green-500',
    warning: 'text-amber-500',
    danger: 'text-orange-500',
    liquidatable: 'text-red-500',
  };

  const statusBg = {
    safe: 'bg-green-500',
    warning: 'bg-amber-500',
    danger: 'bg-orange-500',
    liquidatable: 'bg-red-500',
  };

  const statusText = {
    safe: 'Safe',
    warning: 'Warning',
    danger: 'Danger',
    liquidatable: 'Liquidatable',
  };

  return (
    <Card className={`overflow-hidden ${className}`}>
      <CardContent className="p-6">
        <div className="flex flex-col items-center">
          <h4 className="text-sm font-medium text-slate-400 mb-6 w-full text-left">Health Factor</h4>
          
          <div className="relative w-48 h-24 mb-4">
            {/* Background Arc */}
            <div className="absolute inset-x-0 bottom-0 w-48 h-48 rounded-full border-[1.5rem] border-slate-800 border-t-transparent border-l-transparent border-r-transparent rotate-[-45deg]" />
            
            {/* Foreground Arc */}
            <div 
              className={`absolute inset-x-0 bottom-0 w-48 h-48 rounded-full border-[1.5rem] border-t-transparent border-l-transparent border-r-transparent ${statusBg[status].replace('bg-', 'border-')} transition-transform duration-700 ease-out`}
              style={{ transform: `rotate(${angle - 45 - 180}deg)` }}
            />
            
            <div className="absolute bottom-0 left-1/2 -translate-x-1/2 flex flex-col items-center">
              <span className={`text-4xl font-bold ${statusColors[status]}`}>
                {formatted}
              </span>
              <span className={`text-xs uppercase tracking-wider font-semibold mt-1 ${statusColors[status]}`}>
                {statusText[status]}
              </span>
            </div>
          </div>
          
          <div className="w-full flex justify-between text-xs text-slate-500 px-2 mt-2">
            <span>0.0</span>
            <span>1.0</span>
            <span>2.0+</span>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
