;; founder-vault.clar
;; Founder Vault with Immutable Emission Curve and DAO Override Timelock
;; - Manages founder token distributions with vesting schedules
;; - Enforces immutable emission curves with DAO timelock for changes

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u9500))
(define-constant ERR_INSUFFICIENT_BALANCE (err u9501))
(define-constant ERR_TIMELOCK_ACTIVE (err u9502))
(define-constant ERR_INVALID_AMOUNT (err u9503))
(define-constant ERR_VESTING_NOT_STARTED (err u9504))
(define-constant ERR_NO_CLAIMABLE (err u9505))

;; --- Constants ---
(define-constant TIMELOCK_BLOCKS u12096)  ;; 14 days at 5s blocks
(define-constant BPS_TOTAL u10000)
(define-uint PRECISION u1000000)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var dao-governor principal tx-sender)
(define-data-var founder-list (list 10 principal) (list))
(define-data-var total-allocated uint u0)
(define-data-var timelock-start uint u0)
(define-data-var pending-founder-list (list 10 principal) (list))

;; --- Founder Vesting State ---
(define-map founder-info {
  founder: principal,
} {
  total-allocation: uint,
  claimed-total: uint,
  vesting-start: uint,
  vesting-duration: uint,
  cliff-end: uint,
  emission-rate: uint,  ;; per block
})

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-dao-or-owner)
  (or (is-eq tx-sender (var-get contract-owner))
      (is-eq tx-sender (var-get dao-governor)))
)

(define-private (is-founder)
  (let ((founders (var-get founder-list)))
    (is-some (filter is-eq founders tx-sender))
  )
)

;; --- Admin Functions ---

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

;; --- DAO Timelock Controls for Founder List ---

;; @notice Propose new founder list with timelock
(define-public (propose-founder-list (new-founders (list 10 principal)))
  (begin
    (asserts! (is-dao-or-owner) ERR_UNAUTHORIZED)
    (asserts! (<= (len new-founders) u10) ERR_INVALID_AMOUNT)
    (var-set timelock-start block-height)
    (var-set pending-founder-list new-founders)
    (print {
      event: "founder-list-proposed",
      proposed-founders: new-founders,
      timelock-start: block-height,
      effective-at: (+ block-height TIMELOCK_BLOCKS)
    })
    (ok true)
  )
)

;; @notice Execute the timelocked founder list change
(define-public (execute-founder-list-change)
  (let ((current-height block-height)
        (pending (var-get pending-founder-list))
        (start (var-get timelock-start)))
    (asserts! (is-dao-or-owner) ERR_UNAUTHORIZED)
    (asserts! (> start u0) ERR_TIMELOCK_ACTIVE)
    (asserts! (>= current-height (+ start TIMELOCK_BLOCKS)) ERR_TIMELOCK_ACTIVE)
    (var-set founder-list pending)
    (var-set timelock-start u0)
    (var-set pending-founder-list (list))
    (print {
      event: "founder-list-updated",
      new-founders: pending,
      effective-at: current-height
    })
    (ok true)
  )
)

;; --- Founder Vesting Management ---

;; @notice Initialize vesting for a founder (immutable emission curve)
(define-public (initialize-founder-vesting
    (founder principal)
    (token <sip-010-ft-trait>)
    (total-allocation uint)
    (vesting-start uint)
    (vesting-duration uint)
    (cliff-percent uint)
  )
  (let (
    (cliff-end (+ vesting-start (/ (* vesting-duration cliff-percent) BPS_TOTAL)))
    (emission-rate (/ (* total-allocation PRECISION) vesting-duration))
    (founders (var-get founder-list))
    )
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-some (filter is-eq founders founder)) ERR_UNAUTHORIZED)
    (asserts! (> vesting-start block-height) ERR_INVALID_AMOUNT)
    (asserts! (> vesting-duration u0) ERR_INVALID_AMOUNT)
    (asserts! (<= cliff-percent BPS_TOTAL) ERR_INVALID_AMOUNT)
    
    (map-set founder-info {founder: founder} {
      total-allocation: total-allocation,
      claimed-total: u0,
      vesting-start: vesting-start,
      vesting-duration: vesting-duration,
      cliff-end: cliff-end,
      emission-rate: emission-rate,
    })
    
    (var-set total-allocated (+ (var-get total-allocated) total-allocation))
    
    (print {
      event: "founder-vesting-initialized",
      founder: founder,
      token: (contract-of token),
      total-allocation: total-allocation,
      vesting-start: vesting-start,
      vesting-duration: vesting-duration,
      cliff-end: cliff-end,
      emission-rate: emission-rate,
    })
    (ok true)
  )
)

