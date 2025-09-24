# Conxian Documentation Hub

This is the central documentation hub for the Conxian DeFi platform. All documentation follows best practices and is organized by audience and purpose.

## 📚 Documentation Structure

### 👥 For Users
- [`user/USER_MANUAL.md`](./user/USER_MANUAL.md) - **Complete user guide and onboarding**
- [`user/QUICK_START.md`](./user/QUICK_START.md) - **5-minute getting started guide**

### 👨‍💻 For Developers
- [`developer/DEVELOPER_GUIDE.md`](./developer/DEVELOPER_GUIDE.md) - **Development setup and contributing**
- [`developer/CI_CD_PIPELINE.md`](./developer/CI_CD_PIPELINE.md) - **CI/CD pipeline documentation**
- [`developer/REPOSITORY_SECRETS_SETUP.md`](./developer/REPOSITORY_SECRETS_SETUP.md) - **Repository secrets setup**
- [`developer/error-codes.md`](./developer/error-codes.md) - **Error codes reference**
- [`developer/trait-registry.md`](./developer/trait-registry.md) - **Trait system documentation**
- [`standards/BIP-COMPLIANCE.md`](./standards/BIP-COMPLIANCE.md) - **Bitcoin integration compliance**
- [`standards/standards.md`](./standards/standards.md) - **Development standards and guidelines**

### 🏗️ Architecture & Design
- [`architecture/ARCHITECTURE.md`](./architecture/ARCHITECTURE.md) - **System architecture and design**
- [`architecture/system_spec.md`](./architecture/system_spec.md) - **Complete system specification**
- [`architecture/TOKENOMICS.md`](./architecture/TOKENOMICS.md) - **Economic model and token design**
- [`architecture/NAKAMOTO_SBTC_INTEGRATION.md`](./architecture/NAKAMOTO_SBTC_INTEGRATION.md) - **sBTC integration details**
- [`architecture/WORMHOLE_INTEGRATION.md`](./architecture/WORMHOLE_INTEGRATION.md) - **Cross-chain integration**
- [`architecture/DEFI_GAP_ANALYSIS_COMPREHENSIVE.md`](./architecture/DEFI_GAP_ANALYSIS_COMPREHENSIVE.md) - **DeFi gap analysis**
- [`architecture/DEX_DESIGN.md`](./architecture/DEX_DESIGN.md) - **DEX design specifications**
- [`architecture/YIELD_STRATEGY_GAP_ANALYSIS.md`](./architecture/YIELD_STRATEGY_GAP_ANALYSIS.md) - **Yield strategy analysis**
- [`architecture/adr/`](./architecture/adr/) - **Architecture decision records**

### 🚀 Deployment & Operations
- [`deployment/DEPLOYMENT.md`](./deployment/DEPLOYMENT.md) - **Production deployment guide**
- [`deployment/DEPLOYMENT.md`](./deployment/DEPLOYMENT.md) - **Testnet deployment guide**

### 🔒 Security & Compliance
- [`security/SECURITY.md`](./security/SECURITY.md) - **Security features and audit information**
- [`security/security-checklist.md`](./security/security-checklist.md) - **Security checklist**

### 📖 Guides & References
- [`api/API_REFERENCE.md`](./api/API_REFERENCE.md) - **Smart contract function reference**
- [`guides/contract-guides/`](./guides/contract-guides/) - **Detailed contract guides and specifications**
- [`guides/liquidation-flow.md`](./guides/liquidation-flow.md) - **Liquidation process guide**
- [`guides/oracle-integration.md`](./guides/oracle-integration.md) - **Oracle integration guide**
- [`guides/oracle-system.md`](./guides/oracle-system.md) - **Oracle system documentation**

### 📊 Project Management
- [`project-management/STATUS.md`](./project-management/STATUS.md) - **Current project status**
- [`project-management/ROADMAP.md`](./project-management/ROADMAP.md) - **Future development plans**
- [`project-management/CHANGELOG.md`](./project-management/CHANGELOG.md) - **Version history and changes**
- [`project-management/DEX_IMPLEMENTATION_ROADMAP.md`](./project-management/DEX_IMPLEMENTATION_ROADMAP.md) - **DEX implementation roadmap**
- [`project-management/DEX_IMPLEMENTATION_SUMMARY.md`](./project-management/DEX_IMPLEMENTATION_SUMMARY.md) - **DEX implementation summary**
- [`project-management/GAP_ANALYSIS_EXECUTIVE_SUMMARY.md`](./project-management/GAP_ANALYSIS_EXECUTIVE_SUMMARY.md) - **Gap analysis summary**

## 🎯 Quick Navigation

| I want to... | Read this |
|---------------|-----------|
| Get started as a user | [User Manual](./user/USER_MANUAL.md) |
| Quick 5-minute setup | [Quick Start](./user/QUICK_START.md) |
| Integrate with contracts | [API Reference](./api/API_REFERENCE.md) |
| Contribute code | [Developer Guide](./developer/DEVELOPER_GUIDE.md) |
| Understand the economics | [Tokenomics](./architecture/TOKENOMICS.md) |
| Review security | [Security](./security/SECURITY.md) |
| Check current status | [Status](./project-management/STATUS.md) |
| Deploy to production | [Deployment](./deployment/DEPLOYMENT.md) |
| **Use lending & flash loans** | [**System Specification**](./architecture/system_spec.md) |
| **Understand mathematics** | [**Mathematical Libraries Guide**](./guides/contract-guides/README.md) |
| **Set up CI/CD** | [**CI/CD Pipeline**](./developer/CI_CD_PIPELINE.md) |
| **Bitcoin integration** | [**sBTC Integration**](./architecture/NAKAMOTO_SBTC_INTEGRATION.md) |
| **Cross-chain features** | [**Wormhole Integration**](./architecture/WORMHOLE_INTEGRATION.md) |

## 📋 Documentation Standards

All documentation follows these principles:

- **🎯 User-focused**: Written for specific audiences
- **✅ Actionable**: Provides clear steps and examples
- **🔄 Current**: Reflects actual implementation
- **📝 Concise**: No redundancy or outdated information
- **🔍 Searchable**: Well-structured with clear headings

## 🗂️ File Organization

```
documentation/
├── README.md (this file)
├── user/                    # User-focused documentation
├── developer/               # Developer guides and standards
├── architecture/            # System design and specifications
├── deployment/              # Deployment and operations
├── security/                # Security and compliance
├── api/                     # API and contract references
├── guides/                  # How-to guides and tutorials
├── standards/               # Standards and best practices
└── project-management/      # Status, roadmap, and planning
```

## 📝 Contributing

When adding new documentation:

1. **Follow the existing structure** - Place files in the appropriate directory
2. **Use consistent naming** - Follow the established naming conventions
3. **Update this README** - Add new files to the navigation table
4. **Cross-reference** - Link related documents where appropriate
5. **Keep it current** - Remove outdated information

## 🔗 Related Resources

- **📖 Main Project README**: [`../README.md`](../README.md)
- **⚙️ Configuration**: [`../Clarinet.toml`](../Clarinet.toml)
- **📄 Full Documentation Index**: [`../FULL_SYSTEM_INDEX.md`](../FULL_SYSTEM_INDEX.md)

---

*Last updated: September 23, 2025* | *Documentation reorganized for clarity and maintainability*
