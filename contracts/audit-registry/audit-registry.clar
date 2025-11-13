;; audit-registry.clar
;; DAO-based contract security audit registry
;; Handles audit submissions, DAO voting, and NFT badge issuance

;; --- Traits ---
(use-trait "dao-trait" .traits.dao-trait.dao-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_AUDIT_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_STATUS (err u1003))
(define-constant ERR_VOTING_CLOSED (err u1004))
(define-constant ERR_ALREADY_VOTED (err u1005))
(define-constant ERR_INSUFFICIENT_STAKE (err u1006))
(define-constant ERR_INVALID_VOTE_WEIGHT (err u1007))
(define-constant ERR_VOTING_ACTIVE (err u1008))

;; --- Data Storage ---
(define-data-var next-audit-id uint u1)
(define-data-var min-stake-amount uint u100000000) ;; 100 STX in microSTX
(define-data-var voting-period uint u10080) ;; ~7 days in blocks
(define-data-var dao-contract (optional principal) none)
(define-data-var quorum-threshold uint u5000) ;; 50% in basis points

;; Audit structure with enhanced voting
(define-map audits { id: uint } {
  contract-address: principal,
  audit-hash: (string-ascii 64),
  auditor: principal,
  report-uri: (string-utf8 256),
  timestamp: uint,
  status: {
    status: (string-ascii 20),
    reason: (optional (string-utf8 500))
  },
  votes: {
    for: uint,
    against: uint,
    total-weight: uint
  },
  voting-ends: uint,
  finalized: bool
})

;; Track individual votes
(define-map voter-records 
  { audit-id: uint, voter: principal }
  { vote: bool, weight: uint, timestamp: uint })

;; Stake tracking
(define-map staked-amounts  
  { staker: principal }  
  { amount: uint, last-vote: uint })

;; --- Private Helper Functions ---

(define-private (get-voting-weight (voter principal))
  (match (var-get dao-contract)
    dao 
      (match (contract-call? dao get-voting-power voter)
        weight (ok weight)
        error (ok u1)) ;; Default weight if DAO call fails
    (ok u1))) ;; Default weight if no DAO configured

(define-private (has-voted (audit-id uint) (voter principal))
  (is-some (map-get? voter-records { audit-id: audit-id, voter: voter })))

(define-private (calculate-quorum-met (for-votes uint) (against-votes uint))
  (let ((total-votes (+ for-votes against-votes)))
    (and 
      (> total-votes u0)
      (>= (* for-votes u10000) (* total-votes (var-get quorum-threshold))))))

;; --- Public Functions ---

;; Submit a new audit with enhanced validation
(define-public (submit-audit 
    (contract-address principal) 
    (audit-hash (string-ascii 64))
    (report-uri (string-utf8 256)))
  (let (
      (audit-id (var-get next-audit-id))
      (caller tx-sender))
    
    ;; Validate DAO voting power if configured
    (match (var-get dao-contract)
      dao (match (contract-call? dao has-voting-power caller)
            has-power (asserts! has-power ERR_UNAUTHORIZED)
            error (err error))
      (ok true))
    
    (map-set audits { id: audit-id }
      {
        contract-address: contract-address,
        audit-hash: audit-hash,
        auditor: caller,
        report-uri: report-uri,
        timestamp: block-height,
        status: { status: "pending", reason: none },
        votes: { for: u0, against: u0, total-weight: u0 },
        voting-ends: (+ block-height (var-get voting-period)),
        finalized: false
      })
    
    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)))

;; Enhanced voting with weight tracking
(define-public (vote (audit-id uint) (approve bool))
  (let (
      (caller tx-sender)
      (audit (unwrap! (map-get? audits { id: audit-id }) ERR_AUDIT_NOT_FOUND))
      (vote-weight (unwrap! (get-voting-weight caller) ERR_INVALID_VOTE_WEIGHT)))
    
    (asserts! (<= block-height (get voting-ends audit)) ERR_VOTING_CLOSED)
    (asserts! (not (get finalized audit)) ERR_VOTING_CLOSED)
    (asserts! (not (has-voted audit-id caller)) ERR_ALREADY_VOTED)
    
    ;; Record the vote
    (map-set voter-records 
      { audit-id: audit-id, voter: caller }
      { vote: approve, weight: vote-weight, timestamp: block-height })
    
    ;; Update audit votes
    (let ((current-votes (get votes audit)))
      (map-set audits { id: audit-id }
        (merge audit {
          votes: {
            for: (if approve (+ (get for current-votes) vote-weight) (get for current-votes)),
            against: (if approve (get against current-votes) (+ (get against current-votes) vote-weight)),
            total-weight: (+ (get total-weight current-votes) vote-weight)
          }
        })))
    
    (ok true)))

;; Finalize audit with quorum check
(define-public (finalize-audit (audit-id uint))
  (let (
      (audit (unwrap! (map-get? audits { id: audit-id }) ERR_AUDIT_NOT_FOUND))
      (votes (get votes audit)))
    
    (asserts! (> block-height (get voting-ends audit)) ERR_VOTING_ACTIVE)
    (asserts! (not (get finalized audit)) ERR_INVALID_STATUS)
    
    (let ((quorum-met (calculate-quorum-met (get for votes) (get against votes)))
          (approved (>= (get for votes) (get against votes))))
      
      (if (and quorum-met approved)
        (begin
          (map-set audits { id: audit-id }
            (merge audit {
              status: { status: "approved", reason: none },
              finalized: true
            }))
          ;; Mint NFT for successful audit
          (try! (contract-call? .audit-badge-nft mint 
            audit-id
            (get report-uri audit)
            (get auditor audit))))
        (map-set audits { id: audit-id }
          (merge audit {
            status: { 
              status: "rejected", 
              reason: (some (if quorum-met 
                "Majority voted against" 
                "Quorum not met"))
            },
            finalized: true
          })))
      
      (ok true))))

;; --- Read-only Functions ---
(define-read-only (get-audit (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok audit)
    (err ERR_AUDIT_NOT_FOUND)))

(define-read-only (get-audit-status (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok (get status audit))
    (err ERR_AUDIT_NOT_FOUND)))

(define-read-only (get-audit-votes (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok (get votes audit))
    (err ERR_AUDIT_NOT_FOUND)))

(define-read-only (get-voter-record (audit-id uint) (voter principal))
  (ok (map-get? voter-records { audit-id: audit-id, voter: voter })))

(define-read-only (get-quorum-status (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (let ((votes (get votes audit)))
      (ok {
        quorum-met: (calculate-quorum-met (get for votes) (get against votes)),
        for-votes: (get for votes),
        against-votes: (get against votes),
        total-weight: (get total-weight votes)
      }))
    (err ERR_AUDIT_NOT_FOUND)))

;; --- Admin Functions ---
(define-public (set-voting-period (blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period blocks)
    (ok true)))

(define-public (set-quorum-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= threshold u10000) ERR_INVALID_STATUS)
    (var-set quorum-threshold threshold)
    (ok true)))

(define-public (emergency-pause-audit (audit-id uint) (reason (string-utf8 500)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? audits { id: audit-id })
      audit
        (begin
          (map-set audits { id: audit-id }
            (merge audit {
              status: { status: "paused", reason: (some reason) },
              finalized: true
            }))
          (ok true))
      (err ERR_AUDIT_NOT_FOUND))))

;; Initialize the contract
(define-public (initialize (maybe-dao (optional principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set dao-contract maybe-dao)
    (ok true)))
