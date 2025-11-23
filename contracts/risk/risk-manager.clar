;; @desc This contract is responsible for all risk management functions,
;; including setting risk parameters, calculating liquidation prices, and checking position health.

(use-trait risk-manager-trait .risk-management.risk-manager-trait)
(use-trait rbac-trait .core-protocol.02-core-protocol.rbac-trait-trait)

(impl-trait .risk-management.risk-manager-trait)

;; @constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_PARAMETERS (err u1005))
(define-constant MIN_LEVERAGE u100)

;; @data-vars
(define-data-var max-leverage uint u2000) ;; 20x
(define-data-var maintenance-margin uint u500) ;; 5%
(define-data-var liquidation-threshold uint u8000) ;; 80%
(define-data-var min-liquidation-reward uint u100) ;; 0.1%
(define-data-var max-liquidation-reward uint u1000)  ;; 1%
(define-data-var insurance-fund principal tx-sender)

;; --- Public Functions ---
(define-public (set-risk-parameters (new-max-leverage uint) (new-maintenance-margin uint) (new-liquidation-threshold uint))
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts! (and (>= new-max-leverage MIN_LEVERAGE) (<= new-max-leverage u5000)) ERR_INVALID_PARAMETERS)
    (asserts! (and (> new-maintenance-margin u0) (< new-maintenance-margin u10000)) ERR_INVALID_PARAMETERS)
    (asserts! (and (> new-liquidation-threshold new-maintenance-margin) (<= new-liquidation-threshold u10000)) ERR_INVALID_PARAMETERS)

    (var-set max-leverage new-max-leverage)
    (var-set maintenance-margin new-maintenance-margin)
    (var-set liquidation-threshold new-liquidation-threshold)

    (ok true)
  )
)

(define-public (set-liquidation-rewards (min-reward uint) (max-reward uint))
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (asserts! (and (> min-reward u0) (<= min-reward max-reward) (<= max-reward u5000)) ERR_INVALID_PARAMETERS)

    (var-set min-liquidation-reward min-reward)
    (var-set max-liquidation-reward max-reward)

    (ok true)
  )
)

(define-public (update-position-value (user principal) (new-value uint))
  (begin
    (try! (check-role "ROLE_ADMIN"))
    (var-set insurance-fund fund)
    (ok true)
  )
)

(define-read-only (calculate-liquidation-price (position {entry-price: uint, leverage: uint, is-long: bool}))
  (let (
    (m-margin (var-get maintenance-margin))
    (entry-price (get entry-price position))
    (leverage (get leverage position))
    (is-long (get is-long position))
  )
    (if is-long
      (ok (* entry-price (/ (+ (- (* leverage u10000) u10000) m-margin) (* leverage u10000))))
      (ok (* entry-price (/ (- (+ (* leverage u10000) u10000) m-margin) (* leverage u10000))))
    )
  )
)

;; --- Private Functions ---
(define-private (check-role (role (string-ascii 32)))
  (contract-call? .core-protocol.rbac-trait-trait has-role tx-sender role)
)
