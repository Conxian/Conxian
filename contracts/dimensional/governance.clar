;; governance.clar
;; Governance and parameter management for dimensional engine

(use-trait dimensional-core-trait .all-traits.dimensional-trait)
(use-trait governance-token-trait .all-traits.governance-token-trait)
(use-trait governance-trait .all-traits.governance-trait)

(use-trait governance_trait .all-traits.governance-trait)
 .all-traits.governance-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_PARAM (err u5001))
(define-constant ERR_VOTING_NOT_ACTIVE (err u5002))
(define-constant ERR_ALREADY_VOTED (err u5003))
(define-constant ERR_VOTING_CLOSED (err u5004))
(define-constant ERR_INSUFFICIENT_BALANCE (err u5005))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var governance-token principal)
(define-data-var voting-delay uint u100)  ;; ~20 minutes
(define-data-var voting-period uint u720) ;; ~1 day
(define-data-var proposal-threshold uint u100000000)  ;; 100 tokens

;; Proposal data structure
(define-map proposals {id: uint} {
  proposer: principal,
  target: principal,
  function: (string-ascii 50),
  args: (list 10 {name: (string-ascii 50), value: (string-utf8 1024)}),
  start-block: uint,
  end-block: uint,
  for-votes: uint,
  against-votes: uint,
  executed: bool,
  canceled: bool
})

;; Voter information
(define-map votes {proposal-id: uint, voter: principal} {
  support: bool,  ;; true = for, false = against
  votes: uint
})

;; Track if address has voted on a proposal
(define-map has-voted {(proposal-id: uint, voter: principal)} bool)

;; Track next proposal ID
(define-data-var next-proposal-id uint u1)

;; ===== Core Functions =====
(define-public (propose 
    (target principal)
    (function (string-ascii 50))
    (args (list 10 {name: (string-ascii 50), value: (string-utf8 1024)}))
  )
  (let (
    (proposal-id (var-get next-proposal-id))
    (voting-delay (var-get voting-delay))
    (voting-period (var-get voting-period))
    (balance (unwrap! (contract-call? (var-get governance-token) get-balance tx-sender) (err u5001)))
  )
    (asserts! (>= balance (var-get proposal-threshold)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Create new proposal
    (map-set proposals {id: proposal-id} {
      proposer: tx-sender,
      target: target,
      function: function,
      args: args,
      start-block: (+ block-height voting-delay),
      end-block: (+ block-height voting-delay voting-period),
      for-votes: u0,
      against-votes: u0,
      executed: false,
      canceled: false
    })
    
    ;; Increment proposal ID
    (var-set next-proposal-id (+ proposal-id u1))
    
    (ok proposal-id)
  )
)

(define-public (cast-vote (proposal-id uint) (support bool))
  (let (
    (proposal (unwrap! (map-get? proposals {id: proposal-id}) (err u5001)))
    (has-voted? (default-to false (map-get? has-voted {(proposal-id: proposal-id, voter: tx-sender)})))
    (weight (unwrap! (contract-call? (var-get governance-token) get-votes tx-sender block-height) (err u5001)))
  )
    (asserts! (and (>= block-height (get proposal 'start-block)) 
                  (<= block-height (get proposal 'end-block))) 
      ERR_VOTING_NOT_ACTIVE)
    (asserts! (not has-voted?) ERR_ALREADY_VOTED)
    
    ;; Update vote counts
    (if support
      (map-set proposals {id: proposal-id} (merge proposal {
        'for-votes: (+ (get proposal 'for-votes) weight)
      }))
      (map-set proposals {id: proposal-id} (merge proposal {
        'against-votes: (+ (get proposal 'against-votes) weight)
      }))
    )
    
    ;; Record vote
    (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
      support: support,
      votes: weight
    })
    
    (map-set has-voted {(proposal-id: proposal-id, voter: tx-sender)} true)
    
    (ok true)
  )
)

(define-public (execute (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals {id: proposal-id}) (err u5001)))
    (quorum (/ (* (+ (get proposal 'for-votes) (get proposal 'against-votes)) u100) 
              (unwrap! (contract-call? (var-get governance-token) total-supply) (err u5001))))
  )
    (asserts! (is-eq tx-sender (get proposal 'proposer)) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get proposal 'end-block)) ERR_VOTING_NOT_ACTIVE)
    (asserts! (not (get proposal 'executed)) ERR_VOTING_CLOSED)
    (asserts! (not (get proposal 'canceled)) ERR_VOTING_CLOSED)
    (asserts! (> (get proposal 'for-votes) (get proposal 'against-votes)) ERR_VOTING_CLOSED)
    (asserts! (>= quorum u3000) ERR_VOTING_CLOSED)  ;; At least 30% quorum
    
    ;; Mark as executed
    (map-set proposals {id: proposal-id} (merge proposal {
      'executed: true
    }))
    
    ;; Execute the proposal
    (match (contract-call? 
      (get proposal 'target) 
      (get proposal 'function)
      (get proposal 'args)
    )
      result (ok result)
      error (begin
        ;; Revert execution status if call fails
        (map-set proposals {id: proposal-id} (merge proposal {
          'executed: false
        }))
        error
      )
    )
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (match (map-get? proposals {id: proposal-id})
    proposal (ok proposal)
    (err ERR_INVALID_PARAM)
  )
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (match (map-get? votes {proposal-id: proposal-id, voter: voter})
    vote (ok vote)
    (err u0)
  )
)
