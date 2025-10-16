# API Reference

## JavaScript API

```javascript
const { StacksOrbit } = require('stacksorbit');

// Initialize
const deployer = new StacksOrbit({
  network: 'testnet',
  privateKey: process.env.DEPLOYER_PRIVKEY,
  systemAddress: process.env.SYSTEM_ADDRESS
});

// Deploy contracts
await deployer.deployAll();

// Deploy specific contracts
await deployer.deploy(['contract1.clar', 'contract2.clar']);
```

## Python API

```python
from stacksorbit import StacksOrbit

# Initialize
deployer = StacksOrbit(
    network='testnet',
    private_key=os.environ.get('DEPLOYER_PRIVKEY'),
    system_address=os.environ.get('SYSTEM_ADDRESS')
)

# Deploy contracts
deployer.deploy_all()

# Deploy specific contracts
deployer.deploy(['contract1.clar', 'contract2.clar'])
```

## CLI Options

```
stacksorbit [options]

Options:
  --network <network>       Target network (default: "testnet")
  --contracts <contracts>   Comma-separated contract list
  --mode <mode>             Deployment mode (full|upgrade|custom)
  --headless                Run without GUI
  --verbose                 Enable verbose logging
```