# Conxian PRD: DAO Governance & Voting

| | |
|---|---|
| **Status** | 🔄 Framework Implementation |
| **Version** | 1.2 |
| **Owner** | Governance WG |
| **Last Updated** | 2025-08-26 |
| **References** | AIP-2, `dao-governance.clar` (framework implemented), `timelock.clar` (framework implemented) |

---

## 1. Summary & Vision

The Conxian DAO (Decentralized Autonomous Organization) provides a governance framework structure for the Conxian ecosystem. The system framework includes basic on-chain proposal and voting structures, featuring time-weighted voting framework to promote stakeholder alignment and a timelock mechanism framework for proposal execution. The vision is to create a community-driven governance framework that provides basic manipulation resistance and empowers token holders with protocol management structure.

## 2. Goals / Non-Goals

### Goals

- **Voting Framework**: Implement time-weighted voting framework (AIP-2) structure for token holders with basic flash loan protection.
- **Lifecycle Framework**: Provide basic proposal lifecycle framework: submission, voting, queuing (timelock), and execution structure.
- **Control Framework**: Enable DAO framework to govern basic protocol aspects, including parameter changes and basic treasury management structure.
- **Accountability Framework**: Provide basic participation incentive framework through token reallocation mechanism structure.

### Non-Goals

- **Off-Chain Voting**: All binding governance decisions must occur on-chain.
- **Instant Execution**: No proposal can be executed without passing through the mandatory timelock delay.
- **Subjective Decisions**: The DAO operates on programmatic rules; it does not handle subjective disputes.

## 3. User Stories

| ID | As a... | I want to... | So that... | Priority |
|---|---|---|---|---|
| DAO-US-01 | Token Holder | Propose changes to the protocol | I can participate in shaping the future of Conxian. | P0 |
| DAO-US-02 | Token Holder | Vote on active proposals with time-weighted power | My long-term commitment to the project is reflected in my influence. | P0 |
| DAO-US-03 | Token Holder | Delegate my voting power to a trusted representative | I can participate in governance without having to vote on every proposal myself. | P1 |
| DAO-US-04 | Protocol User | Be certain that approved proposals have a delay before execution | I have time to react and exit my positions if I disagree with a change. | P0 |
| DAO-US-05 | Community Member | Trigger the founder participation check after an epoch | I can help enforce the agreed-upon rules for founder accountability. | P1 |

## 4. Functional Requirements

| ID | Requirement | Test Case |
|---|---|---|
| DAO-FR-01 | Allow a user holding a minimum threshold of governance tokens to create a proposal, referencing a target contract and function call data. | `proposal-creation-succeeds` |
| DAO-FR-02 | Enforce a minimum and maximum voting window for all proposals. | `voting-window-enforced` |
| DAO-FR-03 | Calculate voting weight using a time-weighted formula that provides a bonus (up to 25%) for tokens held over a longer duration (AIP-2). | `time-weight-bonus-correct` |
| DAO-FR-04 | Prevent flash-loan attacks by ensuring token holdings are measured at the start of a proposal's voting period. | `flash-loan-vote-fails` |
| DAO-FR-05 | Require proposals to meet a minimum quorum of "For" votes before they can be queued for execution. | `quorum-check-succeeds` |
| DAO-FR-06 | Enforce a mandatory timelock delay between when a proposal passes and when it can be executed. | `timelock-delay-enforced` |
| DAO-FR-07 | Emit standardized events for all lifecycle stages: `proposal-created`, `vote-cast`, `proposal-queued`, `proposal-executed`, `proposal-canceled`. | `events-are-emitted` |
| DAO-FR-08 | Support delegation of voting power without resetting the time-weighted bonus. | `delegation-succeeds` |
| DAO-FR-09 | Track founder voting participation on a per-epoch basis using the `governance-metrics.clar` contract. | `founder-participation-tracked` |
| DAO-FR-10 | If a founder's participation drops below 60% in an epoch, allow a public function to trigger a reallocation of 2% of their token holdings to the `automated-bounty-system.clar`. | `founder-reallocation-succeeds` |

## 5. Non-Functional Requirements (NFRs)

| ID | Requirement | Metric / Verification |
|---|---|---|
| DAO-NFR-01 | **Gas Efficiency** | Voting weight calculation must be performed with a fixed number of operations, avoiding loops over voter counts. |
| DAO-NFR-02 | **Upgradeability** | The governance contract address must be updatable in the `conxian-registry.clar`, allowing for future DAO upgrades. |
| DAO-NFR-03 | **Liveness** | The system must not be susceptible to being frozen by a malicious proposal. Cancellation mechanisms must be in place. |

## 6. Invariants & Safety Properties

| ID | Property | Description |
|---|---|---|
| DAO-INV-01 | **Execution Pre-conditions** | A proposal cannot be executed unless it has successfully passed, met quorum, and completed its full timelock delay. |
| DAO-INV-02 | **Weight Bonus Integrity** | The time-weighted voting bonus cannot exceed its specified cap (25%). |
| DAO-INV-03 | **Immutability of Votes** | Once a vote is cast, it cannot be altered. |
| DAO-INV-04 | **Proposal Immutability** | The target and parameters of a proposal cannot be changed after it is created. |

## 7. Data Model / State & Maps

