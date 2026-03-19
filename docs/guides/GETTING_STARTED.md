# Getting Started with OnLoan

This guide walks you through testing the OnLoan protocol end-to-end on Unichain Sepolia — from claiming testnet tokens to borrowing and watching the Reactive RSC auto-liquidate a position.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| MetaMask | Latest | [metamask.io](https://metamask.io) |
| Node.js | 20+ | [nodejs.org](https://nodejs.org) |
| Foundry | Latest | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| Git | Any | `sudo apt install git` |

---

## 1. Add Unichain Sepolia to MetaMask

| Field | Value |
|-------|-------|
| Network Name | Unichain Sepolia |
| RPC URL | `https://sepolia.unichain.org` |
| Chain ID | `1301` |
| Currency Symbol | ETH |
| Block Explorer | `https://sepolia.uniscan.xyz` |

Get testnet ETH for gas from the [Unichain Sepolia faucet](https://faucet.quicknode.com/unichain/sepolia).

---

## 2. Claim Testnet Tokens

The protocol uses three mock ERC-20 tokens that are permissionlessly mintable.

**Option A — Use the Faucet UI (easiest):**
1. Open [onloan-hook.vercel.app/faucet](https://onloan-hook.vercel.app/faucet)
2. Connect MetaMask
3. Click "Claim Tokens" for each of USDC, WETH, and WBTC
4. Confirm each transaction (3 total)

You'll receive: **10,000 USDC**, **10 WETH**, **0.5 WBTC**

**Option B — Mint via cast:**
```bash
# USDC: 10,000 (6 decimals)
cast send 0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6 \
  "mint(address,uint256)" <YOUR_ADDRESS> 10000000000 \
  --rpc-url https://sepolia.unichain.org \
  --private-key <YOUR_KEY>

# WETH: 10 (18 decimals)
cast send 0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D \
  "mint(address,uint256)" <YOUR_ADDRESS> 10000000000000000000 \
  --rpc-url https://sepolia.unichain.org \
  --private-key <YOUR_KEY>

# WBTC: 0.5 (8 decimals)
cast send 0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8 \
  "mint(address,uint256)" <YOUR_ADDRESS> 50000000 \
  --rpc-url https://sepolia.unichain.org \
  --private-key <YOUR_KEY>
```

---

## 3. Lend USDC

1. Go to **Lend** (`/lend`)
2. Enter amount (e.g. 5,000 USDC)
3. Approve USDC spend → Deposit
4. You receive ERC-6909 receipt tokens representing your pool share
5. Your deposit earns **swap fees + lending interest** from this point

> Note: There is a 1-day withdrawal cooldown to protect pool liquidity.

---

## 4. Borrow USDC

1. Go to **Borrow** (`/borrow`)
2. Select collateral: **WETH** (75% max LTV) or **WBTC** (70% max LTV)
3. Enter collateral amount
4. Enter borrow amount (must be ≤ max LTV × collateral value)
5. Select duration (1–365 days)
6. Approve collateral → Borrow

**Under the hood:** The UI calls `depositCollateral()` first, then encodes your borrow parameters into `hookData` and calls `PoolManager.swap()`. The `beforeSwap` hook validates the LTV, creates the loan, and the swap executes.

After borrowing, your **Dashboard** shows:
- Active loan amount and interest accrued
- Health factor gauge (safe > 1.5, warning 1.2–1.5, danger 1.0–1.2, liquidatable < 1.0)
- Time remaining on the loan

---

## 5. Repay Your Loan

1. Go to **Borrow** (`/borrow`) → your active LoanCard
2. Click **Repay Loan**
3. Approve USDC → Repay

**Under the hood:** The UI encodes a repay flag into `hookData` and calls `PoolManager.donate()`. The `afterDonate` hook closes the loan, distributes interest to lenders, and unlocks your collateral.

---

## 6. Withdraw as a Lender

1. Go to **Lend** (`/lend`)
2. After the 1-day cooldown has elapsed, enter shares to redeem
3. Click **Withdraw**

You receive your USDC principal plus your proportional share of interest earned while the pool was active.

---

## 7. Watch the Liquidation Flow (Advanced)

To observe the Reactive RSC in action:

1. Borrow a large amount close to max LTV (e.g., 7,400 USDC against 1 WETH at $10,000 value → HF ≈ 1.08)
2. Wait for the oracle price to be updated downward (or ask the team to update the price oracle)
3. When HF drops below 1.0, the `LiquidationRSC` on Reactive Network fires a callback
4. Reactive Network relays the callback to `OnLoanHook.liquidateLoan()` on Unichain
5. The position is liquidated: collateral is seized, debt is cleared, liquidator receives 5% bonus

You can watch the liquidation happen on the **Liquidations** page (`/liquidations`).

---

## Running the Frontend Locally

```bash
git clone https://github.com/Akanimoh12/OnLoan-Hook.git
cd OnLoan-Hook/frontend

npm install

# Set up environment
cp .env.example .env
# Edit .env — add a custom RPC to avoid rate limits:
# VITE_RPC_URL_TESTNET=https://unichain-sepolia.g.alchemy.com/v2/YOUR_KEY

npm run dev
# → http://localhost:5173
```

> Get a free Alchemy key at [alchemy.com](https://www.alchemy.com) — select "Unichain Sepolia" when creating the app.

---

## Running Tests

```bash
cd contracts
forge install
forge build
forge test           # all 211 tests
forge test -vvv      # verbose output
forge test --gas-report
```

See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed test documentation.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| MetaMask shows wrong network | Not on Unichain Sepolia | Switch to Chain ID 1301 |
| Transaction fails with "Insufficient balance" | No testnet USDC/WETH/WBTC | Use the Faucet page |
| "RPC too many requests" in console | Public RPC rate-limited | Set `VITE_RPC_URL_TESTNET` in `.env` |
| Health factor not updating | Stale oracle price | Oracle price must be updated on-chain |
| Withdrawal blocked | Cooldown not elapsed | Wait 24h after deposit |
