# Conxian Protocol: Architecture Specification

**Version:** 0.8.0 (Alpha)
**Date:** December 03, 2025
**Status:** In Review

---

## 1. Vision & Architecture

Conxian is a multi-dimensional DeFi protocol built on the Stacks blockchain, with a focus on modularity, security, and a seamless user experience. The protocol is designed with a **facade-based architecture**, where central contracts provide a unified interface for interacting with specialized, single-responsibility contracts.

**Core Principles:**

- **Modularity**: The protocol is divided into distinct modules (e.g., Core, DEX, Governance, Lending), each with a clear and specific purpose.
- **Facade-Based Design**: Each module is centered around a primary contract that acts as a facade, routing calls to the appropriate specialized contracts.
- **Security First**: The architecture is designed to minimize the attack surface by isolating logic and enforcing strict access control.
- **Clarity and Readability**: The codebase is written to be as clear and understandable as possible, with comprehensive docstrings and documentation.

---

## 2. System Architecture

The Conxian Protocol is organized into a series of distinct modules, each responsible for a specific area of functionality.

### 2.1 Core Module

- **Location**: `contracts/core/`
- **Responsibility**: The foundational layer of the protocol, responsible for orchestrating interactions between various components.
- **Key Contracts**:
  - `dimensional-engine.clar`: The central facade for the Core Module, routing calls to the specialized manager contracts.
  - `position-manager.clar`: Manages the lifecycle of user positions.
  - `collateral-manager.clar`: Handles the deposit, withdrawal, and management of user collateral.

### 2.2 DEX Module

- **Location**: `contracts/dex/`
- **Responsibility**: Provides the core functionality for decentralized exchange operations.
- **Key Contracts**:
  - `multi-hop-router-v3.clar`: The central routing engine for the DEX, supporting 1-hop, 2-hop, and 3-hop swaps.
  - `concentrated-liquidity-pool.clar`: Implements a concentrated liquidity AMM.

### 2.3 Governance Module

- **Location**: `contracts/governance/`
- **Responsibility**: A comprehensive framework for decentralized decision-making and protocol upgrades.
- **Key Contracts**:
  - `proposal-engine.clar`: The core of the governance module, acting as a facade for all governance-related actions.
  - `proposal-registry.clar`: A specialized contract for storing and managing all governance proposals.
  - `voting.clar`: Manages the voting process for all proposals.

### 2.4 Lending Module

- **Location**: `contracts/lending/`
- **Responsibility**: The core infrastructure for decentralized lending and borrowing.
- **Key Contracts**:
  - `comprehensive-lending-system.clar`: The main contract for the lending module, managing user deposits, loans, and collateral.
  - `interest-rate-model.clar`: A specialized contract that calculates interest rates based on market conditions.
  - `liquidation-manager.clar`: A contract responsible for managing the liquidation process for under-collateralized loans.

---

## 3. Current Status

The Conxian Protocol is currently in the **Alpha** stage and is undergoing a comprehensive review to ensure the correctness, security, and alignment of all contracts and documentation. The codebase is not yet production-ready, and some features are still under development.
