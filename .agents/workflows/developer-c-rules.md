# Developer C — OnLoan Product & Integration Engineer Rules

> This document is the authoritative implementation guide for Developer C.
> Follow every rule in order. Deviation without explicit approval from the team lead is not permitted.

---

## Branch Policy

- All Developer C work is done on branch `frontend`.
- Branch from `main`. Never commit directly to `main`.
- Open a pull request to `main` only after the full E2E checklist (Section 10) passes.
- Branch name must not be changed.

---

## 0. Global Engineering Standards

- TypeScript strict mode is on. Zero `any` types. Zero `@ts-ignore` comments.
- No `console.log` left in committed code. Use structured logging utilities only.
- All async functions must handle errors explicitly — no silent swallows.
- All `bigint` arithmetic uses `viem` primitives (`parseUnits`, `formatUnits`). Never use raw JavaScript `number` for token amounts.
- All addresses stored as `0x${string}`. Never `string`.
- No emojis in code, comments, or commit messages.
- Commits are written in past active tense, concise. Example: `added borrow form validation`, `wired health factor hook`.
- When a security issue is found, stop and flag it immediately before proceeding.

---

## 0b. Modular Commits Policy

Every commit must represent exactly one logical unit of work. This is strictly enforced.

**Rules:**

- One commit per file group that belongs to the same concern (e.g., all hooks committed together is wrong — each hook is its own commit).
- Never bundle unrelated files in a single commit.
- Commit immediately after completing each item in the task checklist — do not batch multiple checklist items into one commit.
- Commit message must clearly name what was added or changed, not just `update` or `fix`.
- If a commit requires changes to more than 3 files, ask yourself if it can be split.

**Required commit sequence (in order):**

```
build: extracted ABI files from foundry output
config: populated contract addresses in constants
config: added testnet connector to wagmi config
types: defined all on-chain domain types
sdk: added payload encoders and formatting helpers
utils: added address and token formatting helpers
hook: added usePoolState
hook: added useLoan
hook: added useBorrow
hook: added useRepay
hook: added useDeposit
hook: added useWithdraw
hook: added useLiquidations
store: added useAppStore
ui: added Button, Card, Badge primitives
ui: added Skeleton, Spinner, StatRow, ErrorMessage
layout: added Shell, Navbar, Sidebar
health: added HealthFactorGauge
health: added LiquidationWarning
lending: added LendingPoolCard and UtilizationBar
borrow: added BorrowForm
borrow: added LoanCard
liquidations: added LiquidationTable
page: implemented dashboard
page: implemented markets
page: implemented lend
page: implemented borrow
page: implemented liquidations
router: wired all pages into Router
style: extended globals.css with design tokens
deploy: added .env.example
```

---

## 1. Repository Layout

Work is confined to the `frontend/` directory unless explicitly stated otherwise.

```
frontend/
  src/
    abis/               # ABI JSON files extracted from Foundry build
    app/                # Page components and app shell
      App.tsx
      Providers.tsx
      Router.tsx        # Extend this — do not rewrite
    components/         # Reusable UI components
      ui/               # Primitives (Button, Badge, Card, etc.)
      layout/           # Shell, Navbar, Sidebar
      lending/          # LendingPoolCard, UtilizationBar
      borrow/           # BorrowForm, LoanCard, CollateralSelector
      health/           # HealthFactorGauge, LiquidationWarning
      liquidations/     # LiquidationTable, LiquidationCard
    hooks/              # Custom wagmi/react-query hooks
    lib/
      abis.ts           # Exports typed ABIs
      chains.ts         # Already done — do not modify
      constants.ts      # Populate contract addresses from deployments/addresses.json
      sdk.ts            # Payload encoding layer
      wagmi.ts          # Already done — do not modify
      utils.ts          # Formatting helpers
    stores/             # Zustand global state stores
    types/
      index.ts          # All shared TypeScript types
    styles/
      globals.css       # Already exists — extend only
    main.tsx            # Already done — do not modify
```

---

## 2. Step 1 — Bootstrap (Must Complete Before Any UI Work)

### 2.1 Extract ABIs

Run from the project root:

```bash
forge build
```

Copy the following ABI arrays from `out/` into individual files under `frontend/src/abis/`:

