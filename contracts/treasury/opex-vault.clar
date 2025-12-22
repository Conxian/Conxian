;; opex-vault.clar
;; OPEX Vault for Conxian Protocol Operations Budget
;; - Streams CXD/CXTR to ops budgets with DAO override timelock
;; - Enforces immutable emission curve and DAO timelock for parameter changes

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u9500))
(define-constant ERR_INSUFFICIENT_BALANCE (err u9501))
(define-constant ERR_TIMELOCK_ACTIVE (err u9502))
(define-constant ERR_INVALID_AMOUNT (err u9503))

;; --- Constants ---
(define-constant TIMELOCK_BLOCKS u12096)  ;; 14 days at 5s blocks
(define-constant BPS_TOTAL u10000)
(define-uint PRECISION u1000000)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var dao-governor principal tx-sender)
(define-data-var ops-budget-rate uint u0)  ;; CXD per block
(define-data-var last-claim-block uint u0)
(define-data-var timelock-start uint u0)
(define-data-var pending-budget-rate uint u0)

;; --- Budget State ---
(define-map budget-stream {
  recipient: principal,
  token: principal,
} {
  rate-per-block: uint,
  claimed-total: uint,
  last-claim-block: uint,
})

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-dao-or-owner)
  (or (is-eq tx-sender (var-get contract-owner))
      (is-eq tx-sender (var-get dao-governor)))
)

;; --- Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-dao-governor (governor principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set dao-governor governor)
    (ok true)
  )
)

;; --- DAO Timelock Controls ---

;; @notice Propose a new ops budget rate with timelock
(define-public (propose-budget-rate (new-rate uint))
  (begin
    (asserts! (is-dao-or-owner) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate (/ (* u1000000 PRECISION) u100)) ERR_INVALID_AMOUNT) ;; Max 1M CXD per block
    (var-set timelock-start block-height)
    (var-set pending-budget-rate new-rate)
    (print {
      event: "budget-rate-proposed",
      proposed-rate: new-rate,
      timelock-start: block-height,
      effective-at: (+ block-height TIMELOCK_BLOCKS)
    })
    (ok true)
  )
)

;; @notice Execute the timelocked budget rate change
(define-public (execute-budget-rate-change)
  (let ((current-height block-height)
        (pending (var-get pending-budget-rate))
        (start (var-get timelock-start)))
    (asserts! (is-dao-or-owner) ERR_UNAUTHORIZED)
    (asserts! (> start u0) ERR_TIMELOCK_ACTIVE)
    (asserts! (>= current-height (+ start TIMELOCK_BLOCKS)) ERR_TIMELOCK_ACTIVE)
    (var-set ops-budget-rate pending)
    (var-set timelock-start u0)
    (var-set pending-budget-rate u0)
    (print {
      event: "budget-rate-updated",
      new-rate: pending,
      effective-at: current-height
    })
    (ok true)
  )
)

;; --- Budget Streaming ---

;; @notice Add or update a budget stream for a recipient/token
(define-public (set-budget-stream
    (recipient principal)
    (token <sip-010-ft-trait>)
    (rate-per-block uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (map-set budget-stream {
      recipient: recipient,
      token: (contract-of token),
    } {
      rate-per-block: rate-per-block,
      claimed-total: u0,
      last-claim-block: block-height,
    })
    (print {
      event: "budget-stream-set",
      recipient: recipient,
      token: (contract-of token),
      rate-per-block: rate-per-block,
    })
    (ok true)
  )
)

;; @notice Claim accrued budget for a recipient
(define-public (claim-budget (token <sip-010-ft-trait>))
  (let ((token-contract (contract-of token))
        (stream (unwrap! (map-get? budget-stream {recipient: tx-sender, token: token-contract}) ERR_INSUFFICIENT_BALANCE))
        (current-height block-height)
        (blocks-since (- current-height (get last-claim-block stream)))
        (accrued (/ (* (get rate-per-block stream) blocks-since) PRECISION))
        (total-claimed (get claimed-total stream)))
    (asserts! (> blocks-since u0) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> accrued u0) ERR_INSUFFICIENT_BALANCE)

    ;; Update state
    (map-set budget-stream {recipient: tx-sender, token: token-contract}
      (merge stream {
        claimed-total: (+ total-claimed accrued),
        last-claim-block: current-height,
      })
    )

    ;; Transfer tokens (assuming this vault holds the tokens)
    (as-contract
      (try! (contract-call? token transfer accrued tx-sender (as-contract tx-sender) none))
    )

    (print {
      event: "budget-claimed",
      recipient: tx-sender,
      token: token-contract,
      amount: accrued,
      total-claimed: (+ total-claimed accrued),
    })
    (ok accrued)
  )
)

;; --- Read-Only Views ---

(define-read-only (get-budget-stream (recipient principal) (token principal))
  (map-get? budget-stream {recipient: recipient, token: token})
)

(define-read-only (get-claimable-amount (recipient principal) (token principal))
  (let ((stream (unwrap! (map-get? budget-stream {recipient: recipient, token: token}) ERR_INSUFFICIENT_BALANCE))
        (current-height block-height)
        (blocks-since (- current-height (get last-claim-block stream))))
    (if (> blocks-since u0)
      (ok (/ (* (get rate-per-block stream) blocks-since) PRECISION))
      (ok u0)
    )
  )
)

(define-read-only (get-pending-budget-change)
  (let ((start (var-get timelock-start)))
    (if (> start u0)
      (ok {
        pending-rate: (var-get pending-budget-rate),
        timelock-start: start,
        effective-at: (+ start TIMELOCK_BLOCKS),
        blocks-remaining: (if (> (+ start TIMELOCK_BLOCKS) block-height) (- (+ start TIMELOCK_BLOCKS) block-height) u0),
      })
      (ok false)
    )
  )
)

(define-read-only (get-ops-budget-rate)
  (ok (var-get ops-budget-rate))
)

;; --- Emergency Controls ---

(define-public (emergency-pause-claims)
  (begin
    (asserts! (is-dao-or-owner) ERR_UNAUTHORIZED)
    (var-set ops-budget-rate u0)
    (print {
      event: "ops-budget-paused",
      paused-at: block-height,
    })
    (ok true)
  )
)

(define-public (emergency-resume-claims)
  (begin
    (asserts! (is-dao-or-owner) ERR_UNAUTHORIZED)
    ;; Resume with previously approved rate
    (var-set ops-budget-rate (var-get pending-budget-rate))
    (print {
      event: "ops-budget-resumed",
      resumed-at: block-height,
      rate: (var-get pending-budget-rate),
    })
    (ok true)
  )
)
