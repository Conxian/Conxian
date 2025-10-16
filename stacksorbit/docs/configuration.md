# StacksOrbit Configuration Guide

## Environment Setup

Create a `.env` file in your project root with the following variables:

```env
# Required Variables
DEPLOYER_PRIVKEY=your_hex_private_key_here
SYSTEM_ADDRESS=SP2ED6H1EHHTZA1NTWR2GKBMT0800Y6F081EEJ45R
NETWORK=testnet

# Optional (Recommended)
HIRO_API_KEY=your_hiro_api_key
CORE_API_URL=https://api.testnet.hiro.so
```

## Configuration Options

| Variable | Required | Description |
|----------|----------|-------------|
| DEPLOYER_PRIVKEY | Yes | Private key for deployment account |
| SYSTEM_ADDRESS | Yes | System account address |
| NETWORK | Yes | Target network (devnet/testnet/mainnet) |
| HIRO_API_KEY | No | API key for higher rate limits |
| CORE_API_URL | No | Custom API endpoint |

See the [Deployment Guide](./deployment.md) for next steps.