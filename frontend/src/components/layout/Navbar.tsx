import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { shortenAddress } from '@/lib/utils';
import { Button } from '@/components/ui/Button';

export function Navbar() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  // Typically just use the first injected connector
  const injector = connectors.find((c) => c.id === 'injected');

  return (
    <header className="h-16 border-b border-slate-800 bg-slate-950/50 backdrop-blur-md flex items-center justify-between px-6 sticky top-0 z-10 w-full">
      <div className="flex items-center lg:hidden">
        <span className="text-xl font-bold bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">
          OnLoan
        </span>
      </div>
      
      {/* Spacer for desktop since sidebar handles logo */}
      <div className="hidden lg:block"></div>

      <div className="flex items-center space-x-4">
        {isConnected && address ? (
          <div className="flex items-center space-x-3">
            <span className="text-sm font-mono text-slate-300 bg-slate-800 px-3 py-1.5 rounded-lg border border-slate-700">
              {shortenAddress(address)}
            </span>
            <Button variant="ghost" onClick={() => disconnect()} className="h-9 px-3 text-xs">
              Disconnect
            </Button>
          </div>
        ) : (
          <Button 
            onClick={() => injector && connect({ connector: injector })} 
            isLoading={isPending}
            className="h-9"
          >
            Connect Wallet
          </Button>
        )}
      </div>
    </header>
  );
}
