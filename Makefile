.PHONY: build test test-ci coverage snapshot gas fmt lint \
       deploy-testnet deploy-mainnet deploy-tokens deploy-rsc deploy-risk \
       deploy-all-testnet clean install \
       frontend-dev frontend-build slither

# ── Load .env if present ──
-include .env

# ══════════════════════════════════════════════════════════
#  Build & Test
# ══════════════════════════════════════════════════════════

build:
	forge build

test:
	forge test -vvv

test-ci:
	FOUNDRY_PROFILE=ci forge test

test-b:
	forge test --match-contract "LiquidationRSCTest|CrossChainWatcherTest|TWAPOracleTest|RiskEngineTest|MarketCrashSimulation" -vvv

coverage:
	forge coverage --report lcov

snapshot:
	forge snapshot

gas:
	forge test --gas-report

# ══════════════════════════════════════════════════════════
#  Code Quality
# ══════════════════════════════════════════════════════════

fmt:
	forge fmt
	cd frontend && pnpm format

lint:
	solhint 'contracts/src/**/*.sol'
	cd frontend && pnpm lint

slither:
	slither contracts/src/

# ══════════════════════════════════════════════════════════
#  Deployment — Testnet (Unichain Sepolia + Reactive Kopli)
# ══════════════════════════════════════════════════════════

# Step 1: Deploy mock tokens (skip if testnet tokens exist)
deploy-tokens:
	forge script script/deploy/DeployTestnetTokens.s.sol \
		--rpc-url $(UNICHAIN_TESTNET_RPC_URL) \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast
	@echo "\n>>> Update .env with WETH_ADDRESS and WBTC_ADDRESS from output above"

# Step 2: Deploy core protocol (Developer A)
deploy-testnet:
	forge script script/deploy/DeployOnLoan.s.sol \
		--rpc-url $(UNICHAIN_TESTNET_RPC_URL) \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast --verify
	@echo "\n>>> Update .env with addresses from deployments/addresses.json"

# Step 3: Deploy RiskEngine on Unichain (Developer B)
deploy-risk:
	forge script script/deploy/DeployRiskEngine.s.sol \
		--rpc-url $(UNICHAIN_TESTNET_RPC_URL) \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast

# Step 4: Deploy RSCs on Reactive Network (Developer B)
deploy-rsc:
	forge script script/deploy/DeployReactiveMonitor.s.sol \
		--rpc-url $(REACTIVE_RPC_URL) \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast

# Step 5: Configure RSC subscriptions (Developer B)
configure-rsc:
	forge script script/configure/SubscribeRSC.s.sol \
		--rpc-url $(REACTIVE_RPC_URL) \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast

# Full testnet deployment pipeline
deploy-all-testnet: deploy-tokens
	@echo "\n========================================"
	@echo "Step 1 complete: tokens deployed."
	@echo "Update .env with token addresses, then run:"
	@echo "  make deploy-testnet"
	@echo "  make deploy-risk"
	@echo "  make deploy-rsc"
	@echo "========================================"

# ══════════════════════════════════════════════════════════
#  Deployment — Mainnet
# ══════════════════════════════════════════════════════════

deploy-mainnet:
	forge script script/deploy/DeployOnLoan.s.sol \
		--rpc-url $(UNICHAIN_RPC_URL) \
		--private-key $(DEPLOYER_PRIVATE_KEY) \
		--broadcast --verify

# ══════════════════════════════════════════════════════════
#  Frontend
# ══════════════════════════════════════════════════════════

frontend-dev:
	cd frontend && pnpm dev

frontend-build:
	cd frontend && pnpm build

# ══════════════════════════════════════════════════════════
#  Utilities
# ══════════════════════════════════════════════════════════

clean:
	forge clean
	rm -rf frontend/dist

install:
	forge install
	cd frontend && pnpm install

# Export all deployed addresses into a single JSON for frontend consumption
export-addresses:
	@echo "Merging deployment JSONs..."
	@jq -s '.[0] * .[1] * .[2]' \
		deployments/addresses.json \
		deployments/risk-engine.json \
		deployments/reactive-addresses.json \
		> deployments/all-addresses.json 2>/dev/null || echo "Some deployment files missing"
	@echo "Exported to deployments/all-addresses.json"
