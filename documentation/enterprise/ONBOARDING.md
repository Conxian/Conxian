# Conxian for Institutions & Developers: A Technical Onboarding Guide

This guide provides a technical overview of the Conxian protocol's enterprise features. It is intended for institutions, professional trading firms, and developers who wish to integrate with the system's advanced functionalities.

## Introduction to the Enterprise System

The Conxian enterprise system is a suite of smart contracts designed to provide institutional-grade features for DeFi. This includes advanced order types, compliance mechanisms, and tiered account structures. The core of this system is the `enterprise-api.clar` contract.

## Core Enterprise Features

*   **Institutional Accounts:** A distinct account system that allows for KYC verification, tiered access, and specific trading privileges.
*   **Advanced Order Types:**
    *   **Block Trades:** Execute large swaps in a single transaction.
    *   **TWAP (Time-Weighted Average Price) Orders:** Execute a large trade over a specified period to reduce market impact.
*   **Compliance Hooks:** An extensible system that allows the integration of external smart contracts for compliance checks, such as KYC/AML verification.
*   **Audit Trail:** On-chain logging of all significant actions, providing a transparent and immutable record of activity.

## Getting Started: Integrating with the Enterprise API

### 1. Account Creation and Configuration

All enterprise features are tied to an institutional account. These accounts can only be created by the contract owner.

1.  **Account Creation:** The contract owner calls `create-institutional-account`, providing the new account's owner principal and a tier ID.
2.  **Tier Configuration:** Each tier ID corresponds to a `tier-configuration` that defines fee discounts, trading volume limits, and other parameters. These are set by the contract owner using `set-tier-configuration`.
3.  **KYC and Privileges:**
    *   The contract owner can set a KYC expiry for an account using `set-kyc-expiry`.
    *   Specific trading privileges (e.g., for block trades or TWAP orders) are granted using a bitmask via `set-trading-privileges`.

### 2. Executing Advanced Orders

Once an institutional account is set up and has the necessary privileges, it can execute advanced order types.

*   **Block Trades:** The account owner can call `execute-block-trade`, specifying the tokens, amounts, and a slippage parameter.
*   **TWAP Orders:**
    1.  The account owner first creates the order with `create-twap-order`, defining the trade parameters and the start/end block height.
    2.  The order is then executed over time by calling `execute-twap-order` periodically.

### 3. Compliance and Verification

The enterprise system can be connected to a compliance contract.

*   The contract owner sets the address of the compliance contract using `set-compliance-hook`.
*   Once set, all trading functions in the `enterprise-api` will call the `is-verified` function in the compliance contract to ensure the user is authorized to trade.
*   A reference implementation of a compliance contract is available in `compliance-hooks.clar`. This contract includes the following functions:
    *   `set-kyc-tier`: Sets the KYC tier for a given account.
    *   `verify-account`: Verifies an account by setting its KYC tier to a basic level.
    *   `unverify-account`: Removes the verification for an account.
    *   `is-verified`: Checks if an account is currently verified.

##### `set-kyc-tier`
*   **Description:** Sets the KYC tier for a given account.
*   **Parameters:**
    *   `account` (principal): The account to modify.
    *   `kyc-tier` (uint): The new KYC tier.
*   **Returns:** `(response bool)`

##### `is-verified`
*   **Description:** Checks if an account is currently verified.
*   **Parameters:**
    *   `account` (principal): The account to check.
*   **Returns:** `(bool)`

## Security and Best Practices

*   **Contract Ownership:** The `enterprise-api.clar` contract has a single owner with significant privileges. It is critical that this ownership is managed securely, ideally through a multi-signature wallet or a DAO.
*   **Compliance Hooks:** The security and reliability of the compliance hook contract are paramount. Any bugs or vulnerabilities in the compliance contract could impact the entire enterprise system.
*   **Gas and Execution:** TWAP orders and other complex operations may require careful gas management and an understanding of the Stacks blockchain's execution costs.
