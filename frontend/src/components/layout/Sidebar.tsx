import { Link, useLocation } from 'react-router-dom';

const navItems = [
  { label: 'Dashboard', path: '/' },
  { label: 'Markets', path: '/markets' },
  { label: 'Lend', path: '/lend' },
  { label: 'Borrow', path: '/borrow' },
  { label: 'Liquidations', path: '/liquidations' },
];

export function Sidebar() {
  const location = useLocation();

  return (
    <aside className="w-64 border-r border-slate-800 bg-slate-950 flex-col hidden lg:flex">
      <div className="h-16 flex items-center px-6 border-b border-slate-800">
        <Link to="/" className="text-xl font-bold bg-gradient-to-r from-violet-400 to-fuchsia-400 bg-clip-text text-transparent">
          OnLoan
        </Link>
      </div>
      <nav className="flex-1 py-6 px-4 space-y-2">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path || 
                           (item.path !== '/' && location.pathname.startsWith(item.path));
          
          return (
            <Link
              key={item.path}
              to={item.path}
              className={`flex items-center space-x-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                isActive 
                  ? 'bg-violet-500/10 text-violet-400' 
                  : 'text-slate-400 hover:text-slate-100 hover:bg-slate-800/50'
              }`}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>
      <div className="p-4 border-t border-slate-800">
        <div className="text-xs text-slate-500 flex justify-between">
          <span>Unichain Sepolia</span>
          <span className="flex h-2 w-2 rounded-full bg-green-500 mt-1"></span>
        </div>
      </div>
    </aside>
  );
}
