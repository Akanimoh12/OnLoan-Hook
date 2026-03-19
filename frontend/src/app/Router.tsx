import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Dashboard } from '@/pages/Dashboard';
import { Lend } from '@/pages/Lend';
import { Borrow } from '@/pages/Borrow';
import { Markets } from '@/pages/Markets';
import { Liquidations } from '@/pages/Liquidations';
import { Faucet } from '@/pages/Faucet';

export function Router() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/lend" element={<Lend />} />
        <Route path="/borrow" element={<Borrow />} />
        <Route path="/markets" element={<Markets />} />
        <Route path="/liquidations" element={<Liquidations />} />
        <Route path="/faucet" element={<Faucet />} />
      </Routes>
    </BrowserRouter>
  );
}
