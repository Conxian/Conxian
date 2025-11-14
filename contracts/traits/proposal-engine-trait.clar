;; ===========================================
;; PROPOSAL ENGINE TRAIT
;; ===========================================
;; @desc Interface for a proposal engine.
;; This trait provides functions for creating, voting on, and executing proposals.
;;
;; @example
;; (use-trait proposal-engine .proposal-engine-trait)
(define-trait proposal-engine-trait
  (
    ;; @desc Propose a new action.
    ;; @param title: The title of the proposal.
    ;; @param description: A description of the proposal.
    ;; @param start-block: The block number when voting starts.
    ;; @param end-block: The block number when voting ends.
    ;; @param contract-call: The contract call to execute if the proposal passes.
    ;; @returns (response uint uint): The ID of the newly created proposal, or an error code.
    (propose ((string-ascii 256) (string-utf8 1024) uint uint (tuple (contract principal) (function (string-ascii 64)) (args (list 10 (buff 1024))))) (response uint uint))

    ;; @desc Vote on an existing proposal.
    ;; @param proposal-id: The ID of the proposal.
    ;; @param in-favor: True for 'yes', false for 'no'.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (vote (uint bool) (response bool uint))

    ;; @desc Execute a passed proposal.
    ;; @param proposal-id: The ID of the proposal.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (execute (uint) (response bool uint))

    ;; @desc Get the details of a specific proposal.
    ;; @param proposal-id: The ID of the proposal.
    ;; @returns (response (tuple ...) uint): A tuple containing the proposal details, or an error code.
    (get-proposal (uint) (response (tuple (title (string-ascii 256)) (description (string-utf8 1024)) (proposer principal) (start-block uint) (end-block uint) (votes-for uint) (votes-against uint) (executed bool) (passed bool)) uint))
  )
)
