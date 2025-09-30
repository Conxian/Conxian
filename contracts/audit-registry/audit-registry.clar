;; audit-registry.clar
;; DAO-based contract security audit registry
;; Handles audit submissions, DAO voting, and NFT badge issuance

(use-trait sip-009-nft-trait .all-traits.sip-009-nft-trait)
(use-trait dao-trait .all-traits.dao-trait)

;; --- Traits ---

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_AUDIT_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_STATUS (err u1003))
(define-constant ERR_VOTING_CLOSED (err u1004))
(define-constant ERR_ALREADY_VOTED (err u1005))
(define-constant ERR_INSUFFICIENT_STAKE (err u1006))

;; --- Data Storage ---
(define-data-var next-audit-id uint u1)
(define-data-var min-stake-amount uint u100000000) ;; 100 STX in microSTX
(define-data-var voting-period uint u10080) ;; ~7 days in blocks (assuming 1 block per minute)
;; Optional DAO contract to query voting power if configured
(define-data-var dao-contract (optional principal) none)

;; Audit structure
(define-map audits
  { id: uint }
  { 
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
      voters: (list 100 principal)
    },
    voting-ends: uint
  }
)

;; Stake tracking
(define-map staked-amounts
  { staker: principal }
  { amount: uint, last-vote: uint }
)

;; --- Public Functions ---

;; Submit a new audit
(define-public (submit-audit 
    (contract-address principal) 
    (audit-hash (string-ascii 64))
    (report-uri (string-utf8 256))
  )
  (let (
      (audit-id (var-get next-audit-id))
      (caller tx-sender)
    )
    ;; If a DAO contract is configured, enforce has-voting-power; otherwise allow
    (match (var-get dao-contract)
      dc (asserts! (is-eq (contract-call? dc has-voting-power caller) (ok true)) ERR_UNAUTHORIZED)
      none (ok true)
    )
    
    (map-set audits { id: audit-id }
      { 
        contract-address: contract-address,
        audit-hash: audit-hash,
        auditor: caller,
        report-uri: report-uri,
        timestamp: stacks-block-height,
        status: { status: "pending", reason: none },
        votes: { for: u0, against: u0, voters: (list) },
        voting-ends: (+ stacks-block-height (var-get voting-period))
      }
    )
    
    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

;; Vote on an audit
(define-public (vote (audit-id uint) (approve bool))
  (let (
      (caller tx-sender)
      (audit (unwrap! (map-get? audits { id: audit-id }) ERR_AUDIT_NOT_FOUND))
      (voters (get voters (get votes audit)))
    )
    (asserts! (<= stacks-block-height (get voting-ends audit)) ERR_VOTING_CLOSED)
    ;; Ensure caller hasn't already voted
    (let ((already-voted (fold (lambda (v acc) (or acc (is-eq v caller))) voters false)))
      (asserts! (not already-voted) ERR_ALREADY_VOTED))
    
    ;; Simplified status update; DAO weight integration can be added via dao-contract
    (if approve
      (map-set audits { id: audit-id }
        (merge audit { status: { status: "approved", reason: none } }))
      (map-set audits { id: audit-id }
        (merge audit { status: { status: "rejected", reason: (some "Voting threshold not met") } })))
    (ok true)
  )
)

;; Finalize audit after voting period
(define-public (finalize-audit (audit-id uint))
  (let (
      (audit (unwrap! (map-get? audits { id: audit-id }) ERR_AUDIT_NOT_FOUND))
      (votes (get votes audit))
      (total-votes (+ (get for votes) (get against votes)))
    )
    (asserts! (> stacks-block-height (get voting-ends audit)) ERR_VOTING_CLOSED)
    
    (if (>= (get for votes) (get against votes))
      (begin
        (map-set audits { id: audit-id } 
          (merge audit {
            status: { status: "approved", reason: none }
          })
        )
        ;; Mint NFT for successful audit
        (contract-call? .audit-badge-nft mint 
          audit-id
          (get report-uri audit)
          (get auditor audit)
        )
      )
      (map-set audits { id: audit-id } 
        (merge audit {
          status: { status: "rejected", reason: (some "Voting threshold not met") }
        })
      )
    )
    (ok true)
  )
)

;; --- Read-only Functions ---
(define-read-only (get-audit (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok audit)
    (err ERR_AUDIT_NOT_FOUND)
  )
)

(define-read-only (get-audit-status (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok (get status audit))
    (err ERR_AUDIT_NOT_FOUND)
  )
)

(define-read-only (get-audit-votes (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok (get votes audit))
    (err ERR_AUDIT_NOT_FOUND)
  )
)

;; --- Admin Functions ---
(define-public (set-voting-period (blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period blocks)
    (ok true)
  )
)

(define-public (emergency-pause-audit (audit-id uint) (reason (string-utf8 500)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? audits { id: audit-id })
      audit
        (begin
          (map-set audits { id: audit-id }
            (merge audit {
              status: { status: "paused", reason: (some reason) }
            })
          )
          (ok true)
        )
      (err error) (err error)
    )
  )
)

;; Initialize the contract
(define-public (initialize (maybe-dao (optional principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set dao-contract maybe-dao)
    (ok true)
  )
)
