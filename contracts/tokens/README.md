# Tokens Module

## Overview

The Tokens Module provides the core token functionality for the Conxian Protocol. It includes the implementation of the Conxian Revenue Token (CXD), a SIP-010 compliant fungible token, as well as other utility tokens. The module is designed to be secure and robust, with features such as access controls, transfer restrictions, and emergency pauses.

## Contracts

- **`cxd-token.clar`**: The primary token of the Conxian ecosystem, this contract implements the Conxian Revenue Token (CXD). It includes functions for transferring, minting, and burning tokens, as well as for managing ownership and administrative privileges. It also includes a number of integration hooks for connecting to other contracts in the Conxian ecosystem, such as the `token-system-coordinator.clar` and the `protocol-fee-switch.clar`.

- **`cxlp-token.clar`**: A liquidity provider token representing a share in a DEX liquidity pool. This contract includes a migration mechanism to convert CXLP tokens to the primary CXD token.

- **`cxs-token.clar`**: A stability token for lending and borrowing operations. This is a SIP-009 compliant non-fungible token, where each NFT represents a unique staked position in the Conxian protocol.

- **`cxtr-token.clar`**: A treasury reserve token for protocol stability. This contract includes a merit-based rewards system for creators.

- **`cxvg-token.clar`**: A governance utility token for protocol upgrades.

- **`token-system-coordinator.clar`**: A contract for coordinating the interactions between the various tokens in the ecosystem. It provides a unified interface for tracking token operations, managing user reputations, and triggering revenue distribution.

- **`cxd-price-initializer.clar`**: A contract for initializing the price of the CXD token.

- **`cxlp-position-nft.clar`**: A SIP-009 compliant non-fungible token that represents a user's position in a liquidity pool.

## Architecture

The Tokens Module is designed to be modular and extensible. The `cxd-token.clar` contract is the core component, providing the basic functionality of a SIP-010 compliant token. The other contracts in the module provide specialized functionality for liquidity provision, governance, and other aspects of the protocol. The `token-system-coordinator.clar` contract provides a unified interface for managing the interactions between the various tokens in the ecosystem.

## Status

**Under Development**: The contracts in this module are currently under development and are not yet considered production-ready. While the core functionality of the `cxd-token.clar` contract is implemented, several of the integration hooks are disabled, and some of the other contracts in the module are not yet fully implemented.