| File to create                             | Source                                                           |
| ------------------------------------------ | ---------------------------------------------------------------- |
| `frontend/src/abis/OnLoanHook.json`        | `out/OnLoanHook.sol/OnLoanHook.json` → `abi` field               |
| `frontend/src/abis/LendingPool.json`       | `out/LendingPool.sol/LendingPool.json` → `abi` field             |
| `frontend/src/abis/LoanManager.json`       | `out/LoanManager.sol/LoanManager.json` → `abi` field             |
| `frontend/src/abis/CollateralManager.json` | `out/CollateralManager.sol/CollateralManager.json` → `abi` field |
| `frontend/src/abis/PriceOracle.json`       | `out/PriceOracle.sol/PriceOracle.json` → `abi` field             |

Each file must contain only the `abi` array — not the full Foundry output object.

### 2.2 Create `frontend/src/lib/abis.ts`

```ts
import OnLoanHookAbi from "@/abis/OnLoanHook.json";
import LendingPoolAbi from "@/abis/LendingPool.json";
import LoanManagerAbi from "@/abis/LoanManager.json";
import CollateralManagerAbi from "@/abis/CollateralManager.json";
import PriceOracleAbi from "@/abis/PriceOracle.json";

export { OnLoanHookAbi, LendingPoolAbi, LoanManagerAbi, CollateralManagerAbi, PriceOracleAbi };
```

### 2.3 Populate `frontend/src/lib/constants.ts`

Read `deployments/addresses.json` and `deployments/testnet-tokens.json`. Populate fully:

```ts
// Contract addresses — sourced from deployments/addresses.json
// Chain: Unichain Sepolia (chainId 1301)

export const CONTRACTS = {
    onLoanHook: "0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0" as `0x${string}`,
    lendingPool: "0xD3ebBdbEB12C656B9743b94384999E0ff7010f36" as `0x${string}`,
    loanManager: "0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46" as `0x${string}`,
    collateralManager: "0xa97C9C8dD22db815a4AB3E3279562FD379F925c6" as `0x${string}`,
    priceOracle: "0x1106661FB7104CFbd35E8477796D8CD9fB3806f2" as `0x${string}`,
    liquidationEngine: "0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6" as `0x${string}`,
    poolManager: "" as `0x${string}`, // Set from deploymnet output
} as const;

export const HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1_0000n; // 1.0 in 4 decimal BPS
export const HEALTH_FACTOR_WARNING_THRESHOLD = 1_2000n; // 1.2 in 4 decimal BPS
export const BPS_DENOMINATOR = 10_000n;
export const WAD = 10n ** 18n;
```

### 2.4 Update `frontend/src/lib/wagmi.ts`

Add `unichainTestnet` alongside `unichain` and expose a connector list with `injected` and `walletConnect`:

```ts
import { http, createConfig, injected } from "wagmi";
import { unichain, unichainTestnet } from "@/lib/chains";

export const config = createConfig({
    chains: [unichainTestnet, unichain],
    connectors: [injected()],
    transports: {
        [unichainTestnet.id]: http(),
        [unichain.id]: http(),
    },
});
```

---

## 3. Step 2 — TypeScript Types (`frontend/src/types/index.ts`)

Define all domain types. These must mirror the on-chain struct definitions exactly.

```ts
// Mirrors LoanTypes.sol :: Loan
export interface Loan {
    borrower: `0x${string}`;
    collateralToken: `0x${string}`;
    collateralAmount: bigint;
    borrowedAmount: bigint;
    accruedInterest: bigint;
    interestRateAtOrigination: bigint;
    startTime: bigint;
    lastAccrualTime: bigint;
    duration: bigint;
    active: boolean;
}

// Mirrors LoanTypes.sol :: CollateralInfo
export interface CollateralInfo {
    token: `0x${string}`;
    isSupported: boolean;
    liquidationThreshold: bigint;
    maxLTV: bigint;
    liquidationBonus: bigint;
}

// Mirrors LoanTypes.sol :: LenderPosition
export interface LenderPosition {
    deposited: bigint;
    shares: bigint;
    lastDepositTime: bigint;
}

// Mirrors PoolTypes.sol :: LendingPoolState
export interface LendingPoolState {
    totalDeposited: bigint;
    totalBorrowed: bigint;
    totalShares: bigint;
    lastUpdateTime: bigint;
    accumulatedProtocolFees: bigint;
}

// Mirrors IRiskEngine.sol :: RiskAssessment
export interface RiskAssessment {
    borrower: `0x${string}`;
    healthFactor: bigint;
    collateralValueUSD: bigint;
    debtValueUSD: bigint;
    liquidationThreshold: bigint;
    isLiquidatable: boolean;
    isExpired: boolean;
    isWarning: boolean;
}

// UI-only types
export type HealthStatus = "safe" | "warning" | "danger" | "liquidatable";

export interface BorrowFormState {
    collateralToken: `0x${string}` | "";
    collateralAmount: string;
    borrowAmount: string;
    durationDays: number;
}

export interface LendFormState {
    amount: string;
}
```

