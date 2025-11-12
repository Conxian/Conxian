;; ===========================================
;; DAO TRAIT
;; ===========================================
;; Interface for Decentralized Autonomous Organization (DAO) functionality
;;
;; This trait provides functions for proposal submission, voting, and execution,
;; enabling decentralized governance of the protocol.
;;
;; Example usage:
;;   (use-trait dao .dao-trait.dao-trait)
(define-trait dao-trait
  (
    ;; Submit a new proposal
    ;; @param proposal-hash: hash of the proposal details
    ;; @param proposer: principal of the proposer
    ;; @param start-block: block at which voting starts
    ;; @param end-block: block at which voting ends
    ;; @return (response uint uint): proposal ID and error code
    (submit-proposal ((buff 32) principal uint uint) (response uint uint))

    ;; Vote on an existing proposal
    ;; @param proposal-id: ID of the proposal
    ;; @param vote: true for 'for', false for 'against'
    ;; @return (response bool uint): success flag and error code
    (vote (uint bool) (response bool uint))

    ;; Execute a passed proposal
    ;; @param proposal-id: ID of the proposal
    ;; @return (response bool uint): success flag and error code
    (execute-proposal (uint) (response bool uint))

    ;; Get proposal details
    ;; @param proposal-id: ID of the proposal
    ;; @return (response (tuple ...) uint): proposal details and error code
    (get-proposal (uint) (response (tuple (proposal-hash (buff 32)) (proposer principal) (start-block uint) (end-block uint) (for-votes uint) (against-votes uint) (executed bool)) uint))

    ;; Get voting power of a principal
    ;; @param voter: principal to check
    ;; @return (response uint uint): voting power and error code
    (get-voting-power (principal) (response uint uint))
  )
)
