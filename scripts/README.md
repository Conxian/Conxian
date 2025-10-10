# Conxian Scripts

Deployment, testing, and utility scripts for the Conxian DeFi platform.

## Script Categories

### Deployment Scripts

- `deploy-testnet.sh` - Deploy all contracts to Stacks testnet
- `deploy-mainnet.sh` - Production deployment with multi-sig controls
- `sdk_deploy_contracts.ts` - Automated SDK-based contract deployment
- `post_deploy_verify.ts` - Post-deployment verification and testing

### Testing & Verification

- `manual-testing.sh` - Interactive manual testing suite
- `run-all-tests.sh` - Comprehensive test execution
- `verify.sh` - Contract compilation and verification
- `check_dependencies.py` - Dependency validation

### Maintenance & Monitoring

- `monitor-health.sh` - Protocol health monitoring
- `keeper_watchdog.py` - Automated parameter adjustment watchdog
- `python_update_autonomics.py` - Python-based autonomic controller
- `sync_issues.py` - GitHub issue synchronization

### Development Tools

- `broadcast-tx.sh` - Transaction broadcasting utility
- `call-read.sh` - Read-only contract call utility
- `get-abi.sh` - Contract ABI extraction
- `ping.sh` - Network connectivity testing

### Economic & Analytics

- `economic_simulation.py` - Protocol economic modeling
- `ml_strategy_recommender.py` - ML-based strategy recommendations
- `governance_proposal_builder.py` - Structured proposal generation

### Integration & Automation

- `integrate-aip-implementations.sh` - AIP feature integration
- `sdk_update_autonomics.ts` - SDK-based autonomic updates
- `register_chainhook.sh` - Chainhook registration
- `local_chainhook_harness.py` - Local chainhook testing

### Oracle Orchestration (NEW)

- `oracle_orchestrator.py` - Main oracle orchestration manager with trimmed-mean aggregation and external adapters
- `oracle_manager.py` - Oracle management CLI for admin operations
- `oracle_ops.sh` - Shell wrapper for convenient oracle operations
- `price_coordinator.py` - Multi-source price feed coordination service
- `oracle_health_monitor.py` - Comprehensive oracle health monitoring
- `oracle.conf` - Complete orchestration system configuration

External price adapters (async):

- `oracle_sources.py` - CoinGecko, Binance, Kraken, ALEX DEX adapters returning normalized integer prices

**Stacks Ecosystem Support:**

- Comprehensive mappings for 30+ Stacks tokens (STX, ALEX, DIKO, USDA, XBTC, WELSH, AUTO, etc.)
- ALEX DEX integration for Stacks-native token prices
- StacksSwap adapter (when API available)
- Stacks blockchain API integration (planned)
- Support for DeFi protocols: ALEX, Arkadiko, CityCoins
- Meme tokens: WELSH, BANANA, CORGI, PEPE
- Stablecoins: USDA, XUSD

Environment variables:

- `OFFLINE=1` or `ORACLE_OFFLINE=1` to disable network calls and use placeholders
- `ORACLE_CONFIG` path to JSON file overriding orchestrator fields (e.g., `external_sources`)
- `external_sources` list in config to select adapters, default: `["coingecko","binance","kraken","alex"]`

### GitHub Integration

- `label_completed_issues.py` - Automated issue labeling
- `claim-creator-tokens.sh` - Creator token claiming automation

## Quick Start

**Deploy to testnet:**

```bash
./deploy-testnet.sh
```

**Run all tests:**

```bash
./run-all-tests.sh
```

**Monitor protocol health:**

```bash
./monitor-health.sh
```

**Update autonomic parameters:**

```bash
python python_update_autonomics.py --broadcast
```

## Oracle Orchestration System

**Setup Oracle System:**

```bash
./oracle_ops.sh setup
```

**Manage Trading Pairs:**

```bash
# Add new trading pair
./oracle_ops.sh pair add STX USD --min-sources 3

# List all pairs
./oracle_ops.sh pair list
```

**Oracle Management:**

