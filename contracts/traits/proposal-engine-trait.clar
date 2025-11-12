;; ===========================================
;; PROPOSAL ENGINE TRAIT
;; ===========================================
;; Interface for a proposal engine.
;;
;; This trait provides functions for creating, voting on, and executing proposals.
;;
;; Example usage:
;;   (use-trait proposal-engine .proposal-engine-trait)
(define-trait proposal-engine-trait
  (
    ;; Propose a new action.
    ;; @param title: title of the proposal
    ;; @param description: description of the proposal
    ;; @param start-block: block number when voting starts
    ;; @param end-block: block number when voting ends
    ;; @param contract-call: contract call to execute if proposal passes
    ;; @return (response uint uint): proposal ID and error code
    (propose ((string-ascii 256) (string-utf8 1024) uint uint (tuple (contract principal) (function (string-ascii 64)) (args (list 10 (buff 1024))))) (response uint uint))

    ;; Vote on an existing proposal.
    ;; @param proposal-id: ID of the proposal
    ;; @param in-favor: true for 'yes', false for 'no'
    ;; @return (response bool uint): success flag and error code
    (vote (uint bool) (response bool uint))

    ;; Execute a passed proposal.
    ;; @param proposal-id: ID of the proposal
    ;; @return (response bool uint): success flag and error code
    (execute (uint) (response bool uint))

    ;; Get proposal details.
    ;; @param proposal-id: ID of the proposal
    ;; @return (response (tuple ...) uint): proposal details and error code
    (get-proposal (uint) (response (tuple (title (string-ascii 256)) (description (string-utf8 1024)) (proposer principal) (start-block uint) (end-block uint) (votes-for uint) (votes-against uint) (executed bool) (passed bool)) uint))
  )
)
