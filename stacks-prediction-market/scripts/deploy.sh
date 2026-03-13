#!/usr/bin/env bash
set -euo pipefail

NETWORK=${1:-testnet}
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC}   $1"; }
err()  { echo -e "${RED}[ERR]${NC}  $1"; exit 1; }

echo ""; echo "=== Stacks PM Deploy: $NETWORK ==="; echo ""

command -v clarinet >/dev/null 2>&1 || err "Clarinet not found"
info "Running clarinet check..."
clarinet check && ok "Check passed"
info "Running tests..."
clarinet test && ok "Tests passed"

case $NETWORK in
  mainnet)  NETWORK_FLAG="--mainnet" ;;
  testnet)  NETWORK_FLAG="--testnet" ;;
  devnet)   NETWORK_FLAG="--devnet"  ;;
  *) err "Unknown network: $NETWORK" ;;
esac

for CONTRACT in market-token oracle prediction-market; do
  info "Deploying $CONTRACT..."
  clarinet deploy --manifest Clarinet.toml $NETWORK_FLAG --contract "$CONTRACT" \
    && ok "Deployed: $CONTRACT" \
    || err "Failed: $CONTRACT"
done

echo ""; echo "=== Deployment complete ==="; echo ""
echo "Next: update NEXT_PUBLIC_CONTRACT_ADDRESS in frontend/.env.local"
