# OnLoan — Frontend

React + TypeScript frontend for the OnLoan lending protocol. Reads and writes directly to deployed smart contracts on Unichain Sepolia via wagmi/viem.

## Tech Stack

| Technology | Purpose |
|------------|---------|
| React 19 | UI framework |
| TypeScript 5.9 | Type safety |
| Vite 7 | Build tool & dev server |
| Tailwind CSS 4 | Styling |
| wagmi 3.5 | Ethereum hooks (contract reads/writes, wallet) |
| viem 2 | Low-level EVM interaction |
| TanStack React Query 5 | Async state & caching |
| Zustand 5 | Global state management |
| Radix UI | Accessible primitives |
| React Router 7 | Client-side routing |

## Prerequisites

- Node.js >= 20.19 (or >= 22.12)
- pnpm (recommended) or npm

## Setup & Run

```bash
# From the repo root
cd frontend

# Install dependencies
pnpm install

# Start development server (http://localhost:5173)
pnpm dev

# Type-check
pnpm exec tsc --noEmit

# Lint
pnpm lint

# Production build
pnpm build

# Preview production build
pnpm preview
```

Or from the repo root:

```bash
make frontend-dev     # start dev server
make frontend-build   # production build
```

## Project Structure

```
frontend/src/
├── abis/           # Contract ABI JSON files
├── app/            # App.tsx, Providers.tsx, Router.tsx
├── components/
│   ├── borrow/     # BorrowForm, LoanCard
│   ├── health/     # HealthFactorGauge, LiquidationWarning
│   ├── layout/     # Shell, Sidebar, Navbar
│   ├── lending/    # LendingPoolCard, UtilizationBar
│   ├── liquidations/ # LiquidationTable
│   └── ui/         # Card, Button, Badge, Skeleton, etc.
├── hooks/          # wagmi hooks (usePoolState, useLoan, useBorrow, etc.)
├── lib/            # constants, wagmi config, chains, SDK helpers
├── pages/          # Dashboard, Lend, Borrow, Markets, Liquidations
├── styles/         # globals.css (Tailwind + custom variables)
├── types/          # TypeScript type definitions
└── main.tsx        # Entry point
```

## Connecting a Wallet

1. Open the app at `http://localhost:5173`
2. Click **Connect Wallet** in the top-right
3. Approve the connection in MetaMask / your injected wallet
4. Make sure you are on **Unichain Sepolia (Chain ID 1301)**

### Adding Unichain Sepolia to MetaMask

| Field | Value |
|-------|-------|
| Network Name | Unichain Sepolia |
| RPC URL | `https://sepolia.unichain.org` |
| Chain ID | `1301` |
| Currency Symbol | `ETH` |
| Block Explorer | `https://sepolia.uniscan.xyz` |

## Getting Testnet Tokens

1. **ETH (gas)** — Use the [Unichain Faucet](https://faucet.unichain.org/) to get testnet ETH
2. **USDC / WETH / WBTC** — These are custom testnet ERC20s deployed by the protocol. If you are the deployer, mint tokens via cast:

```bash
# Mint 1,000 USDC (6 decimals → 1000 * 10^6 = 1000000000)
cast send 0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6 \
  "mint(address,uint256)" YOUR_WALLET_ADDRESS 1000000000 \
  --rpc-url https://sepolia.unichain.org --private-key YOUR_KEY

# Mint 1 WETH (18 decimals → 1 * 10^18 = 1000000000000000000)
cast send 0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D \
  "mint(address,uint256)" YOUR_WALLET_ADDRESS 1000000000000000000 \
  --rpc-url https://sepolia.unichain.org --private-key YOUR_KEY
```

## Testing the App

| Flow | Steps |
|------|-------|
| **Lend** | Go to `/lend` → Enter USDC amount → Click "Supply Assets" → Approve token → Confirm tx |
| **Withdraw** | Go to `/lend` → Enter shares amount → Click "Withdraw Shares" |
| **Borrow** | Go to `/borrow` → Select WETH collateral → Set amounts & duration → Click "Initiate Borrow" |
| **Repay** | Go to `/borrow` → Click "Repay Full Balance" on your loan card |
| **Markets** | Go to `/markets` → View live pool stats, APRs, utilization |
| **Liquidations** | Go to `/liquidations` → See all borrowers with health factors → Click "Liquidate" on unhealthy positions |

## Environment

The frontend reads contract addresses and chain configuration from `src/lib/constants.ts`. No `.env` file is needed — all addresses are hardcoded for the current Unichain Sepolia deployment.
