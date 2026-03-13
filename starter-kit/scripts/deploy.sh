#!/bin/bash
# Deploy SimpleAgentNFT to any EVM chain
# Usage: ./deploy.sh
#
# Required env vars:
#   RPC_URL      - Chain RPC endpoint
#   PRIVATE_KEY  - Deployer private key
#   NAME         - Token name (default: "AI Agent")
#   SYMBOL       - Token symbol (default: "AGENT")

set -e

NAME="${NAME:-AI Agent}"
SYMBOL="${SYMBOL:-AGENT}"

if [ -z "$RPC_URL" ] || [ -z "$PRIVATE_KEY" ]; then
  echo "Error: Set RPC_URL and PRIVATE_KEY environment variables"
  echo ""
  echo "Example:"
  echo "  export RPC_URL=https://rpc.pentagon.games"
  echo "  export PRIVATE_KEY=0x..."
  echo "  ./deploy.sh"
  exit 1
fi

echo "Deploying SimpleAgentNFT..."
echo "  Name:   $NAME"
echo "  Symbol: $SYMBOL"
echo "  RPC:    $RPC_URL"
echo ""

forge create ../contracts/SimpleAgentNFT.sol:SimpleAgentNFT \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --constructor-args "$NAME" "$SYMBOL"

echo ""
echo "Done! Submit your deployment to the ERC-8170 registry:"
echo "https://github.com/blockchainsuperheroes/ai-core/issues/new?title=Registry+Submission&labels=registry&template=registry-submission.md"
