;; risk-manager.clar
;; Risk management for the dimensional engine

(use-trait risk-trait .risk.risk-trait)
(use-trait oracle-trait .oracle.oracle-trait)
(use-trait dimensional-trait .dimensional.dimensional-trait)

;; Helpers
(define-private (abs-int (x int))
  (begin
    (if (>= x 0) x (- 0 x))
  )
)


;; ===== Type Definitions =====
(define-constant LOW u0)
(define-constant MEDIUM u1)
(define-constant HIGH u2)
(define-constant EXTREME u3)

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var max-leverage uint u2000)  ;; 20x
(define-data-var maintenance-margin uint u500)  ;; 5%
(define-data-var liquidation-threshold uint u8000)  ;; 80%
(define-data-var max-position-size uint u1000000000000)  ;; 1M with 6 decimals

;; ===== Core Functions =====
(define-public (validate-position
    (position {collateral: uint, size: int, entry-price: uint})
    (current-price uint)
  )
  (begin
    (let (
      (size-abs-i (abs-int (get size position)))
      (size-abs (to-uint size-abs-i))
      (collateral (get collateral position))
      (notional-value (/ (* size-abs current-price) (pow u10 u8)))  ;; Adjust for decimals
      (leverage (/ (* notional-value u100) collateral))
    )
      ;; Validate leverage
      (asserts! (<= leverage (var-get max-leverage)) (err u2000))

      ;; Validate position size
      (asserts! (<= size-abs (var-get max-position-size)) (err u2001))

      ;; Validate margin requirements
      (let ((initial-margin-required (/ (* notional-value (var-get maintenance-margin)) u10000)))
        (asserts! (>= collateral initial-margin-required) (err u2002))
      )

      (ok true)
    )
  )
)

(define-read-only (get-liquidation-price
    (position {collateral: uint, size: int, entry-price: uint})
  )
  (begin
    (let (
      (size-i (get size position))
      (collateral (get collateral position))
      (is-long (> size-i 0))
      (size-abs (to-uint (abs-int size-i)))

      (liquidation-price
        (if is-long
          ;; Long position liquidation price
          (/ (* (var-get liquidation-threshold) collateral) size-abs)
          ;; Short position liquidation price
          (/ (* collateral (var-get liquidation-threshold))
             (- (* size-abs (var-get liquidation-threshold)) (* collateral u10000)))
        )
      )
    )
      (ok liquidation-price)
    )
  )
)

;; ===== Admin Functions =====
(define-public (set-max-leverage (leverage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1000))
    (asserts! (>= leverage u100) (err u2003))  ;; Min 1x
    (var-set max-leverage leverage)
    (ok true)
  )
)

(define-public (set-maintenance-margin (margin uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1000))
    (asserts! (and (>= margin u100) (<= margin u5000)) (err u2004))  ;; Between 1% and 50%
    (var-set maintenance-margin margin)
    (ok true)
  )
)

(define-public (set-liquidation-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1000))
    (asserts! (and (>= threshold u5000) (<= threshold u9500)) (err u2005))  ;; Between 50% and 95%
    (var-set liquidation-threshold threshold)
    (ok true)
  )
)

(define-public (set-max-position-size (size uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1000))
    (var-set max-position-size size)
    (ok true)
  )
)

