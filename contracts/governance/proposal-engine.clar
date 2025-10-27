;; proposal-engine.clar
;; Manages DAO-based voting and proposal execution

;; Traits
(use-trait proposal-engine-trait .all-traits.proposal-engine-trait)
(impl-trait proposal-engine-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_PROPOSAL_ALREADY_ACTIVE (err u102))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u103))
(define-constant ERR_VOTING_CLOSED (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_QUORUM_NOT_REACHED (err u106))
(define-constant ERR_PROPOSAL_FAILED (err u107))
(define-constant ERR_INVALID_AMOUNT (err u108))
(define-constant ERR_INVALID_VOTING_PERIOD (err u109))

(define-constant CONTRACT_DEPLOYER tx-sender)

;; Data Maps
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

(define-map votes 
  { 
    proposal-id: uint,
    voter: principal
  } 
  { 
    support: bool,
    votes: uint
  })

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-proposal-id uint u1)
(define-data-var voting-period-blocks uint u1440) ;; ~10 days assuming 10 min blocks
(define-data-var quorum-percentage uint u5000) ;; 50% quorum (50 * 100)

;; Authorization
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

;; Proposal Engine Trait Functions
(define-public (propose (description (string-ascii 256)) (targets (list 10 principal)) (values (list 10 uint)) (signatures (list 10 (string-ascii 64))) (calldatas (list 10 (buff 1024))) (start-block uint) (end-block uint))
  (let (
    (proposal-id (var-get next-proposal-id))
  )
    (map-set proposals 
      { id: proposal-id } 
      {
        proposer: tx-sender,
        start-block: start-block,
        end-block: end-block,
        for-votes: u0,
        against-votes: u0,
        executed: false,
        canceled: false,
        description: description
      })
    (var-set next-proposal-id (+ proposal-id u1))
    (print { 
      event: "proposal-created", 
      proposal-id: proposal-id, 
      proposer: tx-sender, 
      start-block: start-block, 
      end-block: end-block 
    })
    (ok proposal-id)))

(define-public (vote (proposal-id uint) (support bool) (votes uint))
  (let (
    (proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (has-voted (is-some (map-get? votes { proposal-id: proposal-id, voter: tx-sender })))
  )
    (asserts! (> votes u0) ERR_INVALID_AMOUNT)
    (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
    (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
    (asserts! (>= block-height (get start-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (<= block-height (get end-block proposal)) ERR_VOTING_CLOSED)
    (asserts! (not has-voted) ERR_ALREADY_VOTED)

    ;; Check if user has voting power
    (asserts! (unwrap! (contract-call? .governance-token has-voting-power tx-sender) ERR_UNAUTHORIZED) ERR_UNAUTHORIZED)

    ;; Update vote counts
    (if support
      (map-set proposals { id: proposal-id } (merge proposal {
        for-votes: (+ (get for-votes proposal) votes)
      }))
      (map-set proposals { id: proposal-id } (merge proposal {
        against-votes: (+ (get against-votes proposal) votes)
      }))
    )

    ;; Record vote
    (map-set votes { proposal-id: proposal-id, voter: tx-sender } {
      support: support,
      votes: votes
    })

    (print { 
      event: "vote-cast", 
      proposal-id: proposal-id, 
      voter: tx-sender, 
      support: support, 
      votes: votes 
    })
    (ok true)
  )
)

(define-public (execute (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (total-votes (+ (get for-votes proposal) (get against-votes proposal)))
    (governance-token-supply (unwrap! (contract-call? .governance-token get-total-supply) ERR_PROPOSAL_NOT_FOUND))
    (quorum (/ (* total-votes u10000) governance-token-supply))
  )
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
    (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
    (asserts! (> (get for-votes proposal) (get against-votes proposal)) ERR_PROPOSAL_FAILED)
    (asserts! (>= quorum (var-get quorum-percentage)) ERR_QUORUM_NOT_REACHED)

    ;; Mark as executed
    (map-set proposals { id: proposal-id } (merge proposal {
      executed: true
    }))

    (print { 
      event: "proposal-executed", 
      proposal-id: proposal-id,
      votes-for: (get for-votes proposal),
      votes-against: (get against-votes proposal)
    })
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (match (map-get? proposals { id: proposal-id })
    proposal (ok proposal)
    (err ERR_PROPOSAL_NOT_FOUND)
  )
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (ok (map-get? votes { proposal-id: proposal-id, voter: voter })))

(define-public (cancel (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (or (is-eq tx-sender (get proposer proposal)) (is-contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
    (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)

    (map-set proposals { id: proposal-id } (merge proposal {
      canceled: true
    }))

    (print { 
      event: "proposal-canceled", 
      proposal-id: proposal-id, 
      canceled-by: tx-sender 
    })
    (ok true)
  )
)

;; Admin Functions
(define-public (set-voting-period (new-period uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_VOTING_PERIOD)
    (var-set voting-period-blocks new-period)
    (ok true)))

(define-public (set-quorum-percentage (new-quorum uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (<= new-quorum u10000) ERR_UNAUTHORIZED)
    (var-set quorum-percentage new-quorum)
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))