---

## 4. Step 3 — SDK Layer (`frontend/src/lib/sdk.ts`)

This is the single most critical file. It encodes all `hookData` payloads that the contract reads.
The encoding must match `OnLoanHook.sol` exactly — any mismatch causes a silent transaction failure.

```ts
import { encodeAbiParameters, parseAbiParameters } from "viem";

// Borrow flag as defined in OnLoanHook.sol
const BORROW_FLAG = "0x01" as const;
// Repay flag as defined in OnLoanHook.sol
const REPAY_FLAG = "0x02" as const;

/**
 * Encodes hookData for a borrow-via-swap call.
 * Maps to: abi.decode(hookData, (bytes1, address, address, uint256, uint256, uint256))
 *
 * @param borrower         - Address initiating the borrow
 * @param collateralToken  - ERC-20 address used as collateral
 * @param collateralAmount - Raw amount in token's native decimals
 * @param borrowAmount     - Raw amount in borrow token's native decimals
 * @param durationSeconds  - Loan duration in seconds
 */
export function encodeBorrowPayload(
    borrower: `0x${string}`,
    collateralToken: `0x${string}`,
    collateralAmount: bigint,
    borrowAmount: bigint,
    durationSeconds: bigint,
): `0x${string}` {
    return encodeAbiParameters(parseAbiParameters("bytes1, address, address, uint256, uint256, uint256"), [
        BORROW_FLAG,
        borrower,
        collateralToken,
        collateralAmount,
        borrowAmount,
        durationSeconds,
    ]);
}

/**
 * Encodes hookData for a repay-via-donate call.
 * Maps to: abi.decode(hookData, (bytes1, address))
 *
 * @param borrower - Address whose loan is being repaid
 */
export function encodeRepayPayload(borrower: `0x${string}`): `0x${string}` {
    return encodeAbiParameters(parseAbiParameters("bytes1, address"), [REPAY_FLAG, borrower]);
}

/**
 * Derives a human-readable health status label from a raw health factor.
 * Health factor is returned from the contract as a uint256 with 4 decimal BPS precision.
 * 10000 = 1.0 in BPS notation.
 */
export function getHealthStatus(healthFactor: bigint): import("@/types").HealthStatus {
    if (healthFactor === 0n) return "liquidatable";
    if (healthFactor < 10_000n) return "liquidatable";
    if (healthFactor < 12_000n) return "danger";
    if (healthFactor < 15_000n) return "warning";
    return "safe";
}

/**
 * Formats a raw BPS health factor to a human-readable string.
 * 10000 => "1.0000", 12500 => "1.2500"
 */
export function formatHealthFactor(healthFactor: bigint): string {
    const whole = healthFactor / 10_000n;
    const frac = healthFactor % 10_000n;
    return `${whole}.${frac.toString().padStart(4, "0")}`;
}

/**
 * Formats a raw utilization rate (BPS, 10000 = 100%) to a percentage string.
 */
export function formatUtilization(rateBps: bigint): string {
    const pct = Number(rateBps) / 100;
    return `${pct.toFixed(2)}%`;
}

/**
 * Formats a raw interest rate (BPS, 10000 = 100%) to an APR string.
 */
export function formatApr(rateBps: bigint): string {
    const pct = Number(rateBps) / 100;
    return `${pct.toFixed(2)}% APR`;
}
```

---

## 5. Step 4 — Custom Hooks (`frontend/src/hooks/`)

### File naming convention: `use<Resource><Action>.ts`

### 5.1 `hooks/usePoolState.ts`

Reads `LendingPool.getPoolState(poolId)` using `useReadContract`.

