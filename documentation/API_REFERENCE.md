# API Reference

This document provides a reference for smart contracts in the Conxian system, including mathematical libraries and lending system framework components.

## Contract Categories

### 🔬 Mathematical Foundation
Advanced mathematical functions providing enterprise-grade precision for DeFi calculations.

- **`math-lib-advanced.clar`** - Newton-Raphson sqrt, binary exponentiation pow, Taylor series ln/exp
- **`fixed-point-math.clar`** - 18-decimal precision arithmetic with proper rounding modes  
- **`precision-calculator.clar`** - Validation and benchmarking tools for mathematical operations

### 💰 Lending System Framework
Lending protocol framework with basic supply, borrow, liquidation structures, and ERC-3156 compatible flash loan implementation.

- **`comprehensive-lending-system.clar`** - Lending protocol framework with basic functionality
- **`enhanced-flash-loan-vault.clar`** - Flash loan implementation with reentrancy protection
- **`interest-rate-model.clar`** - Interest rate calculation framework
- **`loan-liquidation-manager.clar`** - Basic liquidation system structure
- **`lending-protocol-governance.clar`** - Governance framework for protocol parameters
- **`flash-loan-receiver-trait.clar`** - Interface for flash loan callback implementations
- **`lending-system-trait.clar`** - Comprehensive lending protocol interface definitions

### 🏦 Core Infrastructure
Foundational contracts providing the base functionality of the Conxian system.

- **`vault.clar`** - Share-based accounting with precision math integration
- **`cxd-staking.clar`** - Staking contract for CXD tokens
- **`cxd-token.clar`** - Main CXD token contract
- **`cxlp-migration-queue.clar`** - CXLP token migration management
- **`cxlp-token.clar`** - Liquidity pool token
- **`cxs-token.clar`** - Secondary system token
- **`cxtr-token.clar`** - Tertiary system token
- **`cxvg-token.clar`** - Governance token
- **`cxvg-utility.clar`** - Governance token utilities

### 🔀 DEX & Trading Infrastructure
Decentralized exchange functionality with advanced mathematical support.

- **`dex-factory.clar`** - DEX pool factory with advanced math integration
- **`dex-pool.clar`** - Standard DEX pool implementation  
- **`dex-router.clar`** - Multi-hop routing capabilities

### 🛡️ Security & Monitoring
System protection, monitoring, and performance optimization.

- **`automated-circuit-breaker.clar`** - Automated system protection mechanisms
- **`protocol-invariant-monitor.clar`** - Protocol health monitoring
- **`revenue-distributor.clar`** - Revenue distribution to stakeholders
- **`token-emission-controller.clar`** - Token emission management
- **`token-system-coordinator.clar`** - Token system coordination

### ⚡ Performance & Infrastructure
Advanced performance optimization and system management.

- **`distributed-cache-manager.clar`** - Distributed caching system
- **`memory-pool-management.clar`** - Memory optimization
- **`predictive-scaling-system.clar`** - Scaling predictions
- **`real-time-monitoring-dashboard.clar`** - Real-time monitoring
- **`transaction-batch-processor.clar`** - Batch processing optimization

### 📐 Dimensional System
Advanced mathematical and dimensional analysis contracts.

- **`dimensional/dim-graph.clar`** - Graph-based dimensional analysis
- **`dimensional/dim-metrics.clar`** - Dimensional metrics calculations
- **`dimensional/dim-oracle-automation.clar`** - Oracle automation for dimensions
- **`dimensional/dim-registry.clar`** - Dimensional system registry
- **`dimensional/dim-revenue-adapter.clar`** - Revenue adaptation for dimensional analysis
- **`dimensional/dim-yield-stake.clar`** - Dimensional yield staking
- **`dimensional/tokenized-bond-adapter.clar`** - Tokenized bond adaptation
- **`dimensional/tokenized-bond.clar`** - Tokenized bond implementation

### 🔧 Traits & Interfaces
Standard interfaces and trait definitions for system interoperability.

