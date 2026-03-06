.PHONY: build test test-ci coverage snapshot gas fmt lint \
       deploy-testnet deploy-mainnet clean install \
       frontend-dev frontend-build slither

build:
	forge build

test:
	forge test -vvv

test-ci:
	FOUNDRY_PROFILE=ci forge test

coverage:
	forge coverage --report lcov

snapshot:
	forge snapshot

gas:
	forge test --gas-report

fmt:
	forge fmt
	cd frontend && pnpm format

lint:
	solhint 'contracts/src/**/*.sol'
	cd frontend && pnpm lint

deploy-testnet:
	forge script script/deploy/DeployOnLoan.s.sol \
		--rpc-url unichain_testnet --broadcast --verify

deploy-mainnet:
	forge script script/deploy/DeployOnLoan.s.sol \
		--rpc-url unichain --broadcast --verify

clean:
	forge clean
	rm -rf frontend/dist

install:
	forge install
	cd frontend && pnpm install

frontend-dev:
	cd frontend && pnpm dev

frontend-build:
	cd frontend && pnpm build

slither:
	slither contracts/src/