```
- Input: poolId as `0x${string}` (the PoolId encoded bytes32)
- Returns: { data: LendingPoolState | undefined, isLoading, isError }
- Refresh interval: 12 seconds (one block)
- Do not return raw contract tuple — map to the LendingPoolState interface
```

### 5.2 `hooks/useLoan.ts`

Reads `OnLoanHook.getLoan(borrower)` and `OnLoanHook.getHealthFactor(borrower)`.

```
- Input: borrower address
- Returns: { loan: Loan | undefined, healthFactor: bigint | undefined, isLoading, isError }
- Only fetch if borrower is a valid non-zero address
- Refresh interval: 12 seconds
```

### 5.3 `hooks/useBorrow.ts`

Wraps `useWriteContract` for the swap-to-borrow flow.

```
- Input: BorrowFormState + poolKey
- Encodes hookData via sdk.encodeBorrowPayload()
- Exposes: { borrow, isPending, isSuccess, error }
- On success: invalidate useLoan and usePoolState queries via queryClient
```

### 5.4 `hooks/useRepay.ts`

Wraps `useWriteContract` for the donate-to-repay flow.

```
- Input: borrower address, repayAmount
- Encodes hookData via sdk.encodeRepayPayload()
- Exposes: { repay, isPending, isSuccess, error }
- On success: invalidate useLoan and usePoolState queries via queryClient
```

### 5.5 `hooks/useDeposit.ts`

Wraps `useWriteContract` for adding liquidity (LP deposit).

```
- Exposes: { deposit, isPending, isSuccess, error }
- On success: invalidate usePoolState
```

### 5.6 `hooks/useWithdraw.ts`

Wraps `useWriteContract` for removing liquidity.

```
- Check canWithdraw via useReadContract before exposing withdraw action
- Surface a clear error if cooldown has not elapsed
- On success: invalidate usePoolState
```

### 5.7 `hooks/useLiquidations.ts`

```
- Reads getActiveBorrowers() from LoanManager
- Batch reads getHealthFactor() for each borrower via multicall
- Returns: { liquidatable: address[], atRisk: address[], isLoading }
- Refresh interval: 30 seconds
```

### Hook rules

- Every hook must return `isLoading` and `isError` — never leave these out.
- Never call a hook conditionally inside a component. Move the condition inside the hook.
- All write hooks must catch revert errors and surface a clean `error` message — not a raw viem error object.
- Always specify `abi` from `@/lib/abis.ts`, `address` from `CONTRACTS`, and `chainId` from the active chain.

---

## 6. Step 5 — Global State (`frontend/src/stores/`)

### 6.1 `stores/useAppStore.ts`

```ts
// Manages: connected wallet, active chain, active poolId
interface AppState {
    poolId: `0x${string}` | null;
    setPoolId: (id: `0x${string}`) => void;
}
```

Use `zustand`. Keep stores minimal — wagmi already manages wallet state. Do not duplicate wallet address in the store.

---

## 7. Step 6 — UI Components

### 7.1 Design System Rules

- Use Tailwind CSS v4 utility classes. No inline styles.
- Dark mode first. Background base: `#0a0a0f`. Surface: `#111118`. Border: `#1e1e2e`.
- Accent color: `#7c3aed` (violet-600). Danger: `#ef4444`. Warning: `#f59e0b`. Safe: `#22c55e`.
- Use Radix UI primitives already installed for Dialog, Dropdown, Toast, Tooltip.
- All interactive elements must have accessible `aria-label` attributes.
- Every number displaying a token amount must show the token symbol.
- Loading states must show skeleton placeholders — never blank space.

### 7.2 Component Checklist

**`components/ui/`** — base primitives:

- `Button.tsx` — variants: primary, secondary, danger, ghost. States: default, loading, disabled.
- `Card.tsx` — glassmorphic surface container.
- `Badge.tsx` — status labels with color variants.
- `Skeleton.tsx` — loading placeholder.
- `Spinner.tsx` — loading indicator.
- `StatRow.tsx` — label/value pair for data displays.
- `ErrorMessage.tsx` — formatted error display.

**`components/layout/`**:

- `Shell.tsx` — outer page wrapper with sidebar + content area.
- `Navbar.tsx` — logo, nav links, `ConnectButton` (wagmi `useConnect`/`useDisconnect`).
- `Sidebar.tsx` — navigation links to all 5 routes.

