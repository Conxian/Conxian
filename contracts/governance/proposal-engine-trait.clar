;; SPDX-License-Identifier: TBD

;; Trait for a Proposal Engine
;; This trait defines the standard interface for a proposal engine contract.
(define-trait proposal-engine-trait
  (
    ;; @desc Creates a new proposal.
    ;; @param description (string-ascii 256) A human-readable description of the proposal.
    ;; @param targets (list 10 principal) A list of contract principals to be called if the proposal is executed.
    ;; @param values (list 10 uint) A list of STX amounts to be sent with each call.
    ;; @param signatures (list 10 (string-ascii 64)) A list of function signatures to be called on the target contracts.
    ;; @param calldatas (list 10 (buff 1024)) A list of calldata to be passed to each function call.
    ;; @param start-block uint The block height at which the voting period begins.
    ;; @param end-block uint The block height at which the voting period ends.
    ;; @returns (response uint uint) A response containing the ID of the newly created proposal, or an error.
    (propose ((string-ascii 256), (list 10 principal), (list 10 uint), (list 10 (string-ascii 64)), (list 10 (buff 1024)), uint, uint) (response uint uint))

    ;; @desc Casts a vote on an active proposal.
    ;; @param proposal-id uint The ID of the proposal to vote on.
    ;; @param support bool A boolean indicating the voter's support for the proposal (`true` for "for", `false` for "against").
    ;; @param votes uint The number of votes to cast, based on the voter's token holdings.
    ;; @returns (response bool uint) A response indicating `(ok true)` on a successful vote, or an error.
    (vote (uint, bool, uint) (response bool uint))

    ;; @desc Executes a proposal that has successfully passed the voting process.
    ;; @param proposal-id uint The ID of the proposal to execute.
    ;; @returns (response bool uint) A response indicating `(ok true)` on successful execution, or an error.
    (execute (uint) (response bool uint))

    ;; @desc Cancels a proposal.
    ;; @param proposal-id uint The ID of the proposal to cancel.
    ;; @returns (response bool uint) A response indicating `(ok true)` on successful cancellation, or an error.
    (cancel (uint) (response bool uint))

    ;; @desc Retrieves the details of a proposal.
    ;; @param proposal-id uint The ID of the proposal.
    ;; @returns (response (optional { ... }) (err uint)) A response containing an optional tuple with the proposal's details, or an error if not found.
    (get-proposal (uint) (response (optional { proposer: principal, start-block: uint, end-block: uint, for-votes: uint, against-votes: uint, executed: bool, canceled: bool, description: (string-ascii 256) }) (err uint)))

    ;; @desc Retrieves the details of a specific vote on a proposal.
    ;; @param proposal-id uint The ID of the proposal.
    ;; @param voter principal The principal of the voter.
    ;; @returns (response (optional { ... }) (err uint)) A response containing an optional tuple with the vote's details, or an error if not found.
    (get-vote (uint, principal) (response (optional { support: bool, votes: uint }) (err uint)))
  )
)