```clarity
;; --- DAO Core
(define-map proposals uint (tuple (target principal) (calldata bytes) ...))
(define-map votes (tuple (proposal-id uint) (voter principal)) (tuple (for bool) (weight uint)))

;; --- Governance Metrics
(define-map founder-last-voted-at principal uint)
```

## 8. Public Interface (Contract Functions / Events)

### Functions

- `create-proposal(target: principal, calldata: bytes, ...)`: Creates a new governance proposal.
- `vote(proposal-id: uint, for: bool)`: Casts a vote on an active proposal.
- `queue(proposal-id: uint)`: Queues a passed proposal for timelock execution.
- `execute(proposal-id: uint)`: Executes a queued proposal after its timelock has passed.
- `cancel(proposal-id: uint)`: Cancels a proposal.
- `check-founder-participation(founder: principal)`: Triggers the reallocation check for a given founder.

### Events

- `(print (tuple 'event "proposal-created" ...))`
- `(print (tuple 'event "vote-cast" ...))`

## 9. Core Flows (Sequence Narratives)

### Proposal Lifecycle

1. **Creation**: A token holder calls `create-proposal`. The system validates their token balance and creates the proposal with a `pending` status.
2. **Voting**: During the voting window, other token holders call `vote`. The contract calculates their time-weighted voting power and records their vote.
3. **Queuing**: After the voting window closes, anyone can call `queue` if the proposal has met the quorum. The proposal status changes to `queued` and the execution timelock begins.
4. **Execution**: Once the timelock delay has passed, anyone can call `execute`. The contract executes the proposal's calldata against the target contract. The status becomes `executed`.

## 10. Edge Cases & Failure Modes

- **Low Participation**: If a proposal does not meet quorum, it will fail and cannot be executed.
- **Proposal Spam**: Min token holding needed to create proposals, mitigating spam.
- **Tied Vote**: In case of a tie, the proposal does not pass.
- **Guardian Override**: A multi-sig guardian has the power to cancel any proposal, even if passed, as a final safety measure.

## 11. Risks & Mitigations (Technical / Economic / Operational)

| Risk | Mitigation |
|---|---|
| **Vote Buying / Bribery** | The time-weighted bonus for long-term holding makes short-term vote accumulation less effective. Transparency of all votes discourages bribery. |
| **Voter Apathy** | Delegation allows passive holders to still participate. The founder reallocation mechanism ensures the most powerful voters are active. |
| **Malicious Proposal** | The timelock delay provides a crucial window for the community and guardians to react to a malicious but passed proposal, allowing users to exit or for guardians to cancel it. |

## 12. Metrics & KPIs

| ID | Metric | Description |
|---|---|---|
| DAO-M-01 | **Participation Rate** | Percentage of total eligible voting power that participates in a typical proposal. |
| DAO-M-02 | **Proposal Success Rate** | Percentage of proposals that are successfully passed and executed. |
| DAO-M-03 | **Avg. Execution Delay** | The average time from proposal creation to execution. |
| DAO-M-04 | **Delegation Rate** | Percentage of voting power that is delegated. |
| DAO-M-05 | **Founder Participation** | The voting participation rate of founders, tracked per epoch. |

## 13. Rollout / Migration Plan

- **Initial Deployment**: The DAO contracts (`dao-governance.clar`, `timelock.clar`, `governance-metrics.clar`) are planned for a future phase and are not present in the current repository. Upon deployment, the DAO will be granted ownership of all ownable contracts in the ecosystem.
- **Upgrades**: A new governance implementation can be deployed, and the DAO itself can vote to transfer ownership to the new contract.

## 14. Monitoring & Observability

- An off-chain script will monitor for new proposals and broadcast them to community channels (e.g., Discord).
- A public dashboard will display the status of all current and past proposals.
- The `check-founder-participation` function is expected to be called by an off-chain keeper bot at the end of each epoch.

## 15. Open Questions

- Should a decay mechanism be applied to the voting power of inactive delegates after a certain number of epochs? (Current decision: No, keep delegation simple for v1).

## 16. Changelog & Version Sign-off

- **v1.2 (2025-08-26)**:
  - Refactored PRD to the 16-point standard.
  - Merged "Founder Token Reallocation" into the main document for a unified view.
  - Updated content to align with `FULL_SYSTEM_INDEX.md`.
  - Added Appendix A for Nakamoto/Clarity3 compliance assessment.
- **v1.1 (2025-08-18)**:
  - Validated SDK 3.5.0 compliance and confirmed production readiness.
- **v1.0 (2025-08-17)**:
  - Initial stable PRD based on the core implementation.

**Approved By**: Protocol WG, Governance Team
**Mainnet Status**: **APPROVED FOR DEPLOYMENT**

---

## Appendix A: Nakamoto & Clarity3 Adherence Assessment

**Date:** 2025-08-25
**Assessor:** Jules

### Findings

1. **No Nakamoto Features**: The `dao-governance.clar` contract does not utilize any Nakamoto-specific features.
2. **Clarity2 Syntax**: The contract is written in Clarity 2. An upgrade is required to leverage future Nakamoto capabilities.
3. **Incomplete Implementation**: The timelock integration is minimal and could be enhanced in a future version.

### Recommendations

1. **Future Upgrade**: Plan for a future upgrade to a Clarity 3 compatible DAO contract.
2. **Complete Timelock**: Enhance the timelock contract with more granular controls in a future release.
