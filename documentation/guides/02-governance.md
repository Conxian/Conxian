# Contract Guide: `dao-governance.clar`

**Primary Contract:** `contracts/dao-governance.clar`

## 1. Introduction

Decentralized governance is a critical component of the Conxian ecosystem, ensuring that the protocol is managed by its community of stakeholders. The `dao-governance.clar` contract is the engine of this system. It allows holders of the governance token (`.CXVG`) to create proposals, vote on them, and execute approved changes on-chain in a transparent and permissionless manner.

The contract manages the entire lifecycle of a proposal, from creation to execution, and includes features like vote delegation and time-weighted voting to promote fair and robust decision-making.

## 2. Key Concepts

### Governance Token

-   **`.CXVG`**: The SIP-010 token that represents voting power in the DAO. The more tokens a user holds, the more weight their vote carries.

### Proposal Threshold

-   A user must hold a minimum number of governance tokens (`PROPOSAL_THRESHOLD`) to be able to create a new proposal. This prevents spam and ensures that proposers are significantly invested in the protocol.

### Quorum

-   For a vote to be considered valid, a minimum percentage of the total governance token supply must participate in the vote. This is known as the quorum (`QUORUM_BPS`). If the quorum is not met, the proposal cannot pass, even if it has more "for" votes than "against" votes.

### Time-Weighted Voting (CXIP-2)

-   To reward long-term token holders and mitigate the influence of flash-loan-acquired voting power, the DAO uses a time-weighted voting system. The longer a user has held their tokens, the more voting power they have. This encourages long-term alignment with the protocol's success.

### Execution Delay

-   Even after a proposal has successfully passed, there is a mandatory waiting period (`EXECUTION_DELAY`) before it can be executed. This delay acts as a crucial security measure, giving users time to react to and potentially exit the system if they disagree with a passed proposal.

### Emergency Multisig

-   For critical situations that require immediate action, a designated `emergency-multisig` address has the power to bypass the standard governance process and perform emergency actions, such as pausing the vault.

## 3. The Proposal Lifecycle

A proposal moves through several states from its creation to its final execution or failure.

1.  **Pending:** The proposal has been created but the voting period has not yet begun.
2.  **Active:** The voting period is live. Token holders can cast their votes.
3.  **Succeeded:** The voting period has ended, the quorum was met, and the "for" votes outnumbered the "against" votes.
4.  **Defeated:** The voting period has ended, and either the quorum was not met or the "against" votes were greater than or equal to the "for" votes.
5.  **Queued:** A successful proposal has been queued for execution. The `EXECUTION_DELAY` period begins.
6.  **Executed:** The proposal's on-chain instructions have been successfully carried out.
7.  **Cancelled:** The proposal has been cancelled (logic for this is not explicitly in the base contract but could be added).

## 4. How to Participate in Governance

### Creating a Proposal

Any user holding at least `100,000` `.CXVG` can create a proposal.

-   **Function:** `create-proposal`
-   **Parameters:**
    -   `title (string-utf8 100)`: A short, human-readable title.
    -   `description (string-utf8 500)`: A detailed description of the proposal.
    -   `proposal-type uint`: The type of proposal (see table below).
    -   `target-contract principal`: The contract the proposal will call.
    -   `function-name (string-ascii 50)`: The function to be called on the target contract.
    -   `parameters (list 10 uint)`: A list of parameters to pass to the function.

**Proposal Types:**

| Type ID | Name               | Description                                           |
| ------- | ------------------ | ----------------------------------------------------- |
| `u0`    | `PARAM_CHANGE`     | Change a parameter in a core contract (e.g., set fees in the vault). |
| `u1`    | `TREASURY_SPEND`   | Authorize spending from the DAO treasury.             |
| `u2`    | `EMERGENCY_ACTION` | An emergency action (currently not implemented in the execution logic). |
| `u3`    | `BOUNTY_CREATION`  | Create a new bounty in the bounty system.             |
| `u4`    | `CONTRACT_UPGRADE` | Upgrade a contract (logic to be implemented).         |

### Casting a Vote

Once a proposal is active, any holder of the `.CXVG` can vote.

-   **Function:** `cast-vote`
-   **Parameters:**
    -   `proposal-id uint`: The ID of the proposal to vote on.
    -   `vote uint`: Your vote: `u0` for Against, `u1` for For, `u2` for Abstain.

### Delegating Votes

You can delegate your voting power to another user if you trust their judgment or do not wish to vote directly.

-   **Function:** `delegate-vote`
-   **Parameters:**
    -   `delegate principal`: The address of the user you want to delegate your voting power to.

## 5. Executing a Proposal

After a proposal has succeeded and the execution delay has passed, anyone can call the `execute-proposal` function to enact the change.

-   **Function:** `queue-proposal`: Moves a `Succeeded` proposal to the `Queued` state and starts the execution delay timer.
-   **Function:** `execute-proposal`: Executes the proposal's logic if it is in the `Queued` state and the delay has passed.

## 6. Read-Only Functions

| Function Name       | Parameters                          | Returns                               | Description                                                     |
| ------------------- | ----------------------------------- | ------------------------------------- | --------------------------------------------------------------- |
| `get-proposal`      | `id uint`                           | `(optional proposal-tuple)`           | Retrieves all data for a specific proposal.                     |
| `get-vote`          | `proposal-id uint`, `voter principal` | `(optional vote-tuple)`               | Retrieves the vote and weight for a specific voter on a proposal. |
| `get-delegation`    | `delegator principal`               | `(optional delegate-tuple)`           | Shows who a user has delegated their vote to.                   |
| `get-proposal-state`| `id uint`                           | `uint`                                | Returns the current calculated state of a proposal.             |
| `get-voting-power`  | `who principal`, `block-height-ref uint` | `uint`                                | Calculates the voting power of a user at a specific block height. |

## 7. Error Codes

| Code   | Description                       |
| ------ | --------------------------------- |
| `u100` | Unauthorized.                     |
| `u101` | Insufficient balance to create a proposal. |
| `u102` | Proposal not found.               |
| `u103` | Proposal is not in the active voting period. |
| `u104` | Invalid vote value (must be 0, 1, or 2). |
| `u105` | User has already voted on this proposal. |
| `u106` | Cannot delegate to yourself.      |
| `u107` | Proposal has not succeeded.       |
| `u108` | Proposal is not queued for execution. |
| `u109` | Execution delay has not yet passed. |
| `u110` | Unsupported proposal type.        |
| `u111` | Execution of the proposal failed. |
| `u409` | Insufficient holding period for time-weighted voting. |
| `u500` | Error fetching token balance.     |