```bash
# Add oracle to pair
./oracle_ops.sh oracle add STX USD SP123...ORACLE

# Remove oracle from pair  
./oracle_ops.sh oracle remove STX USD SP123...ORACLE

# Check oracle status
./oracle_ops.sh oracle status STX USD SP123...ORACLE
```

**Price Operations:**

```bash
# Submit price manually
./oracle_ops.sh price submit STX USD 123456

# Get current price
./oracle_ops.sh price get STX USD

# Get median price
./oracle_ops.sh price median STX USD
```

**Monitoring:**

```bash
# Monitor all pairs
./oracle_ops.sh monitor --watch

# Monitor specific pair
./oracle_ops.sh monitor STX USD --watch

# Health check
./oracle_ops.sh health-check
```

**Start Orchestration Services:**

```bash
# Start full orchestrator
./oracle_ops.sh start-orchestrator full

# Start price coordinator only
python price_coordinator.py --pairs STX/USD,BTC/USD --interval 60

# Start health monitor
python oracle_health_monitor.py --monitor-all
```

## Deployment Workflows

### Testnet Deployment

```bash
# 1. Verify dependencies
python check_dependencies.py

# 2. Run tests
./run-all-tests.sh

# 3. Deploy contracts
./deploy-testnet.sh

# 4. Verify deployment
npm run verify-post
```

### Production Deployment

```bash
# 1. Security audit complete
./verify.sh

# 2. Multi-sig deployment
./deploy-mainnet.sh

# 3. Post-deployment verification
./post_deploy_verify.ts
```

## Economic Simulation

**Run economic stress tests:**

```bash
python economic_simulation.py | jq '.final'
```

**Generate strategy recommendations:**

```bash
python ml_strategy_recommender.py \
  --state-json '{"utilization_bps":8400,"reserve_ratio_bps":450}'
```

## Autonomic Controllers

**Manual autonomic update:**

```bash
# Read-only check
VAULT_CONTRACT=SP123.vault python python_update_autonomics.py

# Broadcast update
VAULT_CONTRACT=SP123.vault python python_update_autonomics.py --broadcast
```

**Keeper watchdog:**

```bash
python keeper_watchdog.py --config keeper.conf
```

## Monitoring & Alerts

**Health monitoring:**

```bash
# Basic health check
./monitor-health.sh

# Network connectivity
./ping.sh

# Contract status
./call-read.sh vault get-paused
```

## Testing Utilities

**Manual testing suite:**

```bash
./manual-testing.sh
```

**Integration testing:**

```bash
python local_chainhook_harness.py
```

**Contract verification:**

```bash
./verify.sh
```

## Configuration

Most scripts use environment variables for configuration:

```bash
# Network settings
export STACKS_API_BASE=https://api.testnet.hiro.so
export NETWORK=testnet

# Authentication
export DEPLOYER_PRIVKEY=your_private_key
export STACKS_PRIVKEY=your_hex_privkey

# Contract addresses
export VAULT_CONTRACT=SP123.vault
export TREASURY_CONTRACT=SP123.treasury
```

## Requirements

**System Dependencies:**

- Node.js (v18+)
- Python (v3.8+)
- Clarinet CLI
- curl, jq (for shell scripts)

**Python Packages:**

```bash
pip install requests stacks-transactions python-dotenv
# Optional for live external price adapters
pip install aiohttp
```

**Node.js Packages:**

```bash
npm install @stacks/transactions @stacks/network
```

## Security Considerations

- **Private keys** - Never commit private keys to version control
- **Multi-sig requirements** - Production deployments require multiple signatures
- **Rate limiting** - Some scripts include built-in rate limiting
- **Verification** - Always verify contracts post-deployment

## Development Workflow

1. **Develop locally** with clarinet
2. **Test thoroughly** with test suite
3. **Deploy to testnet** for integration
4. **Monitor and verify** deployment
5. **Deploy to mainnet** with multi-sig

For detailed documentation on specific scripts, see individual script
headers and the main [documentation](../documentation/) folder.
