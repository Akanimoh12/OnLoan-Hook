import { BrowserRouter, Routes, Route } from 'react-router-dom';

function DashboardPage() {
  return <div>Dashboard — Coming Soon</div>;
}

function LendPage() {
  return <div>Lend — Coming Soon</div>;
}

function BorrowPage() {
  return <div>Borrow — Coming Soon</div>;
}

function MarketsPage() {
  return <div>Markets — Coming Soon</div>;
}

function LiquidationsPage() {
  return <div>Liquidations — Coming Soon</div>;
}

export function Router() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/lend" element={<LendPage />} />
        <Route path="/borrow" element={<BorrowPage />} />
        <Route path="/markets" element={<MarketsPage />} />
        <Route path="/liquidations" element={<LiquidationsPage />} />
      </Routes>
    </BrowserRouter>
  );
}
