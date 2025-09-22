;; circuit-breaker.clar
;; Generic circuit breaker implementation

(impl-trait .circuit-breaker-trait.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u9400))
(define-constant ERR_CIRCUIT_OPEN (err u9401))
(define-constant ERR_INVALID_OPERATION (err u9402))

(define-data-var contract-owner principal tx-sender)
(define-data-var failure-threshold uint u500) ;; 50% failure rate
(define-data-var reset-timeout uint u100) ;; 100 blocks

(define-map circuit-states (string-ascii 64) { state: bool, last-checked: uint, successes: uint, failures: uint })

(define-public (check-circuit-state (operation (string-ascii 64)))
  (let ((circuit (default-to { state: true, last-checked: u0, successes: u0, failures: u0 } (map-get? circuit-states operation))))
    (if (and (not (get state circuit)) (> block-height (+ (get last-checked circuit) (var-get reset-timeout))))
      (begin
        (map-set circuit-states operation { state: true, last-checked: block-height, successes: u0, failures: u0 })
        (ok true)
      )
      (ok (get state circuit)))
  )
)

(define-public (record-success (operation (string-ascii 64)))
  (let ((circuit (default-to { state: true, last-checked: block-height, successes: u0, failures: u0 } (map-get? circuit-states operation))))
    (map-set circuit-states operation (merge circuit { successes: (+ (get successes circuit) u1) }))
    (ok true)
  )
)

(define-public (record-failure (operation (string-ascii 64)))
  (let ((circuit (default-to { state: true, last-checked: block-height, successes: u0, failures: u0 } (map-get? circuit-states operation))))
    (let ((new-failures (+ (get failures circuit) u1)))
      (let ((total-ops (+ (get successes circuit) new-failures)))
        (if (and (> total-ops u10) (> (* new-failures u1000) (* (var-get failure-threshold) total-ops)))
          (map-set circuit-states operation (merge circuit { state: false, last-checked: block-height, failures: new-failures }))
          (map-set circuit-states operation (merge circuit { failures: new-failures }))
        )
      )
    )
    (ok true)
  )
)

(define-read-only (get-failure-rate (operation (string-ascii 64)))
  (let ((circuit (default-to { state: true, last-checked: u0, successes: u0, failures: u0 } (map-get? circuit-states operation))))
    (let ((total-ops (+ (get successes circuit) (get failures circuit))))
      (if (> total-ops u0)
        (ok (/ (* (get failures circuit) u1000) total-ops))
        (ok u0)
      )
    )
  )
)

(define-read-only (get-circuit-state (operation (string-ascii 64)))
  (ok (default-to { state: true, last-checked: u0, successes: u0, failures: u0 } (map-get? circuit-states operation)))
)

(define-public (set-circuit-state (operation (string-ascii 64)) (state bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((circuit (default-to { state: true, last-checked: block-height, successes: u0, failures: u0 } (map-get? circuit-states operation))))
      (map-set circuit-states operation (merge circuit { state: state, last-checked: block-height }))
      (ok true)
    )
  )
)

(define-public (set-failure-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set failure-threshold threshold)
    (ok true)
  )
)

(define-public (set-reset-timeout (timeout uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set reset-timeout timeout)
    (ok true)
  )
)

(define-read-only (get-admin)
  (ok (var-get contract-owner))
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-admin)
    (ok true)
  )
)