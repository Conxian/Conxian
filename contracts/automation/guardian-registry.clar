(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_INVALID_AMOUNT (err u7001))
(define-constant ERR_UNKNOWN_GUARDIAN (err u7002))

(define-data-var contract-owner principal tx-sender)

(define-data-var min-bond-tier-1 uint u100000000)
(define-data-var min-bond-tier-2 uint u1000000000)

(define-data-var reward-admin principal tx-sender)

(define-map guardian-rewards
  principal
  {
    accrued: uint,
  }
)

(define-map guardians
  principal
  {
    bonded-cxd: uint,
    active: bool,
    tier: uint,
  }
)

(define-private (compute-tier (bonded uint))
  (if (>= bonded (var-get min-bond-tier-2))
      u2
      (if (>= bonded (var-get min-bond-tier-1))
          u1
          u0)))

(define-public (register-guardian (guardian principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender guardian) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let
      (
        (current (default-to
                   { bonded-cxd: u0, active: false, tier: u0 }
                   (map-get? guardians guardian)))
        (new-bond (+ (get bonded-cxd current) amount))
      )
      (map-set guardians guardian
        {
          bonded-cxd: new-bond,
          active: (> new-bond u0),
          tier: (compute-tier new-bond),
        }
      )
      (ok true)
    )
  )
)

(define-public (unbond-guardian (guardian principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender guardian) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let
      (
        (current-opt (map-get? guardians guardian))
      )
      (asserts! (is-some current-opt) ERR_UNKNOWN_GUARDIAN)
      (let
        (
          (current (unwrap-panic current-opt))
          (current-bond (get bonded-cxd current))
        )
        (asserts! (>= current-bond amount) ERR_INVALID_AMOUNT)
        (let
          (
            (new-bond (- current-bond amount))
          )
          (map-set guardians guardian
            {
              bonded-cxd: new-bond,
              active: (> new-bond u0),
              tier: (compute-tier new-bond),
            }
          )
          (ok true)
        )
      )
    )
  )
)

(define-public (slash-guardian (guardian principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let
      (
        (current-opt (map-get? guardians guardian))
      )
      (asserts! (is-some current-opt) ERR_UNKNOWN_GUARDIAN)
      (let
        (
          (current (unwrap-panic current-opt))
          (current-bond (get bonded-cxd current))
        )
        (let
          (
            (deduction (if (>= current-bond amount) amount current-bond))
            (new-bond (- current-bond (if (>= current-bond amount) amount current-bond)))
          )
          (map-set guardians guardian
            {
              bonded-cxd: new-bond,
              active: (> new-bond u0),
              tier: (compute-tier new-bond),
            }
          )
          (ok true)
        )
      )
    )
  )
)

(define-read-only (is-guardian (who principal))
  (let
    (
      (g (map-get? guardians who))
    )
    (ok (if (is-some g)
            (get active (unwrap-panic g))
            false)))
)

(define-read-only (get-guardian-tier (who principal))
  (let
    (
      (g (map-get? guardians who))
    )
    (ok (if (is-some g)
            (some (get tier (unwrap-panic g)))
            none)))
)

(define-read-only (get-guardian-info (who principal))
  (ok (map-get? guardians who))
)

(define-public (set-min-bond-tiers (tier-1 uint) (tier-2 uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> tier-1 u0) ERR_INVALID_AMOUNT)
    (asserts! (>= tier-2 tier-1) ERR_INVALID_AMOUNT)
    (var-set min-bond-tier-1 tier-1)
    (var-set min-bond-tier-2 tier-2)
    (ok true)
  )
)

(define-public (set-reward-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set reward-admin new-admin)
    (ok true)
  )
)

(define-public (credit-reward (guardian principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get reward-admin)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let
      (
        (g (map-get? guardians guardian))
      )
      (asserts! (is-some g) ERR_UNKNOWN_GUARDIAN)
      (let
        (
          (current (default-to { accrued: u0 } (map-get? guardian-rewards guardian)))
        )
        (map-set guardian-rewards guardian
          {
            accrued: (+ (get accrued current) amount),
          }
        )
        (ok true)
      )
    )
  )
)

(define-read-only (get-accrued-rewards (who principal))
  (let
    (
      (entry (map-get? guardian-rewards who))
    )
    (ok (if (is-some entry)
            (get accrued (unwrap-panic entry))
            u0))
  )
)

(define-public (claim-rewards (guardian principal))
  (begin
    (asserts! (is-eq tx-sender guardian) ERR_UNAUTHORIZED)
    (let
      (
        (entry (map-get? guardian-rewards guardian))
      )
      (if (is-some entry)
          (let
            (
              (value (get accrued (unwrap-panic entry)))
            )
            (begin
              (map-set guardian-rewards guardian { accrued: u0 })
              (ok value)))
          (ok u0)))
  )
)
