;;
;; @title Proposal Engine
;; @author Conxian Protocol
;; @desc This contract serves as the central governance facade, providing a unified
;; interface for creating, voting on, and executing proposals. It delegates the
;; underlying logic to specialized contracts, such as `proposal-registry` for
;; storing proposal data and `voting` for managing the voting process. This
;; modular design enhances security and maintainability by separating concerns,
;; allowing individual components to be upgraded independently.
;;

(use-trait protocol-support-trait .core-traits.protocol-support-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant PROPOSAL_DELAY u2073600) ;; Nakamoto-adjusted: 1 day (144 blocks * 120)
(define-constant VOTING_PERIOD u14515200) ;; Nakamoto-adjusted: 7 days (1008 blocks * 120)
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u103))
(define-constant ERR_VOTING_CLOSED (err u104))
(define-constant ERR_QUORUM_NOT_REACHED (err u106))
(define-constant ERR_PROPOSAL_FAILED (err u107))
(define-constant ERR_INVALID_VOTING_PERIOD (err u109))
(define-constant ERR_PROTOCOL_PAUSED (err u5001))
;; Minimum allowed quorum percentage (10% expressed in basis points of 10000)
(define-constant MIN_QUORUM u1000)

;; --- Data Variables ---

;; @desc The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @desc The principal of the proposal registry contract.
(define-data-var proposal-registry principal .proposal-registry)
;; @desc The principal of the voting contract.
(define-data-var voting principal .governance-voting)
;; @desc The principal of the governance token contract.
(define-data-var governance-token principal .governance-token)
;; @desc The duration of the voting period in blocks.
(define-data-var voting-period-blocks uint u20736000)
;; @desc The percentage of the total token supply that must vote for a proposal to pass, multiplied by 100.
(define-data-var quorum-percentage uint u5000)
(define-data-var protocol-coordinator principal tx-sender)

(define-private (is-protocol-paused)
  (contract-call? (var-get protocol-coordinator) is-protocol-paused)
)

;; --- Authorization ---

;; @desc Asserts that the transaction sender is the contract owner.
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Public Functions ---

;; @desc Creates a new proposal.
;; @param description (string-ascii 256) A description of the proposal.
;; @param targets (list 10 principal) A list of target contracts.
;; @param values (list 10 uint) A list of STX values to send.
;; @param signatures (list 10 (string-ascii 64)) A list of function signatures.
;; @param calldatas (list 10 (buff 1024)) A list of calldata.
;; @param start-block uint The starting block for voting.
;; @param end-block uint The ending block for voting.
;; @returns (response uint uint) The ID of the new proposal.
(define-public (propose
    (description (string-ascii 256))
    (targets (list 10 principal))
    (values (list 10 uint))
    (signatures (list 10 (string-ascii 64)))
    (calldatas (list 10 (buff 1024)))
    (start-block uint)
    (end-block uint)
  )
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (let ((proposal-id (try! (contract-call? .proposal-registry create-proposal tx-sender description
        start-block end-block
      ))))
      (print {
        event: "proposal-created",
        proposal-id: proposal-id,
        proposer: tx-sender,
        start-block: start-block,
        end-block: end-block,
      })
      (ok proposal-id)
    )
  )
)

;; @desc Casts a vote on a proposal.
;; @param proposal-id uint The ID of the proposal.
;; @param support bool Whether to support the proposal.
;; @param votes-cast uint The number of votes to cast.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (vote
    (proposal-id uint)
    (support bool)
  )
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (let ((maybe-proposal (try! (contract-call? .proposal-registry get-proposal proposal-id))))
      (match maybe-proposal
        proposal (begin
          (asserts! (is-eq (get executed proposal) false) ERR_VOTING_CLOSED)
          (asserts! (is-eq (get canceled proposal) false) ERR_VOTING_CLOSED)
          (asserts! (>= burn-block-height (get start-block proposal))
            ERR_PROPOSAL_NOT_ACTIVE
          )
          (asserts! (<= burn-block-height (get end-block proposal))
            ERR_VOTING_CLOSED
          )

          (try! (contract-call? .voting vote proposal-id support tx-sender))
          (print {
            event: "vote-cast",
            proposal-id: proposal-id,
            voter: tx-sender,
            support: support,
          })
          (ok true)
        )
        ERR_PROPOSAL_NOT_FOUND
      )
    )
  )
)

