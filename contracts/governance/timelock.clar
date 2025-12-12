;; ===========================================
;; TIMELOCK CONTRACT
;; ===========================================
;; Version: 1.0.0
;; Clarity SDK 3.9+ & Nakamoto Standard

;; Use decentralized traits
(use-trait "ownable-trait" .ownable-trait.ownable-trait)

;; ===========================================
;; DATA STRUCTURES
;; ===========================================
(define-constant TIMELOCK_DELAY u2073600) ;; u144 * 120 blocks (approx 24 hours)
(define-constant MIN_DELAY u17280)  ;; 1 day
(define-constant MAX_DELAY u1209600) ;; 1 week

(define-data-var delay uint u172800)  ;; 10 days

(define-map queue 
  {tx-id: (buff 32)}
  {
    target: principal,
    value: uint,
    data: (buff 1024),
    eta: uint
  }
)

;; ===========================================
;; PUBLIC FUNCTIONS
;; ===========================================

;; Queue a transaction
(define-public (queue-transaction
    (target principal)
    (value uint)
    (data (buff 1024))
    (eta uint)
  )
  (begin
    (asserts! (>= eta (+ block-height (var-get delay))) ERR_INSUFFICIENT_DELAY)
    (asserts! (<= eta (+ block-height (var-get MAX_DELAY))) ERR_EXCESSIVE_DELAY)
    
    (let ((tx-id (sha256 (concat (as-max-len? (to-consensus-buff? target) u160) (to-consensus-buff? value) data))))
      (map-set queue {tx-id: tx-id} {
        target: target,
        value: value,
        data: data,
        eta: eta
      })
      (ok tx-id)
    )
  )
)

;; Execute a queued transaction
(define-public (execute-transaction
    (target principal)
    (value uint)
    (data (buff 1024))
    (eta uint)
  )
  (begin
    (let ((tx-id (sha256 (concat (as-max-len? (to-consensus-buff? target) u160) (to-consensus-buff? value) data))))
      (match (map-get? queue {tx-id: tx-id})
        queued (begin
          (asserts! (>= block-height (get eta queued)) ERR_EXECUTION_TOO_EARLY)
          (asserts! (<= block-height (+ (get eta queued) (var-get GRACE_PERIOD))) ERR_EXECUTION_EXPIRED)
          
          ;; Execute
          (let ((result (contract-call? (get target queued) 
                           (unwrap-panic (from-consensus-buff? (get data queued))) 
                           (get value queued))))
            (map-delete queue {tx-id: tx-id})
            result
          )
        )
        (err ERR_TX_NOT_FOUND)
      )
    )
  )
)

;; ===========================================
;; ADMIN FUNCTIONS
;; ===========================================
(define-public (set-delay (new-delay uint))
  (begin
    (asserts! (is-owner) ERR_NOT_OWNER)
    (asserts! (>= new-delay MIN_DELAY) ERR_DELAY_TOO_SHORT)
    (asserts! (<= new-delay MAX_DELAY) ERR_DELAY_TOO_LONG)
    
    (var-set delay new-delay)
    (ok true)
  )
)
