[![Tests](https://img.shields.io/badge/Tests-Comprehensive-green)](https://github.com/Anya-org/Conxian)
[![Contracts](https://img.shields.io/badge/Contracts-65%2B-blue)](https://github.com/Anya-org/Conxian)
[![Status](https://img.shields.io/badge/Status-Core%20System%20Implemented-blue)](https://github.com/Anya-org/Conxian)
[![Network](https://img.shields.io/badge/Network-Testnet%2FMainnet-9cf)](https://docs.hiro.so/)

## Documentation

All documentation for the Conxian Protocol can be found in the [`documentation`](./documentation) directory.

## Quick Start

- Install dependencies: `npm install`
- Run tests (Vitest + Clarinet SDK): `npm test`
- Check manifests (if Clarinet CLI installed): `npx clarinet check`

## Single Source of Truth

- Canonical manifest: `Clarinet.toml` at the repository root
- Canonical contracts: `contracts/`
- Deployment plans: `deployments/`
- Tests: `tests/` using the root manifest by default
- The `stacks/` directory is for test harnesses only and must reference root contracts (no production logic duplicates)

See `CONTRIBUTING.md` for contribution guidelines and policy checks.
