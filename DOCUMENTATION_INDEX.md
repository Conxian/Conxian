# Conxian Protocol Documentation Index

**Last Updated**: December 7, 2025  
**Status**: Stabilization Phase - Testnet Only  
**Compilation Status**: ✅ 111 contracts passing

---

## 📚 Quick Navigation

### For Developers

- [Developer Guide](#developer-documentation)
- [Architecture Overview](#architecture--design)
- [API Reference](#api-documentation)
- [Testing Guide](#testing--quality)

### For Enterprise Users

- [Enterprise Overview](#enterprise-documentation)
- [Service Catalog](#service-catalog)
- [Compliance & Security](#compliance--security)

### For Contributors

- [Contributing Guide](#contributing)
- [Roadmap](#project-management)
- [Changelog](#changelog)

---

## 🏗️ Architecture & Design

### Core Architecture

- **[Architecture Specification](./documentation/ARCHITECTURE_SPEC.md)** - High-level system design and module interactions
- **[Architecture Deep Dive](./documentation/architecture/ARCHITECTURE.md)** - Detailed architectural decisions and patterns
- **[Company Charter](./documentation/COMPANY_CHARTER.md)** - On-chain company model (departments, roles, and alignment under DAO + Conxian Labs)
- **[Whitepaper](./documentation/whitepaper/Conxian-Whitepaper.md)** - Complete technical vision and protocol design

### System Components

- **[Behavior Metrics System](./documentation/BEHAVIOR_METRICS.md)** - Reputation tracking and incentive system
- **[Operations Runbook](./documentation/OPERATIONS_RUNBOOK.md)** - Operational procedures and admin controls
- **[Regulatory Alignment](./documentation/REGULATORY_ALIGNMENT.md)** - Compliance mapping and regulatory objectives
- **[Identity, KYC & POPIA Charter](./documentation/IDENTITY_KYC_POPIA.md)** - Identity, KYC/KYB, and data protection alignment
- **[Treasury & Revenue Router](./documentation/TREASURY_AND_REVENUE_ROUTER.md)** - Treasury structure and protocol revenue routing
- **[Payroll & Rewards](./documentation/PAYROLL_AND_REWARDS.md)** - Guardian, contributor, and Labs payment design
- **[Legal Representatives & Bounties](./documentation/LEGAL_REPRESENTATIVES_AND_BOUNTIES.md)** - Legal wrappers, advisors, and bounty incentives
- **[Payments & Providers](./documentation/PAYMENTS_AND_PROVIDERS.md)** - External payment and banking provider integration

---

## 👨‍💻 Developer Documentation

### Getting Started

- **[README](./README.md)** - Project overview and quick start
- **[Developer Guide](./documentation/developer/DEVELOPER_GUIDE.md)** - Complete development setup and workflow
- **[Contributing Guide](./CONTRIBUTING.md)** - Contribution guidelines and standards

### Contract Development
- **[Naming Standards](./NAMING_STANDARDS.md)** - Contract, token, and council naming conventions
- **[Architecture Specification](./documentation/ARCHITECTURE_SPEC.md)** - System design and module interactions

### Testing

- **[Testing Framework](./documentation/TESTING_FRAMEWORK.md)** - Test infrastructure and best practices
- **[Test Coverage Reports](./documentation/benchmarking/)** - Performance and coverage metrics

---

## 🔌 API Documentation

### Protocol APIs

- **[API Overview](./documentation/API_OVERVIEW.md)** - Comprehensive API surface documentation
- **[On-Chain APIs](./documentation/api/)** - Contract function references
- **[Deployment APIs](./documentation/deployment/)** - StacksOrbit deployment interfaces

### Integration Guides

- **[Enterprise Integration](./documentation/enterprise/ONBOARDING.md)** - Enterprise integration patterns
- **[UI Integration](./documentation/ui-default-strategies.md)** - Frontend integration guide

---

## 🏢 Enterprise Documentation

### Business Overview

- **[Enterprise Buyer Overview](./documentation/ENTERPRISE_BUYER_OVERVIEW.md)** - Executive summary for institutional stakeholders
- **[Service Catalog](./documentation/SERVICE_CATALOG.md)** - Available services and maturity levels
- **[Business Value & ROI](./documentation/enterprise/BUSINESS_VALUE_ROI.md)** - Value proposition and ROI analysis

### Compliance & Security

- **[Compliance & Security Framework](./documentation/enterprise/COMPLIANCE_SECURITY.md)** - Security controls and compliance standards
- **[Regulatory Alignment](./documentation/REGULATORY_ALIGNMENT.md)** - Regulatory mapping and objectives
- **[Identity, KYC & POPIA Charter](./documentation/IDENTITY_KYC_POPIA.md)** - Identity and data protection standards (Conxian and Conxian Labs)
- **[Payments & Providers](./documentation/PAYMENTS_AND_PROVIDERS.md)** - How Conxian Labs interacts with payment and banking providers
- **[Security Review Process](./documentation/SECURITY_REVIEW_PROCESS.md)** - Security audit procedures

---

## 📊 Project Management

### Planning & Tracking

- **[Roadmap](./ROADMAP.md)** - Development phases and milestones
- **[Changelog](./CHANGELOG.md)** - Version history and feature tracking

### Status Reports

- **[TODO Audit Report](./TODO_AUDIT_REPORT.md)** - Comprehensive TODO analysis and production readiness
- **[Benchmark Reports](./documentation/benchmarking/)** - Performance benchmarks and TPS reports

---

## 🔐 Security & Audit

### Security Documentation

- **[Audit Findings](./stacks/security/audit-findings/)** - Security audit reports and remediation
- **[Audit Checklist](./stacks/security/audit-prep/audit-checklist.md)** - Pre-audit preparation checklist

### Incident Response

- **[Operations Runbook](./documentation/OPERATIONS_RUNBOOK.md)** - Incident response and emergency procedures

---

## 🎯 Governance

### Governance Framework

- **[Governance Overview](./contracts/governance/README.md)** - Governance architecture and councils
- **[Governance Transition](./stacks/governance/governance-transition.md)** - Governance evolution plan
- **[Initial Parameters](./stacks/governance/initial-parameters.md)** - Bootstrap parameters

### Community Resources

- **[Voter Guide](./stacks/governance/community/voter-guide.md)** - How to participate in governance
- **[Delegation Guide](./stacks/governance/community/delegation-guide.md)** - Vote delegation instructions
- **[Proposal Template](./stacks/governance/proposal-template.md)** - How to create proposals

### Proposals (CXIPs)

- [CXIP-1](./stacks/governance/proposals/CXIP-1.md) through [CXIP-9](./stacks/governance/proposals/CXIP-9.md) - Conxian Improvement Proposals

---

## 📖 Module-Specific Documentation

### Core Modules

- **[Core Module](./contracts/core/README.md)** - Protocol foundation and orchestration
- **[DEX Module](./contracts/dex/README.md)** - Decentralized exchange functionality
- **[Lending Module](./contracts/lending/README.md)** - Lending and borrowing infrastructure
- **[Tokens Module](./contracts/tokens/README.md)** - Token system and emission controls

### Supporting Modules

- **[Governance Module](./contracts/governance/README.md)** - DAO and council governance
- **[Security Module](./contracts/security/README.md)** - MEV protection and circuit breakers
- **[Monitoring Module](./contracts/monitoring/README.md)** - Observability and analytics
- **[Vaults Module](./contracts/vaults/README.md)** - sBTC vault and yield aggregation

---

## 🛠️ Testing & Quality

### Test Documentation

- **[Testing Framework](./documentation/TESTING_FRAMEWORK.md)** - Test infrastructure overview
- **[Strategy Testing Plan](./documentation/strategy-testing-plan.md)** - Strategy testing approach
- **[Benchmarking Report](./documentation/benchmarking/benchmarking-report.md)** - Performance benchmarks

### Test Suites

- **Unit Tests**: `tests/` - Contract-level unit tests
- **Integration Tests**: `tests/` - Cross-contract integration tests
- **System Tests**: `tests/` - End-to-end system tests

---

## 📝 Standards & Guidelines

### Development Standards

- **[Naming Standards](./NAMING_STANDARDS.md)** - Naming conventions for contracts, tokens, and councils
- **[Contributing Guidelines](./CONTRIBUTING.md)** - Code style and contribution process
- **[Code Review Standards](./documentation/review/)** - Review checklist and criteria

### Documentation Standards

- **[Documentation README](./documentation/README.md)** - Documentation structure and guidelines
- **[Markdown Standards](./documentation/standards/)** - Markdown formatting guidelines

---

## 🔄 Migration & Deployment

### Deployment Guides

- **[Deployment Guide](./documentation/deployment/)** - Contract deployment procedures
- **[Migration Guide](./documentation/developer/MIGRATION_GUIDE_ACCESS_CONTROL.md)** - Access control migration

### Configuration

- **[Deployment Plans](./deployments/)** - Network-specific deployment configurations
- **[Wallet Configuration](./config/)** - Wallet setup for different networks

---

## 📚 Additional Resources

### External Documentation

- **[Stacks Documentation](https://docs.stacks.co/)** - Stacks blockchain documentation
- **[Clarity Language](https://docs.stacks.co/clarity/)** - Clarity smart contract language
- **[Clarinet SDK](https://docs.hiro.so/stacks/clarinet-js-sdk)** - Testing framework documentation

### Community

- **GitHub**: [Anya-org/Conxian](https://github.com/Anya-org/Conxian)
- **Issues**: [GitHub Issues](https://github.com/Anya-org/Conxian/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Anya-org/Conxian/discussions)

---

## 📋 Document Status Legend

- ✅ **Current** - Up to date with latest codebase
- 🔄 **In Progress** - Being actively updated

### Current Status by Document

| Document | Status | Last Updated |
|----------|--------|--------------|
| README.md | ✅ Current | Dec 6, 2025 |
| ROADMAP.md | ✅ Current | Dec 6, 2025 |
| CHANGELOG.md | ✅ Current | Dec 6, 2025 |
| TODO_AUDIT_REPORT.md | ✅ Current | Dec 6, 2025 |
| BEHAVIOR_METRICS.md | ✅ Current | Dec 6, 2025 |
| SERVICE_CATALOG.md | ✅ Current | Dec 6, 2025 |
| DOCUMENTATION_INDEX.md | ✅ Current | Dec 6, 2025 |
| COMPANY_CHARTER.md | 🔄 In Progress | Dec 7, 2025 |
| IDENTITY_KYC_POPIA.md | 🔄 In Progress | Dec 7, 2025 |
| TREASURY_AND_REVENUE_ROUTER.md | 🔄 In Progress | Dec 7, 2025 |
| PAYROLL_AND_REWARDS.md | 🔄 In Progress | Dec 7, 2025 |
| LEGAL_REPRESENTATIVES_AND_BOUNTIES.md | 🔄 In Progress | Dec 7, 2025 |
| PAYMENTS_AND_PROVIDERS.md | 🔄 In Progress | Dec 7, 2025 |

---

## 🔍 Finding Information

### By Topic

- **Architecture**: Start with [Architecture Specification](./documentation/ARCHITECTURE_SPEC.md)
- **Development**: Start with [Developer Guide](./documentation/developer/DEVELOPER_GUIDE.md)
- **Enterprise**: Start with [Enterprise Buyer Overview](./documentation/ENTERPRISE_BUYER_OVERVIEW.md)
- **Security**: Start with [Compliance & Security](./documentation/enterprise/COMPLIANCE_SECURITY.md)
- **Governance**: Start with [Governance Module](./contracts/governance/README.md)

### By Role

- **Developer**: Developer Guide → API Overview → Testing Framework
- **Enterprise Buyer**: Enterprise Overview → Service Catalog → Compliance
- **Auditor**: TODO Audit Report → Security Review Process → Audit Findings
- **Contributor**: Contributing Guide → Naming Standards → Code Review Standards

---

## 📞 Support & Contact

For questions or support:

1. Check relevant documentation section above
2. Search [GitHub Issues](https://github.com/Anya-org/Conxian/issues)
3. Create a new issue with the appropriate template
4. Join community discussions

---

**Note**: This documentation index follows GitHub Pages best practices and is designed for both web and repository viewing. All links are relative and work in both contexts.
