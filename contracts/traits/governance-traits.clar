;; ===========================================
;; GOVERNANCE TRAITS MODULE
;; ===========================================
;; @desc Governance and voting specific traits.
;; Designed for secure proposal execution.

;; ===========================================
;; DAO TRAIT
;; ===========================================
;; @desc Interface for a Decentralized Autonomous Organization (DAO).
(define-trait dao-trait
  (
    ;; @desc Propose a new governance action.
    ;; @param title: The title of the proposal.
    ;; @param description: A description of the proposal.
    ;; @returns (response uint uint): The ID of the newly created proposal, or an error code.
    (propose ((string-utf8 256) (string-utf8 1024)) (response uint uint))

    ;; @desc Vote on a proposal.
    ;; @param proposal-id: The ID of the proposal to vote on.
    ;; @param vote: The vote, where 1 is for and 0 is against.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (vote (uint uint) (response bool uint))

    ;; @desc Execute a passed proposal.
    ;; @param proposal-id: The ID of the proposal to execute.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (execute-proposal (uint) (response bool uint))

    ;; @desc Get the details of a specific proposal.
    ;; @param proposal-id: The ID of the proposal to retrieve.
    ;; @returns (response (optional { ... }) uint): A tuple containing the proposal details, or none if the proposal is not found.
    (get-proposal (uint) (response (optional {
      proposer: principal,
      title: (string-utf8 256),
      description: (string-utf8 1024),
      start-block: uint,
      end-block: uint,
      for-votes: uint,
      against-votes: uint,
      state: uint
    }) uint))
  )
)

;; ===========================================
;; GOVERNANCE TOKEN TRAIT
;; ===========================================
;; @desc Interface for a governance token.
(define-trait governance-token-trait
  (
    ;; @desc Get the voting power of a principal.
    ;; @param user: The principal to check.
    ;; @returns (response uint uint): The voting power of the principal, or an error code.
    (get-voting-power (principal) (response uint uint))

    ;; @desc Get the voting power of a principal at a specific block height.
    ;; @param user: The principal to check.
    ;; @param block-height: The block height to check the voting power at.
    ;; @returns (response uint uint): The voting power of the principal at the specified block height, or an error code.
    (get-voting-power-at (principal uint) (response uint uint))

    ;; @desc Delegate voting power to another principal.
    ;; @param delegatee: The principal to delegate to.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (delegate (principal) (response bool uint))

    ;; @desc Mint new governance tokens.
    ;; @param recipient: The principal to receive the minted tokens.
    ;; @param amount: The number of tokens to mint.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (mint (principal uint) (response bool uint))
  )
)
