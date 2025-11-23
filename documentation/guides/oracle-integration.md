# Oracle Integration Guide

## Overview

This document outlines the oracle system architecture and integration with the Conxian lending protocol. The oracle system provides a simple and secure way to manage price feeds for assets in the Conxian protocol.

## Oracle Contract

The primary oracle contract is `contracts/dex/oracle.clar`.

### Key Features

-   **Admin Controls:** The contract has a single admin who can set the price of any asset.
-   **Simple Price Storage:** The contract stores the price of each asset in a simple map.

### Key Functions

-   **`set-admin`**: Allows the current admin to set a new admin.
-   **`set-price`**: Allows the admin to set the price of an asset.
-   **`get-price`**: A read-only function that returns the price of a given asset.

## Integration with Lending System

The lending system integrates with the oracle to get the price of assets for calculating collateral value and health factors. This is done by calling the `get-price` function on the `oracle.clar` contract.

## Security Considerations

-   The oracle system is centralized, with a single admin who has complete control over the price of all assets. This is a potential security risk, and a more decentralized oracle system is planned for a future release.
-   The lending system should include checks to ensure that the price of an asset is not stale or outside of a reasonable range.

## Future Work

-   A more decentralized oracle system will be implemented in a future release. This will likely involve a multi-signature admin and the use of multiple price feed providers.
-   The oracle contract will be updated to include a timestamp for each price, to allow for staleness checks.
