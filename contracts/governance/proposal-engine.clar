;; proposal-engine.clar
;; Manages DAO-based voting and proposal execution

;; Traits
(use-trait proposal-engine-trait .all-traits.proposal-engine-trait)
(use-trait governance-token-trait .all-traits.governance-token-trait)

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
  { proposal-id: uint } 
  { 
    proposer: principal,
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    details: (string-ascii 256)
  })

(define-map votes 
  { 
    proposal-id: uint,
    voter: principal
  } 
  { 
    amount: uint,
    support: bool
  })

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-proposal-id uint u1)
(define-data-var voting-period-blocks uint u1440) ;; ~10 days assuming 10 min blocks
(define-data-var quorum-percentage uint u5000) ;; 50% quorum (50 * 100)

;; Authorization
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

;; Public Functions
(define-public (create-proposal (details (string-ascii 256)))
  (let (
    (proposal-id (var-get next-proposal-id))
    (start-block block-height)
    (end-block (+ block-height (var-get voting-period-blocks)))
  )
    (map-set proposals 
      { proposal-id: proposal-id } 
      {
        proposer: tx-sender,
        start-block: start-block,
        end-block: end-block,
        votes-for: u0,
        votes-against: u0,
        executed: false,
        details: details
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

(define-public (vote (proposal-id uint) (support bool) (amount uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (current-votes-for (get votes-for proposal))
    (current-votes-against (get votes-against proposal))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
    (asserts! (>= block-height (get start-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (<= block-height (get end-block proposal)) ERR_VOTING_CLOSED)
    (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)

    ;; Lock tokens by transferring to contract
    (try! (contract-call? .governance-token transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: tx-sender } 
      { amount: amount, support: support })

    ;; Update proposal vote counts
    (map-set proposals 
      { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if support (+ current-votes-for amount) current-votes-for),
        votes-against: (if support current-votes-against (+ current-votes-against amount))
      }))

    (print { 
      event: "vote-cast", 
      proposal-id: proposal-id, 
      voter: tx-sender, 
      support: support, 
      amount: amount 
    })
    (ok true)))

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
    (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
    (governance-token-supply (unwrap! (contract-call? .governance-token get-total-supply) ERR_PROPOSAL_NOT_FOUND))
    (quorum-reached (>= (* total-votes u10000) (* governance-token-supply (var-get quorum-percentage))))
    (proposal-passed (> (get votes-for proposal) (get votes-against proposal)))
  )
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_ACTIVE)
    (asserts! (> block-height (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! quorum-reached ERR_QUORUM_NOT_REACHED)
    (asserts! proposal-passed ERR_PROPOSAL_FAILED)

    ;; Mark proposal as executed
    (map-set proposals 
      { proposal-id: proposal-id } 
      (merge proposal { executed: true }))

    (print { 
      event: "proposal-executed", 
      proposal-id: proposal-id,
      votes-for: (get votes-for proposal),
      votes-against: (get votes-against proposal)
    })
    (ok true)))

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

;; Read-only Functions
(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals { proposal-id: proposal-id })))

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (ok (map-get? votes { proposal-id: proposal-id, voter: voter })))

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner)))

(define-read-only (get-next-proposal-id)
  (ok (var-get next-proposal-id)))

(define-read-only (get-voting-period)
  (ok (var-get voting-period-blocks)))

(define-read-only (get-quorum-percentage)
  (ok (var-get quorum-percentage)))

(define-read-only (is-proposal-active (proposal-id uint))
  (match (map-get? proposals { proposal-id: proposal-id })
    proposal (ok (and 
      (>= block-height (get start-block proposal))
      (<= block-height (get end-block proposal))
      (not (get executed proposal))))
    (ok false)))