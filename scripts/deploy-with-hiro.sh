#!/bin/bash

# Conxian Deployment Script with Hiro API Integration
# Uses Hiro API key for enhanced testing and deployment capabilities

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if Hiro API key is set
if [ -z "$HIRO_API_KEY" ]; then
    echo "❌ Error: HIRO_API_KEY not set in .env file"
    exit 1
fi

# Configuration
NETWORK=${NETWORK:-testnet}
STACKS_API_BASE=${STACKS_API_BASE:-https://api.testnet.hiro.so}

echo "🚀 Conxian Deployment with Hiro API Integration"
echo "📡 Network: $NETWORK"
echo "🔗 API Base: $STACKS_API_BASE"
echo "🔑 API Key: ${HIRO_API_KEY:0:8}..."

# Function to check network status
check_network_status() {
    echo "🔍 Checking network status..."
    
    response=$(curl -s -H "X-API-Key: $HIRO_API_KEY" \
        "$STACKS_API_BASE/extended/v1/status" || echo "error")
    
    if [ "$response" = "error" ]; then
        echo "❌ Failed to connect to Stacks API"
        exit 1
    fi
    
    echo "✅ Network connection successful"
}

# Function to get account info
get_account_info() {
    local address=$1
    if [ -z "$address" ]; then
        echo "⚠️  No deployer address provided"
        return
    fi
    
    echo "👤 Getting account info for: $address"
    
    curl -s -H "X-API-Key: $HIRO_API_KEY" \
        "$STACKS_API_BASE/extended/v1/address/$address/balances" | \
        jq '.stx.balance, .stx.locked' 2>/dev/null || echo "Could not fetch balance"
}

# Function to deploy contracts
deploy_contracts() {
    echo "📦 Starting contract deployment..."
    
    # Check if clarinet is available
    if ! command -v clarinet &> /dev/null; then
        echo "❌ Clarinet not found. Please install Clarinet first."
        exit 1
    fi
    
    # Run clarinet check first
    echo "🔍 Running contract validation..."
    if ! clarinet check; then
        echo "❌ Contract validation failed"
        exit 1
    fi
    
    echo "✅ Contract validation passed"
    
    # Deploy to testnet if configured
    if [ "$NETWORK" = "testnet" ] && [ -n "$DEPLOYER_PRIVKEY" ]; then
        echo "🚀 Deploying to testnet..."
        clarinet deployments apply --deployment-plan deployments/default.simnet-plan.yaml
    else
        echo "⚠️  Testnet deployment skipped (no private key or not testnet)"
    fi
}

# Function to test mathematical contracts
test_math_contracts() {
    echo "🧮 Testing mathematical contracts..."
    
    # Test math-lib-advanced
    echo "Testing sqrt function..."
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $HIRO_API_KEY" \
        -d '{
            "contractAddress": "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6",
            "contractName": "math-lib-advanced",
            "functionName": "sqrt-fixed",
            "functionArgs": ["u4000000000000000000"],
            "sender": "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"
        }' \
        "$STACKS_API_BASE/v2/contracts/call-read/ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6/math-lib-advanced/sqrt-fixed" \
        2>/dev/null | jq '.result' || echo "Math contract not deployed yet"
}

# Function to monitor deployment
monitor_deployment() {
    echo "📊 Monitoring deployment status..."
    
    if [ -n "$DEPLOYER_ADDRESS" ]; then
        echo "📈 Account balance:"
        get_account_info "$DEPLOYER_ADDRESS"
        
        echo "📋 Recent transactions:"
        curl -s -H "X-API-Key: $HIRO_API_KEY" \
            "$STACKS_API_BASE/extended/v1/address/$DEPLOYER_ADDRESS/transactions?limit=5" | \
            jq '.results[].tx_id' 2>/dev/null || echo "Could not fetch transactions"
    fi
}

# Main execution
main() {
    echo "🎯 Starting Conxian deployment process..."
    
    check_network_status
    
    if [ -n "$DEPLOYER_ADDRESS" ]; then
        get_account_info "$DEPLOYER_ADDRESS"
    fi
    
    deploy_contracts
    test_math_contracts
    monitor_deployment
    
    echo "✅ Deployment process completed!"
    echo "📚 Next steps:"
    echo "   1. Verify contracts on Stacks Explorer"
    echo "   2. Run integration tests"
    echo "   3. Initialize pools and liquidity"
    echo "   4. Monitor system health"
}

# Handle command line arguments
case "${1:-deploy}" in
    "check")
        check_network_status
        ;;
    "balance")
        get_account_info "$DEPLOYER_ADDRESS"
        ;;
    "test")
        test_math_contracts
        ;;
    "monitor")
        monitor_deployment
        ;;
    "deploy"|*)
        main
        ;;
esac