# OnLoan

<!-- ![OnLoan Logo](docs/assets/logo.png) -->

[![CI](https://github.com/Akanimoh12/OnLoan-Hook/actions/workflows/ci.yml/badge.svg)](https://github.com/Akanimoh12/OnLoan-Hook/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.26-363636.svg)](https://soliditylang.org/)

**OnLoan** is a decentralized lending protocol built as a **Uniswap v4 Hook** on **Unichain**, with automated liquidation powered by **Reactive Network**. Lenders earn dual yield from swap fees and borrower interest, while Reactive Smart Contracts ensure real-time health factor monitoring and trustless liquidation — no keepers required.

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Akanimoh12/OnLoan-Hook.git
cd OnLoan-Hook

# Install all dependencies
make install

# Build contracts
make build

# Run tests
make test

# Start frontend dev server
make frontend-dev
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Smart Contracts | Solidity ^0.8.26, Foundry |
| Hook Framework | Uniswap v4 |
| Chain | Unichain |
| Automation | Reactive Network |
| Frontend | React 19, TypeScript, Vite, Tailwind CSS |
| Web3 | wagmi, viem |
| State | Zustand, TanStack Query |

## Documentation

- **[OnLoan Architecture](OnLoan.md)** — Full protocol design and architecture document
- **[Project Structure](PROJECT_STRUCTURE.md)** — Complete directory layout and file reference
- **[Getting Started](docs/guides/GETTING_STARTED.md)** — Setup guide for new developers
- **[Testing Guide](docs/guides/TESTING_GUIDE.md)** — How to write and run tests
- **[Deployment Guide](docs/guides/DEPLOYMENT_GUIDE.md)** — Deploy to testnet and mainnet

## Project Structure

```
OnLoan-Hook/
├── contracts/src/     # Solidity smart contracts
├── test/              # Foundry test suites
├── script/            # Deployment & configuration scripts
├── frontend/          # React + TypeScript frontend
├── docs/              # Documentation
└── .github/           # CI/CD workflows
```

See [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) for the complete breakdown.

## Contributing

We welcome contributions! Please read our [Contributing Guide](docs/guides/CONTRIBUTING.md) before submitting a PR.

## License

This project is licensed under the [MIT License](LICENSE).