- **`traits/sip-010-trait.clar`** - Fungible token standard interface
- **`traits/vault-trait.clar`** - Vault interface definition
- **`traits/vault-admin-trait.clar`** - Vault admin interface
- **`traits/strategy-trait.clar`** - Strategy interface for yield strategies
- **`traits/pool-trait.clar`** - Pool interface for DEX pools
- **`traits/ownable-trait.clar`** - Ownership interface
- **`traits/dim-registry-trait.clar`** - Dimensional registry interface
- **`traits/dimensional-oracle-trait.clar`** - Dimensional oracle interface
- **`traits/ft-mintable-trait.clar`** - Mintable fungible token interface
- **`traits/monitor-trait.clar`** - Monitoring interface
- **`traits/sip-009-trait.clar`** - NFT standard interface  
- **`traits/staking-trait.clar`** - Staking interface

### 🧪 Testing & Utilities
Mock contracts and testing utilities.

- **`mocks/mock-token.clar`** - Mock token for testing
- **`enhanced-yield-strategy.clar`** - Enhanced yield strategy implementation

## Key Functions by Contract

### Mathematical Libraries

#### `math-lib-advanced.clar`
- **`sqrt-fixed(x)`** - Square root calculation with Newton-Raphson method (18-decimal precision)
- **`pow-fixed(base, exponent)`** - Power function with binary exponentiation (simplified implementation)
- **`ln-fixed(x)`** - Natural logarithm using Taylor series (basic approximation)
- **`exp-fixed(x)`** - Exponential function using Taylor series (basic approximation)

#### `fixed-point-math.clar`  
- **`mul-down(a, b)`** - Multiplication with rounding down
- **`mul-up(a, b)`** - Multiplication with rounding up
- **`div-down(a, b)`** - Division with rounding down
- **`div-up(a, b)`** - Division with rounding up
- **`percentage(value, percent)`** - Calculate percentage of value
- **`compound-interest(principal, rate, periods)`** - Compound interest calculation

### Lending System

#### `comprehensive-lending-system.clar`
- **`supply(asset, amount)`** - Supply assets to the protocol
- **`withdraw(asset, amount)`** - Withdraw supplied assets
- **`borrow(asset, amount)`** - Borrow assets against collateral
- **`repay(asset, amount)`** - Repay borrowed assets
- **`liquidate(borrower, asset, repay-amount)`** - Liquidate undercollateralized positions
- **`flash-loan(asset, amount, receiver, data)`** - Execute flash loan with callback
- **`get-health-factor(user)`** - Calculate user's health factor (read-only)
- **`get-supply-balance(user, asset)`** - Get user's supply balance (read-only)
- **`get-borrow-balance(user, asset)`** - Get user's borrow balance (read-only)

#### `enhanced-flash-loan-vault.clar`
- **`flash-loan(asset, amount, receiver, data)`** - ERC-3156 compatible flash loan implementation
- **`get-flash-loan-stats(asset)`** - Get flash loan statistics for specific asset (read-only)
- **`calculate-flash-loan-fee(asset, amount)`** - Calculate flash loan fee (read-only)
- **`get-max-flash-loan(asset)`** - Get maximum flash loan amount available (read-only)

#### `interest-rate-model.clar`
- **`get-borrow-rate(cash, borrows, reserves)`** - Calculate borrow interest rate
- **`get-supply-rate(cash, borrows, reserves, reserve-factor)`** - Calculate supply interest rate  
- **`get-utilization-rate(cash, borrows, reserves)`** - Calculate utilization rate

### Governance & Risk Management

#### `lending-protocol-governance.clar`
- **`propose(title, description, type, target, function, params)`** - Create governance proposal
- **`vote(proposal-id, support, reason)`** - Vote on proposal
- **`queue-proposal(proposal-id)`** - Queue successful proposal for execution
- **`execute-proposal(proposal-id)`** - Execute queued proposal
- **`delegate(delegatee)`** - Delegate voting power

#### `loan-liquidation-manager.clar`  
- **`liquidate-position(borrower, debt-asset, collateral-asset, debt-amount, max-collateral)`** - Liquidate position
- **`is-position-liquidatable(borrower)`** - Check if position can be liquidated
- **`calculate-liquidation-amounts(borrower, debt-asset, collateral-asset)`** - Calculate liquidation parameters
- **`get-liquidation-stats()`** - Get system liquidation statistics

**Note**: This API reference reflects the current contract implementations. Some functions may be basic frameworks requiring further development for production use. For detailed parameters and implementation specifics, refer to the contract source code in the `contracts/` directory.
