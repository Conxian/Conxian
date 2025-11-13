# Contract Guide: `proposal-engine.clar`

**Primary Contract:** `contracts/governance/proposal-engine.clar`

## 1. Introduction

The `proposal-engine.clar` contract is the core of the Conxian DAO's governance system. It allows holders of the governance token to create and vote on proposals that can modify the protocol.

## 2. Key Concepts

### Governance Token

-   The governance token (not specified in this contract, but assumed to be `.governance-token`) represents voting power. The more tokens a user holds, the more weight their vote carries.

### Proposals

-   Proposals are created by users and contain a description of the proposed changes, as well as the code to be executed if the proposal passes.

### Voting

-   Token holders can vote for or against proposals. A user's voting power is proportional to the number of governance tokens they hold.

### Quorum

-   For a vote to be considered valid, a minimum percentage of the total governance token supply must participate in the vote. This is known as the quorum.

### Voting Period

-   Proposals are active for a specific number of blocks, defined by the `voting-period-blocks` variable.

## 3. The Proposal Lifecycle

1.  **Creation:** A user creates a proposal, providing a description and the code to be executed.
2.  **Active:** The proposal is active and token holders can cast their votes.
3.  **Execution:** If a proposal meets the quorum and has more "for" votes than "against" votes after the voting period ends, it can be executed.
4.  **Cancellation:** A proposal can be cancelled by its proposer or the contract owner.

## 4. How to Participate in Governance

### Creating a Proposal

-   **Function:** `propose`
-   **Parameters:**
    -   `description (string-ascii 256)`: A description of the proposal.
    -   `targets (list 10 principal)`: A list of contracts the proposal will call.
    -   `values (list 10 uint)`: A list of values to pass to the functions.
    -   `signatures (list 10 (string-ascii 64))`: A list of function signatures to be called.
    -   `calldatas (list 10 (buff 1024))`: A list of calldata to pass to the functions.
    -   `start-block uint`: The block height at which voting begins.
    -   `end-block uint`: The block height at which voting ends.

### Casting a Vote

-   **Function:** `vote`
-   **Parameters:**
    -   `proposal-id uint`: The ID of the proposal to vote on.
    -   `support bool`: Your vote: `true` for For, `false` for Against.
    -   `votes uint`: The number of votes to cast.

### Executing a Proposal

-   **Function:** `execute`
-   **Parameters:**
    -   `proposal-id uint`: The ID of the proposal to execute.

### Cancelling a Proposal

-   **Function:** `cancel`
-   **Parameters:**
    -   `proposal-id uint`: The ID of the proposal to cancel.

## 5. Admin Functions

| Function Name         | Parameters                | Description                                               |
| --------------------- | ------------------------- | --------------------------------------------------------- |
| `set-voting-period`   | `new-period uint`         | Sets the voting period in blocks.                         |
| `set-quorum-percentage` | `new-quorum uint`       | Sets the quorum percentage.                               |
| `transfer-ownership` | `new-owner principal`     | Transfers ownership of the contract.                      |

## 6. Read-Only Functions

| Function Name       | Parameters                          | Returns                               | Description                                                     |
| ------------------- | ----------------------------------- | ------------------------------------- | --------------------------------------------------------------- |
| `get-proposal`      | `proposal-id uint`                  | `(optional proposal-tuple)`           | Retrieves all data for a specific proposal.                     |
| `get-vote`          | `proposal-id uint`, `voter principal` | `(optional vote-tuple)`               | Retrieves the vote and weight for a specific voter on a proposal. |

## 7. Error Codes

| Code   | Description                       |
| ------ | --------------------------------- |
| `u100` | Unauthorized.                     |
| `u101` | Proposal not found.               |
| `u102` | Proposal already active.          |
| `u103` | Proposal not active.              |
| `u104` | Voting closed.                    |
| `u105` | Already voted.                    |
| `u106` | Quorum not reached.               |
| `u107` | Proposal failed.                  |
| `u108` | Invalid amount.                   |
| `u109` | Invalid voting period.            |