**`components/health/`**:

- `HealthFactorGauge.tsx`
    - Renders a radial arc gauge scaled 0 to 2.0
    - Color transitions: red (`< 1.0`) → orange (`1.0–1.2`) → yellow (`1.2–1.5`) → green (`> 1.5`)
    - Shows numeric health factor using `formatHealthFactor()` from sdk
    - Shows status label using `getHealthStatus()` from sdk
    - Shows liquidation price if derivable
- `LiquidationWarning.tsx`
    - Displayed as a dismissible alert banner when health status is `'warning'` or `'danger'`
    - Must not be displayed when status is `'safe'`

**`components/lending/`**:

- `LendingPoolCard.tsx`
    - Shows: Total Deposited, Total Borrowed, Utilization Rate, Current APR
    - Sources from `usePoolState`
    - `UtilizationBar` sub-component — visual bar showing utilization %

**`components/borrow/`**:

- `BorrowForm.tsx`
    - Fields: Collateral Token (dropdown), Collateral Amount (input), Borrow Amount (input), Duration (slider in days)
    - Live preview: estimated health factor, estimated interest cost
    - Validate: collateral amount > 0, borrow amount > 0, duration within pool config bounds
    - Disable submit if pool has insufficient liquidity
    - Uses `useBorrow` hook
- `LoanCard.tsx`
    - Shows active loan details: Borrowed amount, Collateral, Health Factor gauge, Accrued Interest, Time remaining
    - Sources from `useLoan`
    - Contains `RepayButton` that opens a repay flow Dialog

**`components/liquidations/`**:

- `LiquidationTable.tsx`
    - Lists all at-risk and liquidatable borrowers
    - Columns: Address, Health Factor, Collateral Value, Debt Value, Status badge
    - Each row has a Liquidate button that calls `OnLoanHook.liquidateLoan(borrower)`
    - Sources from `useLiquidations`

---

## 8. Step 7 — Page Implementation

Each page maps to a route in `Router.tsx`. Replace stubs with real implementations.

### 8.1 Dashboard (`/`)

Content:

- Wallet connection prompt if not connected
- Active loan summary card (`LoanCard`) for the connected address
- `LендingPoolCard` for the active pool
- `LiquidationWarning` if health factor is in warning zone
- Quick-action buttons: Go to Borrow, Go to Lend

### 8.2 Markets (`/markets`)

Content:

- One `LendingPoolCard` per registered pool
- Pool utilization, TVL, APR, available liquidity
- Link/button to jump to Lend or Borrow within that pool

### 8.3 Lend (`/lend`)

Content:

- Pool selector (if multiple pools)
- Deposit form: amount input, token display, share preview
- Existing LP position: your shares, estimated value, withdraw eligibility
- Withdraw button — only active if `canWithdraw` returns true
- Uses `useDeposit` and `useWithdraw`

### 8.4 Borrow (`/borrow`)

Content:

- `BorrowForm` component
- If loan already exists: show `LoanCard` + `HealthFactorGauge` instead of the form
- Repay flow accessible from `LoanCard`

### 8.5 Liquidations (`/liquidations`)

Content:

- `LiquidationTable` showing all at-risk borrowers
- Summary bar: total loans monitored, at-risk count, liquidatable count
- Refresh button / auto-refresh indicator

---

## 9. Step 8 — Deployment Scripts

### 9.1 `frontend/src/lib/utils.ts`

```ts
import { formatUnits, parseUnits, type Address } from "viem";

export function shortenAddress(address: Address): string {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function formatTokenAmount(raw: bigint, decimals: number, symbol: string): string {
    return `${parseFloat(formatUnits(raw, decimals)).toLocaleString()} ${symbol}`;
}

export function formatUSD(raw: bigint, decimals = 8): string {
    const val = parseFloat(formatUnits(raw, decimals));
    return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(val);
}

export function daysToSeconds(days: number): bigint {
    return BigInt(days) * 86_400n;
}
```

### 9.2 Environment variables

Create `frontend/.env.example`:

```
VITE_WALLET_CONNECT_PROJECT_ID=
VITE_CHAIN_ID=1301
```

Never commit `.env` files. `.env.example` is required.

---

## 10. Step 9 — End-to-End Testing Checklist

Before marking any feature complete, manually verify every item in this checklist:

### Wallet

