# OnLoan — Smart Contracts

Solidity smart contracts for the OnLoan lending protocol, built as a Uniswap v4 Hook on Unichain with Reactive Network automation.

## Architecture

```
contracts/src/
├── hook/           # OnLoanHook — Uniswap v4 hook (beforeSwap, afterSwap, afterDonate)
├── lending/        # LendingPool, LoanManager — deposit/withdraw/borrow/repay logic
├── liquidation/    # LiquidationEngine — health-factor-based liquidation
├── oracle/         # PriceOracle, TWAPOracle — on-chain price feeds
├── reactive/       # LiquidationRSC, CrossChainWatcher — Reactive Network RSCs
├── risk/           # RiskEngine — batch risk assessment & stress testing
├── tokens/         # ReceiptToken, CollateralManager — ERC20 shares & collateral custody
├── libraries/      # FixedPointMath, PoolKeyHelper — shared utilities
├── types/          # DataTypes.sol — struct definitions
└── interfaces/     # IOnLoanHook, ILendingPool, etc.
```

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil)
- Solidity ^0.8.26

## Setup

```bash
# From the repo root
make install        # installs forge dependencies (v4-core, v4-periphery, openzeppelin, etc.)
make build          # compile all contracts
```

## Running Tests

```bash
# Run all tests with verbose output
make test

# Run with CI profile (higher fuzz runs)
make test-ci

# Run specific module tests
forge test --match-contract LendingPoolTest -vvv
forge test --match-contract OnLoanHookTest -vvv
forge test --match-contract LiquidationEngineTest -vvv

# Run Reactive Network tests
make test-b

# Gas report
make gas

# Coverage
make coverage
```

## Deployment

Requires a `.env` file in the repo root:

```env
DEPLOYER_PRIVATE_KEY=0x...
UNICHAIN_TESTNET_RPC_URL=https://sepolia.unichain.org
REACTIVE_RPC_URL=https://kopli-rpc.reactive.network
```

Deploy step by step:

```bash
make deploy-tokens      # 1. Deploy testnet ERC20s (USDC, WETH, WBTC)
make deploy-testnet     # 2. Deploy core protocol (Hook, LendingPool, LoanManager, etc.)
make deploy-risk        # 3. Deploy RiskEngine
make deploy-rsc         # 4. Deploy Reactive Smart Contracts on Reactive Kopli
make configure-rsc      # 5. Subscribe RSCs to on-chain events
```

## Deployed Contracts (Unichain Sepolia — Chain ID 1301)

| Contract | Address |
|----------|---------|
| OnLoanHook | [`0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0`](https://sepolia.uniscan.xyz/address/0x3CcC052E574E3a832FBB0CF426A449b885B1BFF0) |
| LendingPool | [`0xD3ebBdbEB12C656B9743b94384999E0ff7010f36`](https://sepolia.uniscan.xyz/address/0xD3ebBdbEB12C656B9743b94384999E0ff7010f36) |
| LoanManager | [`0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46`](https://sepolia.uniscan.xyz/address/0xa9fD16FcD65304f2f00EfCe0c3517261e8504B46) |
| CollateralManager | [`0xa97C9C8dD22db815a4AB3E3279562FD379F925c6`](https://sepolia.uniscan.xyz/address/0xa97C9C8dD22db815a4AB3E3279562FD379F925c6) |
| PriceOracle | [`0x1106661FB7104CFbd35E8477796D8CD9fB3806f2`](https://sepolia.uniscan.xyz/address/0x1106661FB7104CFbd35E8477796D8CD9fB3806f2) |
| LiquidationEngine | [`0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6`](https://sepolia.uniscan.xyz/address/0x9E2f28b4f68F01b4B56BEFc6047018362EBD91F6) |
| InterestRateModel | [`0xF2268d8133687e40AC174bCcA150677c42D74233`](https://sepolia.uniscan.xyz/address/0xF2268d8133687e40AC174bCcA150677c42D74233) |
| RiskEngine | [`0x1bdFc336373903E24BD46f8d22b14972f0fAEF83`](https://sepolia.uniscan.xyz/address/0x1bdFc336373903E24BD46f8d22b14972f0fAEF83) |
| ReceiptToken | [`0xEAE3b6033d744b8E0e817269df92004F3069bfB1`](https://sepolia.uniscan.xyz/address/0xEAE3b6033d744b8E0e817269df92004F3069bfB1) |
| PoolManager (Uniswap) | [`0x000000000004444c5dc75cB358380D2e3dE08A90`](https://sepolia.uniscan.xyz/address/0x000000000004444c5dc75cB358380D2e3dE08A90) |

**Reactive Network (Kopli Testnet):**

| Contract | Address |
|----------|---------|
| LiquidationRSC | `0x6F491FaBdEc72fD14e9E014f50B2ffF61C508bf1` |
| CrossChainWatcher | `0x012D911Dbc11232472A6AAF6b51E29A0C5929cC5` |

**Testnet Tokens:**

| Token | Address |
|-------|---------|
| USDC | [`0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6`](https://sepolia.uniscan.xyz/address/0x7F3974B5503c99A184122a6a4C1CF884F5c64Fb6) |
| WETH | [`0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D`](https://sepolia.uniscan.xyz/address/0x8B1fbcB9268BB5Ad85c6026C848A5d8Bf7D7888D) |
| WBTC | [`0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8`](https://sepolia.uniscan.xyz/address/0x029dF2c1C69CEFe9Ce762B6a8d3D04b309Fc07D8) |

## Key Design Decisions

- **Hook-first architecture** — Borrow via `beforeSwap` hookData encoding, repay via `afterDonate`
- **Isolated lending pools** — Each pool ID tracks its own deposits, borrows, shares, and interest
- **Kinked interest rate model** — Rates increase sharply above the kink utilization to incentivize repayment
- **Reactive liquidations** — No keeper bots; Reactive Smart Contracts autonomously monitor and trigger liquidations on-chain
