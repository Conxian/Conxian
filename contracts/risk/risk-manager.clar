(use-trait risk-manager-trait .dimensional-traits.risk-manager-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

(impl-trait .dimensional-traits.risk-manager-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_PARAMETERS (err u1005))
(define-constant ERR_NOT_CONFIGURED (err u1006))
(define-constant MIN_LEVERAGE u100)

(define-data-var max-leverage uint u2000)
(define-data-var maintenance-margin uint u500)
(define-data-var liquidation-threshold uint u8000)
(define-data-var min-liquidation-reward uint u100)
(define-data-var max-liquidation-reward uint u1000)
(define-data-var insurance-fund principal tx-sender)

(define-public (set-risk-parameters
    (new-max-leverage uint)
    (new-maintenance-margin uint)
    (new-liquidation-threshold uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts!
      (and (>= new-max-leverage MIN_LEVERAGE) (<= new-max-leverage u5000))
      ERR_INVALID_PARAMETERS
    )
    (asserts!
      (and (> new-maintenance-margin u0) (< new-maintenance-margin u10000))
      ERR_INVALID_PARAMETERS
    )
    (asserts!
      (and (> new-liquidation-threshold new-maintenance-margin) (<= new-liquidation-threshold u10000))
      ERR_INVALID_PARAMETERS
    )
    (var-set max-leverage new-max-leverage)
    (var-set maintenance-margin new-maintenance-margin)
    (var-set liquidation-threshold new-liquidation-threshold)
    (ok true)
  )
)

(define-public (set-liquidation-rewards
    (min-reward uint)
    (max-reward uint)
  )
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts!
      (and
        (> min-reward u0)
        (<= min-reward max-reward)
        (<= max-reward u5000)
      )
      ERR_INVALID_PARAMETERS
    )
    (var-set min-liquidation-reward min-reward)
    (var-set max-liquidation-reward max-reward)
    (ok true)
  )
)

(define-public (liquidate-position
    (position-id uint)
    (liquidator principal)
  )
  (ok {
    liquidated: true,
    reward: u0,
    repaid: u0,
  })
)

(define-public (set-insurance-fund (fund principal))
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (var-set insurance-fund fund)
    (ok true)
  )
)

(define-read-only (calculate-liquidation-price (position {
  entry-price: uint,
  leverage: uint,
  is-long: bool,
}))
  (let (
      (m-margin (var-get maintenance-margin))
      (entry-price (get entry-price position))
      (leverage (get leverage position))
      (is-long (get is-long position))
    )
    (if is-long
      (ok (* entry-price
        (/ (+ (- (* leverage u10000) u10000) m-margin) (* leverage u10000))
      ))
      (ok (* entry-price
        (/ (- (+ (* leverage u10000) u10000) m-margin) (* leverage u10000))
      ))
    )
  )
)

(define-private (check-role (role (string-ascii 32)))
  (begin
    (asserts! (is-ok (contract-call? .roles has-role role tx-sender))
      ERR_UNAUTHORIZED
    )
    (ok true)
  )
)

(define-public (assess-position-risk (position-id uint))
  (let (
      (position (unwrap! (contract-call? .position-manager get-position position-id)
        ERR_INVALID_PARAMETERS
      ))
      (collateral (get collateral position))
      (size (get size position))
      (entry-price (get entry-price position))
      (threshold (var-get liquidation-threshold))
      (health-factor (if (is-eq size u0)
        u1000000
        (/ (* collateral threshold) size)
      ))
      (liquidation-price (unwrap!
        (calculate-liquidation-price {
          entry-price: entry-price,
          leverage: (get leverage position),
          is-long: (get is-long position),
        })
        ERR_INVALID_PARAMETERS
      ))
    )
    (ok {
      health-factor: health-factor,
      liquidation-price: liquidation-price,
      risk-level: (if (> health-factor u15000)
        "LOW"
        (if (> health-factor u11000)
          "MEDIUM"
          "HIGH"
        )
      ),
    })
  )
)