- [ ] MetaMask (or injected wallet) connects on Unichain Sepolia
- [ ] Disconnecting wallet clears all user-specific UI
- [ ] Wrong network shows a clear "Switch to Unichain Sepolia" prompt

### Lend Flow

- [ ] Deposit form validates minimum amount
- [ ] LP position is shown after deposit (shares > 0)
- [ ] Withdrawal blocked with correct message if cooldown not elapsed
- [ ] Withdrawal succeeds after cooldown

### Borrow Flow

- [ ] BorrowForm validation blocks zero amounts
- [ ] BorrowForm blocks if borrow exceeds available liquidity
- [ ] Health factor preview updates live as user inputs change
- [ ] Borrow transaction submits with correct `hookData` encoding
- [ ] Loan card appears after successful borrow
- [ ] Repay transaction submits correctly and closes loan

### Health Factor

- [ ] Gauge displays correct color for all four states
- [ ] Warning banner appears at warning and danger zones
- [ ] Warning banner is absent at safe zone

### Liquidations

- [ ] Table populates with at-risk borrowers
- [ ] Liquidate button triggers `liquidateLoan` call
- [ ] Table updates after liquidation

### Error Handling

- [ ] User rejection of MetaMask shows a graceful toast — not a crash
- [ ] Contract revert surfaces descriptive error message
- [ ] Network request failure shows retry option

---

## 11. Step 10 — Deployment & Environment Config

### Deploy frontend to Vercel or equivalent:

```bash
cd frontend
pnpm build
# Upload dist/ directory
```

- Set `VITE_WALLET_CONNECT_PROJECT_ID` in the deployment environment.
- Validate the production build connects to Unichain Sepolia by default.
- Never ship `.env` files to a public repository.

### Update README with:

- Frontend setup instructions
- Contract addresses table
- Screenshots of dashboard, borrow flow, health factor gauge, liquidations table

---

## 12. Component Completion Criteria

A component is complete when:

1. It renders without TypeScript errors (`tsc --noEmit` passes)
2. It handles `isLoading` with a skeleton
3. It handles `isError` with `ErrorMessage`
4. It handles the empty/zero state explicitly (no loan, no liquidity, etc.)
5. It is accessible (keyboard navigable, ARIA labels present)
6. It is responsive at 375px, 768px, and 1280px viewport widths

---

## 13. Commit Conventions

All commits must follow this pattern:

```
<scope>: <past-active-tense description>

Example:
sdk: added borrow and repay payload encoders
hooks: wired useLoan with health factor read
borrow-form: added collateral selector and live health preview
liquidations: rendered at-risk borrower table with liquidate action
```

Scopes: `sdk`, `hooks`, `stores`, `ui`, `layout`, `borrow`, `lend`, `liquidations`, `markets`, `dashboard`, `deploy`, `docs`

---

## 14. Integration Points with Person A and Person B

### From Person A (do not modify):

- All contracts in `contracts/src/` — treat as read-only
- All interfaces in `contracts/src/interfaces/` — source of truth for ABIs
- All types in `contracts/src/types/` — source of truth for on-chain data shapes

### Coordination required:

- If `deployments/addresses.json` is updated after redeployment, update `constants.ts` immediately
- If a new contract event is emitted that C needs to listen to, request the event signature from A
- Notify Person B of any health factor threshold changes displayed in the UI — it must match B's liquidation bot thresholds

### From Person B (for display only):

- B's `ReactiveMonitor` fires liquidation events on-chain
- C subscribes to `LiquidationEngine` events via `useWatchContractEvent` to show real-time liquidation status
- C does not implement the liquidation logic — only the liquidation trigger button and status display

---

## 15. Prohibited Patterns

- Do not use `useEffect` to fetch contract data — use `useReadContract` and `useQuery`.
- Do not store bigints in `useState` as strings then parse on submit — use bigint state throughout.
- Do not hardcode chain IDs as raw numbers in component code — use `chain.id` from wagmi.
- Do not display raw wei values to users — always format with `formatUnits`.
- Do not use `window.ethereum` directly — always use wagmi connectors.
- Do not write new contract interaction logic outside of `hooks/` — components call hooks, never contracts directly.
- Do not use `as any` as a shortcut for type casting — model the type correctly.
- Do not skip loading states — a component that shows stale or undefined data is a bug.
