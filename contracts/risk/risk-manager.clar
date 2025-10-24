;; risk-manager.clar
;; Risk management for the dimensional engine

(use-trait risk-trait .all-traits.risk-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait dimensional-trait .all-traits.dimensional-trait)

(impl-trait risk-trait)

;; ===== Type Definitions =====
(define-types
  (risk-level (enum
    (LOW)
    (MEDIUM)
    (HIGH)
    (EXTREME)
  ))
)

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
  (let (
    (size (abs (get position size)))
    (collateral (get position collateral))
    (notional-value (/ (* size current-price) (pow u10 u8)))  ;; Adjust for decimals
    (leverage (/ (* notional-value u100) collateral))
  )
    ;; Validate leverage
    (asserts! (<= leverage (var-get max-leverage)) (err u2000))

    ;; Validate position size
    (asserts! (<= size (var-get max-position-size)) (err u2001))

    ;; Validate margin requirements
    (let ((initial-margin-required (/ (* notional-value (var-get maintenance-margin)) u10000)))
      (asserts! (>= collateral initial-margin-required) (err u2002))
    )

    (ok true)
  )
)

(define-read-only (get-liquidation-price
    (position {collateral: uint, size: int, entry-price: uint})
  )
  (let (
    (size (get position size))
    (collateral (get position collateral))
    (is-long (> size 0))
    (size-abs (abs size))

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
