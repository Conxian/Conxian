;; ===========================================
;; GOVERNANCE VOTING CONTRACT
;; ===========================================
;; Version: 1.0.0
;; Clarity SDK 3.9+ & Nakamoto Standard

;; Use decentralized traits
(use-trait "governance-token-trait" .governance-token-trait.governance-token-trait)
(use-trait "rbac-trait" .rbac-trait.rbac-trait)

;; ===========================================
;; CONSTANTS
;; ===========================================
(define-constant VOTE_TYPE_FOR u1)
(define-constant VOTE_TYPE_AGAINST u2)
(define-constant VOTE_TYPE_ABSTAIN u3)
(define-constant PROPOSAL_STATUS_PENDING u1)
(define-constant PROPOSAL_STATUS_ACTIVE u2)
(define-constant PROPOSAL_STATUS_EXECUTED u3)
(define-constant PROPOSAL_STATUS_REJECTED u4)
(define-constant PROPOSAL_STATUS_QUEUED u5)
(define-constant TIMELOCK_CONTRACT .timelock)

;; ===========================================
;; DATA STRUCTURES
;; ===========================================
(define-data-var next-proposal-id uint u0)
(define-data-var voting-period uint u10080)  ;; 1 week in blocks
(define-data-var voting-delay uint u144)     ;; 1 day in blocks
(define-data-var proposal-threshold uint u1000000000000)  ;; 1M tokens
(define-data-var timelock-delay uint u10080)  ;; 1 week in blocks

;; Proposal structure
define-map proposals {
  proposal-id: uint
} {
  proposer: principal,
  title: (string-utf8 256),
  description: (string-utf8 1024),
  start-block: uint,
  end-block: uint,
  for-votes: uint,
  against-votes: uint,
  abstain-votes: uint,
  state: uint,
  executed: bool,
  eta: (optional uint)
}

;; Voting power snapshots
define-map voting-power-snapshots {
  voter: principal,
  block-height: uint
} {
  voting-power: uint
}

;; Votes
define-map votes {
  proposal-id: uint,
  voter: principal
} {
  vote-type: uint,
  weight: uint
}

;; ===========================================
;; PUBLIC FUNCTIONS
;; ===========================================

;; Create a new proposal
(define-public (propose 
    (title (string-utf8 256))
    (description (string-utf8 1024))
  )
  (begin
    ;; Check voting power meets threshold
    (let ((voting-power (get-voting-power tx-sender block-height)))
      (asserts! (>= voting-power (var-get proposal-threshold)) ERR_INSUFFICIENT_VOTING_POWER)
      
      ;; Create proposal
      (let ((proposal-id (var-get next-proposal-id)))
        (map-set proposals {proposal-id: proposal-id} {
          proposer: tx-sender,
          title: title,
          description: description,
          start-block: (+ block-height (var-get voting-delay)),
          end-block: (+ block-height (var-get voting-delay) (var-get voting-period)),
          for-votes: u0,
          against-votes: u0,
          abstain-votes: u0,
          state: PROPOSAL_STATUS_PENDING,
          executed: false,
          eta: none
        })
        
        ;; Take voting power snapshot
        (map-set voting-power-snapshots 
          {voter: tx-sender, block-height: block-height} 
          {voting-power: voting-power}
        )
        
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
      )
    )
  )
)