;; @desc Executes a proposal.
;; @param proposal-id uint The ID of the proposal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (execute (proposal-id uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (let ((maybe-proposal (try! (contract-call? .proposal-registry get-proposal proposal-id))))
      (match maybe-proposal
        proposal (let (
            (total-votes (+ (get for-votes proposal) (get against-votes proposal)))
            (governance-token-supply (unwrap! (contract-call? .governance-token get-total-supply)
              (err u999)
            ))
            (quorum (/ (* total-votes u10000) governance-token-supply))
          )
          (begin
            (asserts! (is-eq tx-sender (get proposer proposal)) ERR_UNAUTHORIZED)
            (asserts! (>= burn-block-height (get end-block proposal))
              ERR_PROPOSAL_NOT_ACTIVE
            )
            (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
            (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
            (asserts! (> (get for-votes proposal) (get against-votes proposal))
              ERR_PROPOSAL_FAILED
            )
            (asserts! (>= quorum (var-get quorum-percentage))
              ERR_QUORUM_NOT_REACHED
            )
            (try! (contract-call? .proposal-registry set-executed proposal-id))
            (print {
              event: "proposal-executed",
              proposal-id: proposal-id,
              votes-for: (get for-votes proposal),
              votes-against: (get against-votes proposal),
            })
            (ok true)
          )
        )
        ERR_PROPOSAL_NOT_FOUND
      )
    )
  )
)

;; @desc Cancels a proposal.
;; @param proposal-id uint The ID of the proposal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (cancel (proposal-id uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (let ((maybe-proposal (try! (contract-call? .proposal-registry get-proposal proposal-id))))
      (match maybe-proposal
        proposal (begin
          (asserts!
            (or (is-eq tx-sender (get proposer proposal)) (is-contract-owner))
            ERR_UNAUTHORIZED
          )
          (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
          (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
          (try! (contract-call? .proposal-registry set-canceled proposal-id))
          (print {
            event: "proposal-canceled",
            proposal-id: proposal-id,
            canceled-by: tx-sender,
          })
          (ok true)
        )
        ERR_PROPOSAL_NOT_FOUND
      )
    )
  )
)

;; --- Read-Only Functions ---

;; @desc Gets a proposal by its ID.
;; @param proposal-id uint The ID of the proposal.
;; @returns (response (optional { ... }) (err uint)) The proposal details.
(define-read-only (get-proposal (proposal-id uint))
  (contract-call? .proposal-registry get-proposal proposal-id)
)

;; @desc Gets a vote on a proposal by a voter.
;; @param proposal-id uint The ID of the proposal.
;; @param voter principal The address of the voter.
;; @returns (response (optional { ... }) (err uint)) The vote details.
(define-read-only (get-vote
    (proposal-id uint)
    (voter principal)
  )
  (contract-call? .governance-voting get-vote proposal-id voter)
)

;; --- Admin Functions ---

;; @desc Sets the voting period.
;; @param new-period uint The new voting period in blocks.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_VOTING_PERIOD)
    (var-set voting-period-blocks new-period)
    (ok true)
  )
)

;; @desc Sets the quorum percentage.
;; @param new-quorum uint The new quorum percentage.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-quorum-percentage (new-quorum uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    ;; Enforce quorum between 10% and 100% to avoid trivially low or
    ;; impossibly strict quorum settings.
    (asserts! (and (>= new-quorum MIN_QUORUM) (<= new-quorum u10000))
      ERR_UNAUTHORIZED
    )
    (var-set quorum-percentage new-quorum)
    (ok true)
  )
)

;; @desc Transfers ownership of the contract.
;; @param new-owner principal The new owner.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-contract-owner) (err u1000))
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)
