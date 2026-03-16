import * as React from 'react';
import { Sidebar } from './Sidebar';
import { Navbar } from './Navbar';

interface ShellProps {
  children: React.ReactNode;
}

export function Shell({ children }: ShellProps) {
  return (
    <div className="min-h-screen bg-[#0a0a0f] text-slate-100 flex font-sans selection:bg-violet-500/30">
      <Sidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <Navbar />
        <main className="flex-1 p-4 lg:p-8 overflow-y-auto">
          <div className="mx-auto max-w-6xl">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
