;; SPDX-License-Identifier: TBD

;; Proposal Registry
;; This contract stores and manages proposal data.
(define-trait proposal-registry-trait
  (
    ;; @desc Creates a new proposal.
    ;; @param proposer principal The address of the proposer.
    ;; @param description (string-ascii 256) A description of the proposal.
    ;; @param start-block uint The block height at which voting starts.
    ;; @param end-block uint The block height at which voting ends.
    ;; @returns (response uint uint) The ID of the new proposal.
    (create-proposal (principal (string-ascii 256) uint uint)
      (response uint uint)
    )

    ;; @desc Updates the vote counts for a proposal.
    ;; @param proposal-id uint The ID of the proposal.
    ;; @param for-votes uint The number of "for" votes.
    ;; @param against-votes uint The number of "against" votes.
    ;; @returns (response bool uint) `(ok true)` on success.
    (update-votes (uint uint uint) (response bool uint))

    ;; @desc Marks a proposal as executed.
    ;; @param proposal-id uint The ID of the proposal.
    ;; @returns (response bool uint) `(ok true)` on success.
    (set-executed (uint) (response bool uint))

    ;; @desc Marks a proposal as canceled.
    ;; @param proposal-id uint The ID of the proposal.
    ;; @returns (response bool uint) `(ok true)` on success.
    (set-canceled (uint) (response bool uint))

    ;; @desc Retrieves a proposal by its ID.
    ;; @param proposal-id uint The ID of the proposal.
    ;; @returns (response (optional { ... }) uint) The proposal details.
    (get-proposal (uint)
      (response
        (optional {
          proposer: principal,
          start-block: uint,
          end-block: uint,
          for-votes: uint,
          against-votes: uint,
          executed: bool,
          canceled: bool,
          description: (string-ascii 256),
        })
        uint
      ))
  )
)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_PROPOSAL_NOT_FOUND u101)

;; --- Data Storage ---

;; @desc Stores the details of each proposal, keyed by proposal ID.
(define-map proposals
  { id: uint }
  {
    proposer: principal,
    start-block: uint,
    end-block: uint,
    for-votes: uint,
    against-votes: uint,
    executed: bool,
    canceled: bool,
    description: (string-ascii 256)
  })

;; @desc A counter for the next proposal ID.
(define-data-var next-proposal-id uint u1)

;; Contract references
(define-data-var proposal-engine-contract (optional principal) none)
(define-data-var voting-contract (optional principal) none)
(define-data-var contract-owner principal tx-sender)

;; --- Public Functions ---

(define-public (set-proposal-engine-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set proposal-engine-contract (some contract))
    (ok true)
  )
)

(define-public (set-voting-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set voting-contract (some contract))
    (ok true)
  )
)

;; @desc Creates a new proposal. Can only be called by the proposal engine.
;; @param proposer principal The address of the user creating the proposal.
;; @param description (string-ascii 256) A description of the proposal.
;; @param start-block uint The block height at which voting begins.
;; @param end-block uint The block height at which voting ends.
;; @returns (response uint uint) The ID of the newly created proposal.
(define-public (create-proposal (proposer principal) (description (string-ascii 256)) (start-block uint) (end-block uint))
  (begin
    (asserts!
      (is-eq tx-sender
        (unwrap! (var-get proposal-engine-contract) (err ERR_UNAUTHORIZED))
      )
      (err ERR_UNAUTHORIZED)
    )
    (let ((proposal-id (var-get next-proposal-id)))
      (map-set proposals
        { id: proposal-id }
        {
          proposer: proposer,
          start-block: start-block,
          end-block: end-block,
          for-votes: u0,
          against-votes: u0,
          executed: false,
          canceled: false,
          description: description
        })
      (var-set next-proposal-id (+ proposal-id u1))
      (ok proposal-id))))

;; @desc Updates the vote counts for a proposal. Can only be called by the voting contract.
;; @param proposal-id uint The ID of the proposal to update.
;; @param for-votes uint The new total of "for" votes.
;; @param against-votes uint The new total of "against" votes.
;; @returns (response bool uint) `(ok true)` if the update is successful.
(define-public (update-votes (proposal-id uint) (for-votes uint) (against-votes uint))
  (begin
    (asserts! (is-eq tx-sender (unwrap! (var-get voting-contract) (err ERR_UNAUTHORIZED))) (err ERR_UNAUTHORIZED))
    (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) (err ERR_PROPOSAL_NOT_FOUND))))
      (map-set proposals { id: proposal-id } (merge proposal { for-votes: for-votes, against-votes: against-votes }))
      (ok true))))

;; @desc Marks a proposal as executed. Can only be called by the proposal engine.
;; @param proposal-id uint The ID of the proposal to mark as executed.
;; @returns (response bool uint) `(ok true)` if successful.
(define-public (set-executed (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (unwrap! (var-get proposal-engine-contract) (err ERR_UNAUTHORIZED))) (err ERR_UNAUTHORIZED))
    (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) (err ERR_PROPOSAL_NOT_FOUND))))
      (map-set proposals { id: proposal-id } (merge proposal { executed: true }))
      (ok true))))

;; @desc Marks a proposal as canceled. Can only be called by the proposal engine.
;; @param proposal-id uint The ID of the proposal to mark as canceled.
;; @returns (response bool uint) `(ok true)` if successful.
(define-public (set-canceled (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (unwrap! (var-get proposal-engine-contract) (err ERR_UNAUTHORIZED))) (err ERR_UNAUTHORIZED))
    (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) (err ERR_PROPOSAL_NOT_FOUND))))
      (map-set proposals { id: proposal-id } (merge proposal { canceled: true }))
      (ok true))))

;; --- Read-Only Functions ---

;; @desc Retrieves the details of a proposal.
;; @param proposal-id uint The ID of the proposal.
;; @returns (response (optional { ... }) uint) An optional tuple containing the proposal details.
(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals { id: proposal-id })))