;; Cast a vote
(define-public (cast-vote 
    (proposal-id uint)
    (vote-type uint)
  )
  (begin
    ;; Validate proposal
    (let ((proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) ERR_PROPOSAL_NOT_FOUND)))
      (asserts! (>= block-height (get start-block proposal)) ERR_VOTING_NOT_STARTED)
      (asserts! (<= block-height (get end-block proposal)) ERR_VOTING_ENDED)
      
      ;; Get voting power at proposal start block
      (let ((voting-power (get-voting-power tx-sender (get start-block proposal))))
        (asserts! (> voting-power u0) ERR_NO_VOTING_POWER)
        
        ;; Record vote
        (map-set votes {proposal-id: proposal-id, voter: tx-sender} {
          vote-type: vote-type,
          weight: voting-power
        })
        
        ;; Update proposal vote counts
        (if (is-eq vote-type VOTE_TYPE_FOR)
          (map-set proposals {proposal-id: proposal-id} (merge proposal {
            for-votes: (+ (get for-votes proposal) voting-power)
          }))
          (if (is-eq vote-type VOTE_TYPE_AGAINST)
            (map-set proposals {proposal-id: proposal-id} (merge proposal {
              against-votes: (+ (get against-votes proposal) voting-power)
            }))
            (map-set proposals {proposal-id: proposal-id} (merge proposal {
              abstain-votes: (+ (get abstain-votes proposal) voting-power)
            }))
          )
        )
        
        (ok true)
      )
    )
  )
)

;; Execute a proposal
(define-public (execute-proposal (proposal-id uint))
  (begin
    ;; Validate proposal
    (let ((proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) ERR_PROPOSAL_NOT_FOUND)))
      (asserts! (>= block-height (get end-block proposal)) ERR_VOTING_NOT_ENDED)
      (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
      
      ;; Check if proposal passed
      (let (
          (quorum (/ (* (+ (get for-votes proposal) (get against-votes proposal)) u100) (var-get total-voting-supply)))
          (majority (> (get for-votes proposal) (get against-votes proposal)))
        )
        (asserts! (>= quorum (var-get quorum-threshold)) ERR_QUORUM_NOT_MET)
        (asserts! majority ERR_PROPOSAL_FAILED)
        
        ;; Queue proposal in timelock
        (let ((eta (+ block-height (var-get timelock-delay))))
          (contract-call? TIMELOCK_CONTRACT queue-transaction
            (get target-contract proposal)
            u0
            (to-consensus-buff? {
              function: (get function-name proposal),
              args: (get parameters proposal)
            })
            eta
          )
          
          ;; Update proposal state to queued
          (map-set proposals {proposal-id: proposal-id} (merge proposal {
            state: PROPOSAL_STATUS_QUEUED,
            eta: (some eta)
          }))
        )
        (ok true)
      )
    )
  )
)

;; ===========================================
;; VOTING POWER CALCULATION
;; ===========================================

(define-private (get-voting-power (voter principal) (block-height uint))
  (match (map-get? voting-power-snapshots {voter: voter, block-height: block-height})
    snapshot (get voting-power snapshot)
    (contract-call? .governance-token get-voting-power voter block-height)
  )
)

;; ===========================================
;; EXECUTION HANDLERS
;; ===========================================

(define-private (execute-parameter-change (proposal {parameters: (list 20 {key: (string-ascii 32), value: uint})}))
  (fold 
    (lambda (param result)
      (let ((key (get key param)) (value (get value param)))
        (match key
          "voting-period" (var-set voting-period value)
          "voting-delay" (var-set voting-delay value)
          "quorum-threshold" (var-set quorum-threshold value)
          "proposal-threshold" (var-set proposal-threshold value)
          "timelock-delay" (var-set timelock-delay value)
          ;; Add more parameters as needed
          (err ERR_UNKNOWN_PARAMETER)
        )
      )
      (ok true)
    )
    (ok true)
    (get parameters proposal)
  )
)

(define-private (execute-contract-upgrade (proposal {target-contract: principal, new-contract: principal}))
  (contract-call? (get target-contract proposal) upgrade-to (get new-contract proposal))
)

(define-private (execute-treasury-spend (proposal {recipient: principal, amount: uint, token: principal}))
  (contract-call? (get token proposal) transfer (get amount proposal) tx-sender (get recipient proposal))
)

;; ===========================================
;; CONFIGURATION
;; ===========================================
(define-data-var quorum-threshold uint u4000)  ;; 40%
(define-data-var total-voting-supply uint u1000000000000)

;; ===========================================
;; INITIALIZATION
;; ===========================================
(begin
  (print "Governance Voting System Initialized")
)
