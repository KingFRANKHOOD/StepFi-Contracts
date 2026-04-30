#!/bin/bash
set -e

echo "=================================================="
echo "  StepFi Contracts — Testnet Deployment Script"
echo "=================================================="

# Check required tools
command -v stellar >/dev/null 2>&1 || { echo "Error: stellar CLI not found. Install with: cargo install --locked stellar-cli --features opt"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "Error: cargo not found. Install Rust first."; exit 1; }

# Load env vars if .env exists
if [ -f .env ]; then
  export $(cat .env | grep -v '#' | xargs)
fi

# Required: DEPLOYER_SECRET must be set
if [ -z "$DEPLOYER_SECRET" ]; then
  echo "Error: DEPLOYER_SECRET is not set."
  echo "Add it to .env or export it: export DEPLOYER_SECRET=your_secret_key"
  exit 1
fi

NETWORK="testnet"
echo ""
echo "Network: $NETWORK"
echo ""

# Build all contracts
echo "Step 1 — Building all contracts..."
cargo build --target wasm32-unknown-unknown --release 2>&1 | tail -5
echo "Build complete."
echo ""

WASM_DIR="target/wasm32-unknown-unknown/release"

# Deploy each contract
echo "Step 2 — Deploying contracts..."

echo "Deploying reputation-contract..."
REPUTATION_ID=$(stellar contract deploy \
  --wasm $WASM_DIR/reputation_contract.wasm \
  --network $NETWORK \
  --source-account $DEPLOYER_SECRET \
  2>/dev/null)
echo "  REPUTATION_CONTRACT_ID=$REPUTATION_ID"

echo "Deploying parameters-contract..."
PARAMETERS_ID=$(stellar contract deploy \
  --wasm $WASM_DIR/parameters_contract.wasm \
  --network $NETWORK \
  --source-account $DEPLOYER_SECRET \
  2>/dev/null)
echo "  PARAMETERS_CONTRACT_ID=$PARAMETERS_ID"

echo "Deploying vendor-registry-contract..."
VENDOR_REGISTRY_ID=$(stellar contract deploy \
  --wasm $WASM_DIR/vendor_registry_contract.wasm \
  --network $NETWORK \
  --source-account $DEPLOYER_SECRET \
  2>/dev/null)
echo "  VENDOR_REGISTRY_CONTRACT_ID=$VENDOR_REGISTRY_ID"

echo "Deploying liquidity-pool-contract..."
LIQUIDITY_POOL_ID=$(stellar contract deploy \
  --wasm $WASM_DIR/liquidity_pool_contract.wasm \
  --network $NETWORK \
  --source-account $DEPLOYER_SECRET \
  2>/dev/null)
echo "  LIQUIDITY_POOL_CONTRACT_ID=$LIQUIDITY_POOL_ID"

echo "Deploying creditline-contract..."
CREDITLINE_ID=$(stellar contract deploy \
  --wasm $WASM_DIR/creditline_contract.wasm \
  --network $NETWORK \
  --source-account $DEPLOYER_SECRET \
  2>/dev/null)
echo "  CREDIT_LINE_CONTRACT_ID=$CREDITLINE_ID"

echo ""
echo "Step 3 — All contracts deployed. Add these to your StepFi-API .env:"
echo ""
echo "REPUTATION_CONTRACT_ID=$REPUTATION_ID"
echo "PARAMETERS_CONTRACT_ID=$PARAMETERS_ID"
echo "MERCHANT_REGISTRY_CONTRACT_ID=$VENDOR_REGISTRY_ID"
echo "LIQUIDITY_POOL_CONTRACT_ID=$LIQUIDITY_POOL_ID"
echo "CREDIT_LINE_CONTRACT_ID=$CREDITLINE_ID"
echo ""

# Save to .env.contracts file
cat > .env.contracts << ENVEOF
REPUTATION_CONTRACT_ID=$REPUTATION_ID
PARAMETERS_CONTRACT_ID=$PARAMETERS_ID
MERCHANT_REGISTRY_CONTRACT_ID=$VENDOR_REGISTRY_ID
LIQUIDITY_POOL_CONTRACT_ID=$LIQUIDITY_POOL_ID
CREDIT_LINE_CONTRACT_ID=$CREDITLINE_ID
ENVEOF

echo "Contract addresses saved to .env.contracts"
echo ""
echo "=================================================="
echo "  Deployment complete!"
echo "=================================================="
