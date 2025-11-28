# Contract Guide: `proposal-engine.clar`

**Primary Contract:** `contracts/governance/proposal-engine.clar`

## 1. Introduction

The `proposal-engine.clar` contract is the main entry point for the Conxian DAO's governance system. It acts as a facade, delegating all core logic to a set of specialized, single-responsibility contracts. This modular design enhances security and maintainability.

## 2. Core Architecture

The `proposal-engine` contract does not manage proposal data or voting logic directly. Instead, it delegates calls to the following specialized contracts:

-   **`proposal-registry.clar`**: Manages the creation, storage, and status of all governance proposals.
-   **`voting.clar`**: Manages the casting and tallying of votes on proposals.
-   **`governance-token.clar`**: The SIP-010 token that represents voting power in the DAO.

This architecture separates the core logic of the proposal engine from the more specialized tasks of proposal management and voting.

## 3. The Proposal Lifecycle

1.  **Creation:** A user creates a proposal by calling the `propose` function on the `proposal-engine`. This call is delegated to the `proposal-registry` to create a new proposal.
2.  **Active:** Once a proposal is created, it becomes active, and token holders can cast their votes by calling the `vote` function. This call is delegated to the `voting` contract.
3.  **Execution:** After the voting period has ended, if a proposal has met the quorum and has more "for" votes than "against" votes, it can be executed by calling the `execute` function.
4.  **Cancellation:** A proposal can be cancelled by its proposer or the contract owner by calling the `cancel` function.

## 4. How to Participate in Governance

### Creating a Proposal

-   **Function:** `propose`
-   **Parameters:**
    -   `description (string-ascii 256)`
    -   `targets (list 10 principal)`
    -   `values (list 10 uint)`
    -   `signatures (list 10 (string-ascii 64))`
    -   `calldatas (list 10 (buff 1024))`
    -   `start-block uint`
    -   `end-block uint`

### Casting a Vote

-   **Function:** `vote`
-   **Parameters:**
    -   `proposal-id uint`
    -   `support bool`
    -   `votes-cast uint`

### Executing a Proposal

-   **Function:** `execute`
-   **Parameters:**
    -   `proposal-id uint`

### Cancelling a Proposal

-   **Function:** `cancel`
-   **Parameters:**
    -   `proposal-id uint`

## 5. Admin Functions

| Function Name         | Parameters                | Description                                               |
| --------------------- | ------------------------- | --------------------------------------------------------- |
| `set-voting-period`   | `new-period uint`         | Sets the voting period in blocks.                         |
| `set-quorum-percentage` | `new-quorum uint`       | Sets the quorum percentage.                               |
| `transfer-ownership` | `new-owner principal`     | Transfers ownership of the contract.                      |
