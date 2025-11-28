;; proposal-engine.clar

;; Manages DAO-based voting and proposal execution

;; Traits
(use-trait proposal-engine-trait .governance.proposal-engine-trait)
;; TODO: proposal-engine-trait not defined in traits folder.clar
;; (impl-trait .governance.proposal-engine-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_PROPOSAL_ALREADY_ACTIVE (err u102))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u103))
(define-constant ERR_VOTING_CLOSED (err u104))
(define-constant ERR_ALREADY_VOTED (err u105))
(define-constant ERR_QUORUM_NOT_REACHED (err u106))
(define-constant ERR_PROPOSAL_FAILED (err u107))

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
  }
)

(define-map votes 
  { 
    proposal-id: uint,
    voter: principal 
  }
  { 
    amount: uint, 
    support: bool 
  }
)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-proposal-id uint u1)
(define-data-var voting-period-blocks uint u100)  ;; Example: 100 blocks voting period
(define-data-var quorum-percentage uint u5000)    ;; 50% quorum (50 * 100)

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
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (print { 
      event: "proposal-created", 
      proposal-id: proposal-id, 
      proposer: tx-sender, 
      start-block: start-block, 
      end-block: end-block 
    })
    (ok proposal-id)
  )
)

(define-public (vote (proposal-id uint) (support bool) (amount uint))
  (let (
    (proposal (map-get? proposals { proposal-id: proposal-id }))
  )
    (asserts! (is-some proposal) ERR_PROPOSAL_NOT_FOUND)
    (asserts! (not (get executed (unwrap-panic proposal))) ERR_VOTING_CLOSED)
    (asserts! 
      (and 
        (>= block-height (get start-block (unwrap-panic proposal))) 
        (<= block-height (get end-block (unwrap-panic proposal)))
      ) 
      ERR_VOTING_CLOSED
    )
    (asserts! 
      (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) 
      ERR_ALREADY_VOTED
    )
    
    ;; Transfer governance tokens to the contract for voting
    (try! (contract-call? .governance-token transfer amount tx-sender (as-contract tx-sender) none))
    
    (map-set votes 
      { 
        proposal-id: proposal-id, 
        voter: tx-sender 
      } 
      { 
        amount: amount, 
        support: support 
      }
    )
    
    (if support
      (map-set proposals 
        { proposal-id: proposal-id } 
        (merge 
          (unwrap-panic proposal) 
          { 
            votes-for: (+ (get votes-for (unwrap-panic proposal)) amount) 
          }
        )
      )
      (map-set proposals 
        { proposal-id: proposal-id } 
        (merge 
          (unwrap-panic proposal) 
          { 
            votes-against: (+ (get votes-against (unwrap-panic proposal)) amount) 
          }
        )
      )
    )
    
    (print { 
      event: "vote-cast", 
      proposal-id: proposal-id, 
      voter: tx-sender, 
      support: support, 
      amount: amount 
    })
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (begin
    (let ((proposal (map-get? proposals { proposal-id: proposal-id })))
      (asserts! (is-some proposal) ERR_PROPOSAL_NOT_FOUND)
      (asserts! (not (get executed (unwrap-panic proposal))) ERR_PROPOSAL_ALREADY_ACTIVE)
      (asserts! (> block-height (get end-block (unwrap-panic proposal))) ERR_PROPOSAL_NOT_ACTIVE)
      (let (
        (total-votes (+ (get votes-for (unwrap-panic proposal)) (get votes-against (unwrap-panic proposal))))
        (governance-token-supply (unwrap-panic (contract-call? .governance-token get-total-supply)))
        (quorum-reached (>= (* total-votes u10000) (* governance-token-supply (var-get quorum-percentage))))
        (proposal-passed (> (get votes-for (unwrap-panic proposal)) (get votes-against (unwrap-panic proposal))))
      ))
        (asserts! quorum-reached ERR_QUORUM_NOT_REACHED)
        (asserts! proposal-passed ERR_PROPOSAL_FAILED)

        ;; Placeholder for actual proposal execution logic
        ;; This would involve calling other contracts based on the proposal details
        (print { event: "proposal-executed", proposal-id: proposal-id })
        (map-set proposals { proposal-id: proposal-id } (merge (unwrap-panic proposal) { executed: true }))
        (ok true)
      )
    )
  )

;; Read-only Functions
(define-read-only (get-proposal (proposal-id uint))
  (ok (map-get? proposals { proposal-id: proposal-id })))

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (ok (map-get? votes { proposal-id: proposal-id, voter: voter })))

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner)))
