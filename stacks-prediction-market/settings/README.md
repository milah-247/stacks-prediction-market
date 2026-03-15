# Network Settings

| File | Purpose |
|------|---------|
| Simnet.toml | Local simulation network for unit tests |
| Devnet.toml | Local devnet with Docker (Stacks + Bitcoin nodes) |
| Testnet.toml | Public Stacks testnet deployment |

## Usage
- Run `clarinet check` to validate contracts
- Run `clarinet devnet start` to launch local devnet
- Run `bash scripts/deploy.sh testnet` to deploy to testnet
