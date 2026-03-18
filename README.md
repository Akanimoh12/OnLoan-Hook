# OnLoan

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.26-363636.svg)](https://soliditylang.org/)

**OnLoan** is a decentralized lending protocol built as a **Uniswap v4 Hook** on **Unichain**, with automated liquidation powered by **Reactive Network**. Lenders earn dual yield from swap fees and borrower interest, while Reactive Smart Contracts ensure real-time health factor monitoring and trustless liquidation — no keepers required.

> **Submission for:** Atrium Academy UHI8 Hookathon
> **Sponsor Integration:** Reactive Network
> **Chain:** Unichain Sepolia (Chain ID 1301)

### Links

| | Link |
|---|---|
| Website | [onloan-hook.vercel.app](https://onloan-hook.vercel.app/) |
| Demo Video | [Loom Link](https://www.loom.com/share/demo-video-link) |
| Pitch Deck | [Canva Link](https://www.canva.com/design/DAHETVP5AV4/vYndLA7_qw3bUxRGUtq_zg/view?utm_content=DAHETVP5AV4&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=hb4a83ccb96) |
| GitHub | [github.com/Akanimoh12/OnLoan-Hook](https://github.com/Akanimoh12/OnLoan-Hook) |

---

## The Problem

Today's DeFi lending and AMM liquidity exist as **completely siloed systems**:

1. **Fragmented Capital** — Liquidity providers must choose between earning swap fees on Uniswap OR yield on lending protocols (Aave, Compound), but never both at the same time.
2. **Idle Collateral** — Borrowed assets sit locked in lending vaults generating zero swap fee revenue for the lenders who funded them.
3. **Liquidation Failures** — Traditional lending relies on off-chain keeper bots for liquidations, creating single points of failure, MEV extraction, and cascading bad debt during high-volatility events.
4. **No Cross-Chain Awareness** — Lending positions on one chain have zero visibility into collateral price movements on other chains.
5. **Complex UX** — Users must bridge, approve, deposit, and manage positions across multiple dApps and chains manually.

## The Solution

OnLoan hooks directly into Uniswap v4's swap and liquidity lifecycle, **unifying lending and AMM liquidity into a single protocol**:

- **Dual Yield** — Lenders deposit into Uniswap v4 pools via the hook and earn swap fees + lending interest simultaneously.
- **Hook-Native Lending** — Borrowers post collateral and borrow directly through `beforeSwap` / `afterSwap` hook logic. No separate lending contract needed.
- **Reactive Liquidations** — Reactive Network's autonomous smart contracts monitor collateral health factors across chains in real-time, triggering liquidations on-chain without off-chain bots.
- **Cross-Chain Collateral Monitoring** — Reactive Smart Contracts (RSCs) watch collateral value events across origin and destination chains.
- **One-Click UX** — Unified interface for lending, borrowing, and liquidity provision through a single Uniswap v4 pool.

---

## How It Works

```
Lender deposits USDC → LendingPool (via Hook) → Earns swap fees + interest
                                                          ↑
Borrower locks WETH collateral → Hook encodes borrow in swap → Receives USDC
                                                          ↓
Reactive RSC monitors health factor → Auto-liquidates if HF < 1.0
```

1. **Lend:** Users deposit USDC into the lending pool. They receive share tokens representing their portion of the pool.
2. **Borrow:** Users lock WETH or WBTC as collateral. The hook encodes borrow parameters into `hookData` during a swap, and the LoanManager creates the loan.
3. **Interest:** A kinked interest rate model adjusts rates based on pool utilization — rates spike above 80% utilization to incentivize repayment.
4. **Repay:** Borrowers repay via `donate()` on the Uniswap pool, which the hook intercepts to close the loan and return collateral.
5. **Liquidate:** If a borrower's health factor drops below 1.0, anyone can trigger liquidation. On Reactive Network, the LiquidationRSC does this autonomously.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Smart Contracts | Solidity ^0.8.26, Foundry |
| Hook Framework | Uniswap v4 (`v4-core`, `v4-periphery`) |
| Chain | Unichain Sepolia (ID 1301) |
| Automation | Reactive Network (Kopli Testnet) |
| Frontend | React 19, TypeScript, Vite, Tailwind CSS 4 |
| Web3 | wagmi 3.5, viem 2 |
| State | Zustand 5, TanStack React Query 5 |

---

## Deployed Contracts

### Unichain Sepolia (Chain ID 1301)

| Contract | Address | Explorer |
|----------|---------|----------|
| **OnLoanHook** | `0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0` | [View](https://sepolia.uniscan.xyz/address/0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0) |
| **LendingPool** | `0xD3ebBdbEB12C656B9743b94384999E0ff7010f36` | [View](https://sepolia.uniscan.xyz/address/0xD3ebBdbEB12C656B9743b94384999E0ff7010f36) |
| **LoanManager** | `0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46` | [View](https://sepolia.uniscan.xyz/address/0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46) |
| **CollateralManager** | `0xa97C9C8dD22db815a4AB3E3279562FD379F925c6` | [View](https://sepolia.uniscan.xyz/address/0xa97C9C8dD22db815a4AB3E3279562FD379F925c6) |
| **PriceOracle** | `0x1106661FB7104CFbd35E8477796D8CD9fB3806f2` | [View](https://sepolia.uniscan.xyz/address/0x1106661FB7104CFbd35E8477796D8CD9fB3806f2) |
| **LiquidationEngine** | `0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6` | [View](https://sepolia.uniscan.xyz/address/0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6) |
| **InterestRateModel** | `0xF2268d8133687e40AC174bCcA150677c42D74233` | [View](https://sepolia.uniscan.xyz/address/0xF2268d8133687e40AC174bCcA150677c42D74233) |
| **RiskEngine** | `0x1bdFc336373903E24BD46f8d22b14972f0fAEF83` | [View](https://sepolia.uniscan.xyz/address/0x1bdFc336373903E24BD46f8d22b14972f0fAEF83) |
| **ReceiptToken** | `0xEAE3b6033d744b8E0e817269df92004F3069bfB1` | [View](https://sepolia.uniscan.xyz/address/0xEAE3b6033d744b8E0e817269df92004F3069bfB1) |
| PoolManager (Uniswap) | `0x000000000004444c5dc75cB358380D2e3dE08A90` | [View](https://sepolia.uniscan.xyz/address/0x000000000004444c5dc75cB358380D2e3dE08A90) |

### Reactive Network (Kopli Testnet)

| Contract | Address |
|----------|---------|
| **LiquidationRSC** | `0x6F491FaBdEc72fD14e9E014f50B2ffF61C508bf1` |
| **CrossChainWatcher** | `0x012D911Dbc11232472A6AAF6b51E29A0C5929cC5` |

### Testnet Tokens

| Token | Address | Explorer |
|-------|---------|----------|
| USDC (6 dec) | `0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6` | [View](https://sepolia.uniscan.xyz/address/0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6) |
| WETH (18 dec) | `0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D` | [View](https://sepolia.uniscan.xyz/address/0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D) |
| WBTC (8 dec) | `0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8` | [View](https://sepolia.uniscan.xyz/address/0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8) |

---

## Quick Start

```bash
# Clone
git clone https://github.com/Akanimoh12/OnLoan-Hook.git
cd OnLoan-Hook

# Install all dependencies (contracts + frontend)
make install

# Build contracts
make build

# Run tests
make test

# Start frontend dev server
make frontend-dev
```

See [contracts/README.md](contracts/README.md) and [frontend/README.md](frontend/README.md) for detailed instructions.

## Project Structure

```
OnLoan-Hook/
├── contracts/src/     # Solidity smart contracts (10 modules, 28 files)
├── test/              # Foundry test suites (unit, fuzz, integration, invariant, gas, simulation)
├── script/            # Deployment & configuration scripts
├── frontend/          # React + TypeScript frontend
├── docs/              # Architecture docs, API reference, security analysis
├── deployments/       # Deployed contract addresses (JSON)
└── Makefile           # Build, test, deploy, and dev commands
```

## Documentation

- **[OnLoan Architecture](OnLoan.md)** — Full protocol design document
- **[Project Structure](PROJECT_STRUCTURE.md)** — Complete directory layout
- **[Getting Started](docs/guides/GETTING_STARTED.md)** — Setup guide
- **[Testing Guide](docs/guides/TESTING_GUIDE.md)** — How to write and run tests
- **[Deployment Guide](docs/guides/DEPLOYMENT_GUIDE.md)** — Deploy to testnet and mainnet

## Why Reactive Network

OnLoan integrates **Reactive Network** as its cross-chain automation layer:

| Reactive Feature | OnLoan Usage |
|---|---|
| Reactive Smart Contracts (RSCs) | Autonomously monitor health factors and trigger liquidations |
| Cross-Chain Event Listening | Watch collateral prices across Unichain and other chains |
| Inversion of Control | Liquidation logic reacts to on-chain events — no human intervention |
| No Off-Chain Dependencies | Eliminates keeper bots, centralized oracles, and external infra |

## Contributing

We welcome contributions! Please read our [Contributing Guide](docs/guides/CONTRIBUTING.md) before submitting a PR.

## License

This project is licensed under the [MIT License](LICENSE).
