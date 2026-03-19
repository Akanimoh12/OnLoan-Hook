# Reactive Network Integration

OnLoan uses **Reactive Network** as its autonomous liquidation layer. This document explains exactly how the integration works, what was built, and why it matters.

---

## Why Reactive Network?

Traditional lending protocols use off-chain keeper bots to watch for undercollateralized positions and call `liquidate()`. This model has three failure modes:

**1. Liveness failure** — If the keeper goes down (server crash, API failure, network partition), positions can go undercollateralized without being liquidated. Bad debt accumulates.

**2. Gas wars during market stress** — When collateral prices crash rapidly, every keeper races to liquidate the same positions. Gas prices spike. Keepers with lower gas bids lose. Liquidations are delayed.

**3. MEV extraction** — Searchers front-run keepers' liquidation transactions, capturing the liquidation bonus through sandwich attacks. This extracts value from both the liquidator and the protocol.

Reactive Network solves all three by moving the liquidation trigger **on-chain**, where it reacts to events rather than polling.

---

## What is a Reactive Smart Contract (RSC)?

An RSC is a smart contract deployed on Reactive Network that:

1. **Subscribes** to event topics on any EVM-compatible chain (origin chain)
2. **Executes logic** when those events are emitted — entirely on-chain, no off-chain server
3. **Emits a Callback** that Reactive Network relays to a destination chain

The key insight: the RSC *reacts* to events. There is no polling loop. There is no cron job. There is no server that needs to stay online.

---

## OnLoan RSC Architecture

### LiquidationRSC

**Deployed at:** `0x6F491FaBdEc72fD14e9E014f50B2ffF61C508bf1` (Reactive Network Kopli Testnet)

**Subscribes to events from Unichain Sepolia:**

| Event | Source Contract | Purpose |
|-------|-----------------|---------|
| `LoanCreated(borrower, collateralToken, amount, borrowed)` | LoanManager | Track new active positions |
| `CollateralDeposited(borrower, token, amount)` | CollateralManager | Update collateral state |
| `PriceUpdated(token, newPrice, timestamp)` | PriceOracle | Trigger health factor re-evaluation |
| `LoanFullyRepaid(borrower)` | LoanManager | Remove position from tracking |
| `LoanLiquidated(borrower)` | LiquidationEngine | Remove position from tracking |

**On each `PriceUpdated` event:**
1. RSC reads the new price from the event data
2. For every tracked borrower: `HF = (collateralValue × threshold) / debt`
3. If `HF < 1.0` and `block.timestamp > lastLiquidationAttempt[borrower] + cooldown`:
   - Emit `Callback(borrower)` event
4. Reactive Network relays the callback to `OnLoanHook.liquidateLoan(borrower)` on Unichain
5. `LiquidationEngine` performs a final on-chain HF check before executing

```
PriceUpdated (Unichain)
      │
      ▼
LiquidationRSC.react(event) — on Reactive Network
      │
      ├─ recalculate HF for all tracked borrowers
      │
      ├─ HF < 1.0 AND cooldown elapsed?
      │         │
      │         ▼
      │   emit Callback(borrower)
      │
      ▼
Reactive Network relays callback
      │
      ▼
OnLoanHook.liquidateLoan(borrower) — back on Unichain
      │
      ▼
LiquidationEngine.liquidateLoan(borrower)
      │
      ├─ on-chain HF check (final validation)
      ├─ seize collateral
      ├─ settle debt with lending pool
      └─ pay liquidation bonus to liquidator
```

### CrossChainCollateralWatcher

**Deployed at:** `0x012D911Dbc11232472A6AAF6b51E29A0C5929cC5` (Reactive Network Kopli Testnet)

This RSC monitors collateral price events across multiple chains. In a multi-chain DeFi environment, collateral held on one chain can lose value based on market movements observed on another chain. The CrossChainWatcher provides:

- **Multi-chain event subscriptions** for supported collateral tokens
- **Cross-chain health factor re-evaluation** when price events arrive from any subscribed chain
- **Callback emission** to the destination chain (Unichain) when cross-chain conditions are met

---

## RSC Configuration

```solidity
// Per-borrower liquidation cooldown — prevents duplicate spam
uint256 public constant LIQUIDATION_COOLDOWN = 1 hours;

// Warning threshold — emits HealthFactorWarning before liquidation threshold
uint256 public constant WARNING_THRESHOLD_BPS = 13_000; // HF < 1.3

// Health factor basis points precision
uint256 public constant HF_PRECISION = 10_000; // 1.0 = 10_000

// Liquidation threshold — triggers full liquidation callback
uint256 public constant LIQUIDATION_THRESHOLD_BPS = 10_000; // HF < 1.0
```

---

## Two-Tier Safety Architecture

OnLoan implements a deliberate two-tier health check:

**Tier 1 — RSC (Off-Chain Reactive)**
- Runs off Unichain on Reactive Network
- Reacts to price events with minimal latency
- Performs HF calculation using event data
- Emits callback if HF < 1.0
- First-mover advantage: triggers liquidation faster than any keeper

**Tier 2 — LiquidationEngine (On-Chain Final)**
- Executes on Unichain when callback arrives
- Independently fetches current oracle price
- Independently recalculates HF from on-chain state
- Only executes if HF is still < 1.0 at execution time
- Acts as the authoritative truth — RSC cannot override it

This design ensures:
- **False positives are harmless** — RSC sends a callback, on-chain check rejects it
- **Race conditions are handled** — if borrower repays between RSC callback and on-chain execution, the on-chain check catches it and no liquidation occurs
- **No central authority** — the RSC is one of many authorized liquidators; anyone can also call `LiquidationEngine.liquidateLoan()` directly

---

## Event Subscription Setup

RSC subscriptions are configured via `SubscribeRSC.s.sol`:

```bash
# Deploy RSC on Reactive Network
forge script script/deploy/DeployReactiveMonitor.s.sol \
  --rpc-url https://kopli-rpc.reactive.network \
  --broadcast

# Subscribe to events on Unichain Sepolia
forge script script/deploy/SubscribeRSC.s.sol \
  --rpc-url https://kopli-rpc.reactive.network \
  --broadcast
```

The subscription registers:
- Origin chain ID: 1301 (Unichain Sepolia)
- Origin contract: `OnLoanHook`, `LoanManager`, `CollateralManager`, `PriceOracle`
- Event topics: keccak256 of each event signature
- Destination chain ID: 1301 (Unichain Sepolia)
- Destination contract: `OnLoanHook`
- Callback function: `liquidateLoan(address borrower)`

---

## Why This Matters for DeFi

The keeper model is a crutch from 2020 DeFi. It worked when:
- Gas was cheap
- Block times were slow (slower liquidation races)
- Markets were less volatile

In 2025 DeFi:
- Gas spikes are routine during volatility
- Block times are sub-second (Unichain: 2ms)
- Market crashes are faster and deeper

OnLoan's RSC-based liquidation is the correct architecture for this environment: event-driven, on-chain, no external dependencies, and immune to keeper downtime.
