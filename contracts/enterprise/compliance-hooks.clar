

;; compliance-hooks.clar
;; Enterprise compliance hooks and registries for KYC/KYB, sanction screening, and whale gating references.

(define-constant ERR_UNAUTHORIZED (err u92001))
(define-constant ERR_INVALID_INPUT (err u92002))

;; Admin
(define-data-var admin principal tx-sender)

;; Enterprise KYB registry: principals approved for enterprise-grade access
(define-map enterprise-kyb principal bool)

;; KYC attestations for users (basic boolean; real systems can include versioned attestations)
(define-map user-kyc principal { version: uint, attested-by: principal, timestamp: uint, status: bool })

;; Sanction screening flags
(define-map sanctioned principal bool)

;; Whale gating thresholds (BTC-equivalent). Units are BTC whole units for simplicity.
(define-data-var whale-threshold-btc uint u100)

;; =====================
;; Admin functions
;; =====================

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-whale-threshold (btc uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> btc u0) ERR_INVALID_INPUT)
    (var-set whale-threshold-btc btc)
    (ok true)
  )
)

;; Enterprise KYB
(define-public (add-enterprise (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set enterprise-kyb p true)
    (ok true)
  )
)

(define-public (remove-enterprise (p principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-delete enterprise-kyb p)
    (ok true)
  )
)

;; User KYC
(define-public (attest-kyc (user principal) (version uint) (attested-by principal) (status bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set user-kyc user { version: version, attested-by: attested-by, timestamp: block-height, status: status })
    (ok true)
  )
)

;; Sanction screening
(define-public (set-sanctioned (user principal) (flag bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set sanctioned user flag)
    (ok true)
  )
)

;; =====================
;; Read-only checks
;; =====================

(define-read-only (is-enterprise (p principal))
  (default-to false (map-get? enterprise-kyb p))
)

(define-read-only (is-kyc (user principal))
  (default-to false (get status (map-get? user-kyc user)))
)

(define-read-only (is-sanctioned (user principal))
  (default-to false (map-get? sanctioned user))
)

;; Simple whale check: caller provides BTC-equivalent activity (computed off-chain or by upstream modules)
(define-read-only (is-whale (btc-equivalent uint))
  (>= btc-equivalent (var-get whale-threshold-btc))
)

;; Composite compliance gating for sensitive operations
;; Inputs:
;; - user principal
;; - btc-equivalent activity (optional aggregation provided by upstream)
;; Returns true if user passes KYC and is not sanctioned.
;; Whale detection prints an event for downstream gating; enterprise paths can require is-enterprise and is-kyc.
(define-read-only (is-compliant-for-operation (user principal) (btc-equivalent uint))
  (let ((kyc (is-kyc user))
        (san (default-to false (map-get? sanctioned user)))
        (whale (>= btc-equivalent (var-get whale-threshold-btc))))
    (begin
      (if whale (begin (print { event: "whale-detected", user: user, btc: btc-equivalent }) true) true)
      (and kyc (not san))
    )
  )
)
