import { formatUnits } from 'viem';
import { useAccount, useConnect, useDisconnect, useBalance } from 'wagmi';
import { shortenAddress } from '@/lib/utils';
import { Button } from '@/components/ui/Button';

export function Navbar() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { data: balance } = useBalance({ address });
  const formattedBalance = balance
    ? Number(formatUnits(balance.value, balance.decimals))
    : 0;

  const injector = connectors.find((c) => c.id === 'injected');

  return (
    <header className="h-16 border-b border-slate-800/60 bg-[#0c0c14]/80 backdrop-blur-xl flex items-center justify-between px-6 sticky top-0 z-10 w-full">
      <div className="flex items-center lg:hidden">
        <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-violet-500 to-fuchsia-500 flex items-center justify-center text-white font-bold text-sm mr-2">
          O
        </div>
        <span className="text-lg font-bold bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">
          OnLoan
        </span>
      </div>
      
      <div className="hidden lg:block" />

      <div className="flex items-center gap-3">
        {isConnected && address ? (
          <>
            {balance && (
              <div className="hidden sm:flex items-center gap-1.5 text-xs text-slate-400 bg-slate-900/60 border border-slate-800/60 px-3 py-1.5 rounded-lg">
                <span className="text-slate-500">Balance:</span>
                <span className="text-slate-200 font-medium">
                  {Number.isFinite(formattedBalance) ? formattedBalance.toFixed(4) : '0.0000'} {balance.symbol}
                </span>
              </div>
            )}
            <div className="flex items-center gap-2 bg-slate-900/60 border border-slate-800/60 rounded-lg px-1 py-1">
              <div className="flex items-center gap-2 px-2.5 py-1">
                <span className="relative flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-green-500"></span>
                </span>
                <span className="text-sm font-mono text-slate-300">
                  {shortenAddress(address)}
                </span>
              </div>
              <button
                onClick={() => disconnect()}
                className="text-xs text-slate-500 hover:text-red-400 transition-colors bg-slate-800/60 hover:bg-red-500/10 rounded-md px-2.5 py-1.5 font-medium"
              >
                Disconnect
              </button>
            </div>
          </>
        ) : (
          <Button 
            onClick={() => injector && connect({ connector: injector })} 
            isLoading={isPending}
            className="h-9 shadow-lg shadow-violet-500/20"
          >
            <svg className="w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            Connect Wallet
          </Button>
        )}
      </div>
    </header>
  );
}
