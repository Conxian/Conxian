# Enterprise API Reference

This document provides a detailed API reference for the enterprise smart contracts, primarily `enterprise-api.clar` and `compliance-hooks.clar`.

## `enterprise-api.clar`

### Public Functions

#### `create-institutional-account`
*   **Description:** Creates a new institutional account.
*   **Parameters:**
    *   `owner` (principal): The owner of the new account.
    *   `tier-id` (uint): The tier level for the new account.
*   **Returns:** `(response uint)` - The ID of the newly created account.

#### `set-kyc-expiry`
*   **Description:** Sets the KYC expiry for an institutional account.
*   **Parameters:**
    *   `account-id` (uint): The ID of the account to update.
    *   `expiry` (optional uint): The block height when KYC expires.
*   **Returns:** `(response bool)`

---

## `compliance-hooks.clar`

### Public Functions

#### `set-kyc-tier`
*   **Description:** Sets the KYC tier for a given account.
*   **Parameters:**
    *   `account` (principal): The account to modify.
    *   `kyc-tier` (uint): The new KYC tier.
*   **Returns:** `(response bool)`

#### `is-verified`
*   **Description:** Checks if an account is currently verified.
*   **Parameters:**
    *   `account` (principal): The account to check.
*   **Returns:** `(bool)`
