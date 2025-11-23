;; SPDX-License-Identifier: TBD

;; Voting
;; This contract manages voting on proposals.
(define-trait voting-trait
  (
    ;; @desc Casts a vote on a proposal.
    ;; @param proposal-id uint The ID of the proposal to vote on.
    ;; @param support bool Whether the vote is for or against the proposal.
    ;; @param votes uint The number of votes to cast.
    ;; @param voter principal The address of the voter.
    ;; @returns (response bool uint) `(ok true)` on success.
    (vote (uint bool uint principal) (response bool uint))

    ;; @desc Retrieves a vote on a proposal by a specific voter.
    ;; @param proposal-id uint The ID of the proposal.
    ;; @param voter principal The address of the voter.
    ;; @returns (response (optional { ... }) uint) The vote details.
    (get-vote (uint principal)
      (response (optional {
        support: bool,
        votes: uint,
      })
        uint
      ))
  )
)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_ALREADY_VOTED u105)

;; --- Data Storage ---

;; @desc Stores the details of each vote, keyed by a tuple of proposal ID and voter principal.
(define-map votes
  {
    proposal-id: uint,
    voter: principal
  }
  {
    support: bool,
    votes: uint
  })

;; Contract references
(define-data-var proposal-engine-contract (optional principal) none)
(define-data-var contract-owner principal tx-sender)

;; --- Public Functions ---

(define-public (set-proposal-engine-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set proposal-engine-contract (some contract))
    (ok true)
  )
)

;; @desc Casts a vote on a proposal. Can only be called by the proposal engine.
;; @param proposal-id uint The ID of the proposal being voted on.
;; @param support bool A boolean indicating support (`true` for "for", `false` for "against").
;; @param votes-cast uint The number of votes being cast.
;; @param voter principal The principal of the user casting the vote.
;; @returns (response bool uint) `(ok true)` if the vote is successfully cast, otherwise an error.
(define-public (vote (proposal-id uint) (support bool) (votes-cast uint) (voter principal))
  (begin
    (asserts!
      (is-eq tx-sender
        (unwrap! (var-get proposal-engine-contract) (err ERR_UNAUTHORIZED))
      )
      (err ERR_UNAUTHORIZED)
    )
    (begin
      (asserts!
        (is-none (map-get? votes {
          proposal-id: proposal-id,
          voter: voter,
        }))
        (err ERR_ALREADY_VOTED)
      )

      (map-set votes {
        proposal-id: proposal-id,
        voter: voter,
      } {
        support: support,
        votes: votes-cast,
      })
      (ok true)
    )))

;; --- Read-Only Functions ---

;; @desc Retrieves the details of a specific vote.
;; @param proposal-id uint The ID of the proposal.
;; @param voter principal The principal of the voter.
;; @returns (response (optional { ... }) uint) An optional tuple containing the vote details.
(define-read-only (get-vote (proposal-id uint) (voter principal))
  (ok (map-get? votes { proposal-id: proposal-id, voter: voter })))
