;; ===========================================
;; DAO TRAIT
;; ===========================================
;; @desc Interface for Decentralized Autonomous Organization (DAO) functionality.
;; This trait provides functions for proposal submission, voting, and execution,
;; enabling decentralized governance of the protocol.
;;
;; @example
;; (use-trait dao .dao-trait.dao-trait)
(define-trait dao-trait
  (
    ;; @desc Submit a new proposal.
    ;; @param proposal-hash: The hash of the proposal details.
    ;; @param proposer: The principal of the proposer.
    ;; @param start-block: The block at which voting starts.
    ;; @param end-block: The block at which voting ends.
    ;; @returns (response uint uint): The ID of the newly created proposal, or an error code.
    (submit-proposal ((buff 32) principal uint uint) (response uint uint))

    ;; @desc Vote on an existing proposal.
    ;; @param proposal-id: The ID of the proposal.
    ;; @param vote: True for 'for', false for 'against'.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (vote (uint bool) (response bool uint))

    ;; @desc Execute a passed proposal.
    ;; @param proposal-id: The ID of the proposal.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (execute-proposal (uint) (response bool uint))

    ;; @desc Get the details of a specific proposal.
    ;; @param proposal-id: The ID of the proposal.
    ;; @returns (response (tuple ...) uint): A tuple containing the proposal details, or an error code.
    (get-proposal (uint) (response (tuple (proposal-hash (buff 32)) (proposer principal) (start-block uint) (end-block uint) (for-votes uint) (against-votes uint) (executed bool)) uint))

    ;; @desc Get the voting power of a principal.
    ;; @param voter: The principal to check.
    ;; @returns (response uint uint): The voting power of the principal, or an error code.
    (get-voting-power (principal) (response uint uint))
  )
)
