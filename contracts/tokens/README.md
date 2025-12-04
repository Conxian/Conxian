# Tokens Module

## Overview

The Tokens Module provides the core token functionality for the Conxian Protocol. It includes the implementation of the Conxian Revenue Token (CXD), a SIP-010 compliant fungible token, as well as other utility tokens. The module is designed to be secure and robust, with features such as access controls, transfer restrictions, and emergency pauses.

## Contracts

- **`cxd-token.clar`**: The primary token of the Conxian ecosystem, this contract implements the Conxian Revenue Token (CXD). It includes functions for transferring, minting, and burning tokens, as well as for managing ownership and administrative privileges.

- **`cxlp-token.clar`**: A liquidity provider token representing a share in a DEX liquidity pool.

- **`cxs-token.clar`**: A stability token for lending and borrowing operations.

- **`cxtr-token.clar`**: A treasury reserve token for protocol stability.

- **`cxvg-token.clar`**: A governance utility token for protocol upgrades.

- **`token-system-coordinator.clar`**: A contract for coordinating the interactions between the various tokens in the ecosystem.

## Architecture

The Tokens Module is designed to be modular and extensible. The `cxd-token.clar` contract is the core component, providing the basic functionality of a SIP-010 compliant token. The other contracts in the module provide specialized functionality for liquidity provision, governance, and other aspects of the protocol.

## Status

**Under Development**: The contracts in this module are currently under development and are not yet considered production-ready. While the core functionality of the `cxd-token.clar` contract is implemented, several of the integration hooks are disabled, and some of the other contracts in the module are not yet fully implemented.
