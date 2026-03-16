import * as React from 'react';

export interface BadgeProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'outline';
}

export function Badge({ className = '', variant = 'default', ...props }: BadgeProps) {
  const base = 'inline-flex items-center rounded-md px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-violet-500';
  
  const variants = {
    default: 'bg-slate-800 text-slate-100',
    success: 'bg-green-500/10 text-green-500 border border-green-500/20',
    warning: 'bg-amber-500/10 text-amber-500 border border-amber-500/20',
    danger:  'bg-red-500/10 text-red-500 border border-red-500/20',
    outline: 'text-slate-300 border border-slate-700',
  };

  return <div className={`${base} ${variants[variant]} ${className}`} {...props} />;
}