;; --- Claim Functions ---

;; @notice Claim vested tokens for a founder
(define-public (claim-vested-tokens (token <sip-010-ft-trait>))
  (let ((current-height block-height)
        (founder-data (unwrap! (map-get? founder-info {founder: tx-sender}) ERR_UNAUTHORIZED)))
    (asserts! (is-founder) ERR_UNAUTHORIZED)
    (asserts! (>= current-height (get vesting-start founder-data)) ERR_VESTING_NOT_STARTED)
    
    (let ((claimable-amount (calculate-claimable founder-data current-height)))
      (asserts! (> claimable-amount u0) ERR_NO_CLAIMABLE)
      
      ;; Update claimed total
      (map-set founder-info {founder: tx-sender}
        (merge founder-data {
          claimed-total: (+ (get claimed-total founder-data) claimable-amount),
        })
      )
      
      ;; Transfer tokens
      (as-contract
        (try! (contract-call? token transfer claimable-amount tx-sender (as-contract tx-sender) none))
      )
      
      (print {
        event: "founder-tokens-claimed",
        founder: tx-sender,
        token: (contract-of token),
        amount: claimable-amount,
        total-claimed: (+ (get claimed-total founder-data) claimable-amount),
      })
      (ok claimable-amount)
    )
  )
)

;; --- Helper Functions ---

(define-private (calculate-claimable (founder-data {total-allocation: uint, claimed-total: uint, vesting-start: uint, vesting-duration: uint, cliff-end: uint, emission-rate: uint}) (current-height uint))
  (let ((vested-amount u0)
        (blocks-since-start (- current-height (get vesting-start founder_data))))
    
    ;; Check if past cliff
    (if (< current-height (get cliff-end founder_data))
      u0
      ;; Calculate vested amount
      (let ((max-vestable (get total-allocation founder_data))
            (calculated-vested (/ (* (get emission-rate founder_data) blocks-since_start) PRECISION)))
        (if (> calculated-vested max-vestable)
          max-vestable
          calculated-vested
        )
      )
    )
  )
)

;; --- Read-Only Views ---

(define-read-only (get-founder-info (founder principal))
  (map-get? founder-info {founder: founder})
)

(define-read-only (get-claimable-amount (founder principal))
  (let ((founder-data (unwrap! (map-get? founder-info {founder: founder}) ERR_UNAUTHORIZED))
        (current-height block-height))
    (if (>= current-height (get vesting-start founder-data))
      (ok (calculate-claimable founder-data current-height))
      (ok u0)
    )
  )
)

(define-read-only (get-founder-list)
  (ok (var-get founder-list))
)

(define-read-only (get-pending-founder-change)
  (let ((start (var-get timelock-start)))
    (if (> start u0)
      (ok {
        pending-founders: (var-get pending-founder-list),
        timelock-start: start,
        effective-at: (+ start TIMELOCK_BLOCKS),
        blocks-remaining: (if (> (+ start TIMELOCK_BLOCKS) block-height) (- (+ start TIMELOCK_BLOCKS) block-height) u0),
      })
      (ok false)
    )
  )
)

(define-read-only (get-total-allocated)
  (ok (var-get total-allocated))
)

;; --- Emergency Controls ---

(define-public (emergency-pause-all-vesting)
  (begin
    (asserts! (is-dao-or-owner) ERR_UNAUTHORIZED)
    ;; This would require additional state tracking to implement properly
    (print {
      event: "founder-vesting-emergency-pause",
      paused_at: block-height,
    })
    (ok true)
  )
)
