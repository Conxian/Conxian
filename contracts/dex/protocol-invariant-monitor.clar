;; protocol-invariant-monitor.clar
;; Protocol invariant monitoring and circuit breaker system
;; Monitors key invariants and triggers automated protection mechanisms
;; Refactored for real functionality.

;; --- Traits ---
(use-trait ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.sip-010-ft-trait)
(use-trait staking-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.staking-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u10000) ;; For BPS calculations

;; Invariant thresholds
(define-constant MAX_STAKING_CONCENTRATION_BPS u3000) ;; 30% max single user staking
(define-constant TVL_CHANGE_THRESHOLD_BPS u2000) ;; 20% TVL drop/spike triggers warning

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u900))
(define-constant ERR_INVARIANT_VIOLATION (err u901))
(define-constant ERR_CIRCUIT_BREAKER_ACTIVE (err u902))
(define-constant ERR_ALREADY_PAUSED (err u904))
(define-constant ERR_NOT_PAUSED (err u905))
(define-constant ERR_CONTRACT_NOT_SET (err u906))

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var emergency-operator principal CONTRACT_OWNER)
(define-data-var protocol-paused bool false)
(define-data-var last-tvl uint u0) ;; Last recorded Total Value Locked

;; Contract Dependencies
(define-data-var staking-contract-ref (optional principal) none)
(define-data-var lending-system-ref (optional principal) none)

;; --- Invariant Violation Tracking ---
(define-map invariant-violations uint { invariant-type: (string-ascii 40), detected-at: uint, value: uint, threshold: uint })
(define-data-var next-violation-id uint u1)

;; --- Admin Functions ---
(define-public (set-emergency-operator (operator principal))
  (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
  (var-set emergency-operator operator)
  (ok true))

(define-public (set-staking-contract (contract-address principal))
  (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
  (var-set staking-contract-ref (some contract-address))
  (ok true))

(define-public (set-lending-system (contract-address principal))
  (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
  (var-set lending-system-ref (some contract-address))
  (ok true))

;; --- Invariant Checking Functions ---

;; Checks that the total supply of the staking token (xCXD) correctly reflects the underlying staked CXD.
(define-private (check-staking-invariant)
  (let ((staking-contract (unwrap! (var-get staking-contract-ref) ERR_CONTRACT_NOT_SET)))
    (let ((protocol-info (try! (contract-call? staking-contract get-protocol-info)))
          (xcxd-supply (get total-supply protocol-info))
          (cxd-staked (get total-staked-cxd protocol-info))
          (rate (get exchange-rate protocol-info)))
      ;; Invariant: xcxd-supply * exchange_rate == cxd_staked
      (let ((expected-cxd (* xcxd-supply rate)))
        (asserts! (is-eq expected-cxd cxd-staked) (err ERR_INVARIANT_VIOLATION))
        (ok true)
      )
    )
  )
)

;; Checks for sudden, large changes in the lending protocol's Total Value Locked.
(define-private (check-tvl-invariant)
  (let ((lending-system (unwrap! (var-get lending-system-ref) ERR_CONTRACT_NOT_SET)))
    (let ((current-tvl (try! (contract-call? lending-system get-total-value-locked))))
      (let ((last-tvl (var-get last-tvl)))
        (if (> last-tvl u0)
          (let ((change-bps (/ (* (if (> current-tvl last-tvl) (- current-tvl last-tvl) (- last-tvl current-tvl)) PRECISION) last-tvl)))
            (if (> change-bps TVL_CHANGE_THRESHOLD_BPS)
              (record-violation "TVL change exceeded threshold" change-bps TVL_CHANGE_THRESHOLD_BPS)
              (ok true)
            )
          )
          (ok true)
        )
        (var-set last-tvl current-tvl)
      )
    )
  )
)

;; --- Violation Recording ---
(define-private (record-violation (invariant-type (string-ascii 40)) (value uint) (threshold uint))
  (let ((violation-id (var-get next-violation-id)))
    (map-set invariant-violations violation-id
      {
        invariant-type: invariant-type,
        detected-at: block-height,
        value: value,
        threshold: threshold
      }
    )
    (var-set next-violation-id (+ violation-id u1))
    (print { event: "invariant-violation", type: invariant-type, value: value, threshold: threshold })
    (err ERR_INVARIANT_VIOLATION)
  )
)

;; --- Circuit Breaker Functions ---
(define-public (trigger-emergency-pause)
  (begin
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                 (is-eq tx-sender (var-get emergency-operator))) ERR_UNAUTHORIZED)
    (asserts! (not (var-get protocol-paused)) ERR_ALREADY_PAUSED)
    (var-set protocol-paused true)
    (print { event: "protocol-paused", reason: "manual trigger" })
    (ok true)
  )
)

(define-public (resume-protocol)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (var-get protocol-paused) ERR_NOT_PAUSED)
    (var-set protocol-paused false)
    (print { event: "protocol-resumed" })
    (ok true)
  )
)

;; --- Monitoring Functions ---
(define-public (run-health-check)
  (begin
    (try! (check-staking-invariant))
    (try! (check-tvl-invariant))
    ;; Add other checks here as they are developed
    (ok true)
  )
)

;; --- Read-Only Functions ---
(define-read-only (is-protocol-paused)
  (ok (var-get protocol-paused))
)

(define-read-only (get-violation (violation-id uint))
  (map-get? invariant-violations violation-id)
)
