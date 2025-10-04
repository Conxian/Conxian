# StacksOrbit 🚀

> Professional GUI deployment tool for Stacks blockchain smart contracts with intelligent pre-checks, real-time process control, and comprehensive failure logging.

[![NPM Version](https://img.shields.io/npm/v/stacksorbit.svg)](https://www.npmjs.com/package/stacksorbit)
[![PyPI Version](https://img.shields.io/pypi/v/stacksorbit.svg)](https://pypi.org/project/stacksorbit/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/)

**Deploy smart contracts to Stacks blockchain with confidence** - One-click deployment, intelligent validation, and full process control in a beautiful GUI.

---

## ✨ Features

### 🚀 One-Click Deployment
- Deploy to **devnet**, **testnet**, or **mainnet** with a single click
- Auto-detects and deploys 100+ contracts in correct order
- Smart deployment modes: **full** or **upgrade** (skips deployed)

### 🔍 Intelligent Pre-Checks
- ✅ **Environment validation** - Required and optional variables
- 🌐 **Network connectivity** - Tests API endpoints before deploy
- 📊 **Existing deployments** - Auto-detects what's already on-chain
- ✓ **Compilation status** - Validates contracts compile cleanly

### ⛔ Real-Time Process Control
- **Start/Stop** deployments anytime
- **Live status** indicators (running/complete/failed)
- **PID tracking** for running processes
- **Graceful termination** on stop

### 💾 Comprehensive Logging
- **Auto-save** failure logs with full context
- **Error tracking** throughout session
- **Manual export** anytime
- **Complete replay** capability

### ⚙️ Advanced Controls (Side Panel)
- Network switching (devnet/testnet/mainnet)
- Deploy mode selection (SDK/Clarinet TOML)
- Contract filtering (comma-separated)
- Custom deployment options
- Advanced actions (handover, pipeline, etc.)

---

## 📦 Installation

### Via npm (Recommended)

```bash
npm install -g stacksorbit
```

### Via pip

```bash
pip install stacksorbit
```

### From Source

```bash
git clone https://github.com/Anya-org/stacksorbit.git
cd stacksorbit
pip install -r requirements.txt
```

---

## 🚀 Quick Start

### 1. Configure Environment

Create a `.env` file in your project root:

```env
# Required Variables
DEPLOYER_PRIVKEY=your_hex_private_key_here
SYSTEM_ADDRESS=SP2ED6H1EHHTZA1NTWR2GKBMT0800Y6F081EEJ45R
NETWORK=testnet

# Optional (Recommended)
HIRO_API_KEY=your_hiro_api_key
CORE_API_URL=https://api.testnet.hiro.so
```

### 2. Launch StacksOrbit

```bash
stacksorbit
```

Or if installed from source:

```bash
python stacksorbit.py
```

### 3. Deploy Your Contracts

1. **Run Pre-Checks** (🔍 button) - Validates everything
2. **Review Results** - Environment, network, deployments, compilation
3. **Click Deploy** (🚀 button) - Deploys to selected network
4. **Monitor Progress** - Real-time log output
5. **Stop if Needed** (⛔ button) - Graceful termination

---

## 📖 Usage Guide

### Basic Workflow

```bash
# Step 1: Launch GUI
stacksorbit

# Step 2: Auto-Detection (Automatic)
# ✅ Loads .env configuration
# ✅ Detects all .clar contracts
# ✅ Configures network settings
# ✅ Shows deployment status

# Step 3: Pre-Deployment Checks (Recommended)
# Click "🔍 Run Pre-Deployment Checks"
# - Validates required environment variables
# - Tests network connectivity
# - Checks for existing deployments
# - Verifies contract compilation

# Step 4: Deploy
# Click "🚀 DEPLOY TO TESTNET"
# - Monitors real-time progress
# - Stop anytime with ⛔ button
# - Auto-saves failure logs
```

### Advanced Features

#### Network Selection (Right Panel)
```
○ Devnet   - Local testing (Clarinet)
● Testnet  - Public testing network
○ Mainnet  - Production network
```

#### Deploy Modes
```
● SDK Deploy      - Uses @stacks/transactions (recommended)
○ Clarinet TOML   - Deploys from Clarinet.toml order
```

#### Contract Filtering
Filter specific contracts (comma-separated):
```
all-traits,cxd-token,dex-factory,oracle-aggregator
```

#### Deployment Options
```
☐ Devnet Dry Run      - Test without broadcasting
☐ Execute Handover    - Run post-deployment handover
```

---

## 🔍 Pre-Deployment Checks

StacksOrbit runs **4 comprehensive validation checks** before deployment:

### 1. Environment Variables ✅

**Required Variables**:
- `DEPLOYER_PRIVKEY` - Hex private key for deployment
- `SYSTEM_ADDRESS` - Deployer Stacks address
- `NETWORK` - Target network (devnet/testnet/mainnet)

**Optional Variables**:
- `HIRO_API_KEY` - Improves API rate limits
- `CORE_API_URL` - Custom API endpoint

### 2. Network Connectivity 🌐

Tests the configured API endpoint:
- Validates network is accessible
- Confirms network_id matches
- Shows connection status
- Handles timeouts gracefully

### 3. Existing Deployments 🔍

Checks blockchain for deployed contracts:
- Queries account nonce
- Samples key contracts (all-traits, tokens, dex)
- **Auto-detects deployment mode**:
  - **FULL** - No contracts deployed (fresh)
  - **UPGRADE** - Some contracts exist (skip deployed)

### 4. Compilation Status ✓

Validates contracts compile:
- Runs `clarinet check`
- Counts compilation errors
- Shows error summary
- Allows deployment with warnings

---

## ⛔ Process Control

### Stop Button

**Gracefully terminate** any running deployment:
- Appears when process starts (red button)
- Sends SIGTERM to process
- Updates status immediately
- Cleans up resources

### Status Indicators

Real-time status with color coding:
- 🔄 **Running...** (orange) - Deployment in progress
- ✅ **Complete** (green) - Successfully deployed
- ❌ **Failed** (red) - Deployment error occurred
- ⛔ **Stopped** (red) - User terminated process

### Process Information

Track running deployments:
- **PID display** - Process ID shown when running
- **Status updates** - Real-time progress
- **Button states** - Deploy disabled when running
- **Auto-cleanup** - Resources freed on completion

---

## 💾 Failure Handling

### Automatic Failure Logs

All failures are automatically saved to:
```
logs/deployment_failure_YYYYMMDD_HHMMSS.log
```

**Log Contents**:
- **Timestamp** - When failure occurred
- **Network** - Target network
- **Deployer** - Deployer address
- **Reason** - Why it failed
- **Error Count** - Total errors detected
- **Full Session** - Complete output replay

### Manual Log Export

Export current session anytime:
- Click "💾 Save Log" button
- Saves to `logs/` directory
- Includes all output and errors
- Useful for debugging and support

### Error Tracking

Real-time error monitoring:
- Tracks errors throughout session
- Shows count in log file
- Highlights failures in red (❌)
- Auto-detects keywords: error, failed, ❌

---

## 🏗️ Architecture

### Two-Panel Layout

```
┌─────────────────────────────────────────────────────────────┐
│  LEFT PANEL (Primary)        │  RIGHT PANEL (Advanced)      │
│  ────────────────────────     │  ──────────────────────      │
│  📊 Deployment Status         │  ⚙️ Network Selection        │
│  Network: TESTNET             │  ○ Devnet                    │
│  Contracts: 145 detected      │  ● Testnet                   │
│  Deployer: SP2ED...           │  ○ Mainnet                   │
│  Status: ✅ Ready             │                               │
│                               │  Deploy Mode                  │
│  [🚀 DEPLOY TO TESTNET]      │  ● SDK Deploy                │
│  [⛔ STOP PROCESS]            │  ○ Clarinet TOML             │
│  [🔍 Run Pre-Checks]         │                               │
│  [✓][🧪][💾][🔄]            │  Options                      │
│                               │  ☐ Devnet Dry Run            │
│  ┌───────────────────────┐   │  ☐ Execute Handover          │
│  │ 📝 Deployment Log     │   │                               │
│  │ Terminal-style output │   │  Contract Filter              │
│  │ Real-time progress... │   │  [all-traits,cxd-token]      │
│  │ ✅ Contract deployed  │   │                               │
│  └───────────────────────┘   │  Actions                      │
│                               │  [Deploy Devnet]              │
│                               │  [Handover]                   │
│                               │  [Pipeline]                   │
│                               │  [Gen Wallets]                │
│                               │                               │
│                               │  Process Info                 │
│                               │  PID: 12345                   │
└─────────────────────────────────────────────────────────────┘
```

### Technology Stack

**Frontend**:
- Python 3.8+ (tkinter GUI)
- Cross-platform (Windows, macOS, Linux)

**Backend**:
- Subprocess management
- Environment variable handling
- File I/O for logging
- Network requests for validation

**Deployment**:
- `@stacks/transactions` (SDK mode)
- Clarinet CLI (TOML mode)
- Custom deployment scripts

---

## 🧪 Testing

StacksOrbit includes comprehensive test suite:

```bash
# Run all tests
npm test

# Or with Python
python -m pytest tests/

# Run GUI test suite
powershell scripts/test-gui-deployer.ps1
```

**Test Coverage**:
- ✅ Environment validation (17 tests)
- ✅ Contract detection
- ✅ Network connectivity
- ✅ Process management
- ✅ Logging functionality
- ✅ GUI components

---

## 📚 Documentation

- [Installation Guide](docs/installation.md)
- [Configuration](docs/configuration.md)
- [Deployment Guide](docs/deployment.md)
- [Troubleshooting](docs/troubleshooting.md)
- [API Reference](docs/api.md)
- [Contributing](CONTRIBUTING.md)

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Development setup
- Code style guide
- Testing requirements
- Pull request process

---

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🔗 Links

- **GitHub**: https://github.com/Anya-org/stacksorbit
- **NPM**: https://www.npmjs.com/package/stacksorbit
- **PyPI**: https://pypi.org/project/stacksorbit/
- **Documentation**: https://stacksorbit.dev
- **Issues**: https://github.com/Anya-org/stacksorbit/issues
- **Discussions**: https://github.com/Anya-org/stacksorbit/discussions

---

## 💬 Support

- 📖 [Documentation](https://stacksorbit.dev)
- 💬 [GitHub Discussions](https://github.com/Anya-org/stacksorbit/discussions)
- 🐛 [Report Issues](https://github.com/Anya-org/stacksorbit/issues)
- 💼 [Enterprise Support](mailto:support@anyachainlabs.com)

---

## 🎯 Roadmap

### v1.0.0 (Current)
- ✅ GUI deployment interface
- ✅ Pre-deployment checks
- ✅ Process control
- ✅ Failure logging
- ✅ Advanced controls

### v1.1.0 (Planned)
- [ ] Multi-network parallel deploy
- [ ] Deployment history/rollback
- [ ] Contract upgrade wizard
- [ ] Gas estimation
- [ ] Deployment templates

### v2.0.0 (Future)
- [ ] Web-based interface
- [ ] REST API
- [ ] Docker support
- [ ] CI/CD integrations
- [ ] Team collaboration features

---

**Built with ❤️ by [Anya Chain Labs](https://anyachainlabs.com)**

*Deploy smart contracts to Stacks blockchain with confidence* 🚀
