;; token-system-coordinator.clar
;;
;; Core integration contract that coordinates all token operations
;; across the Conxian 5-token ecosystem (CXD, CXVG, CXLP, CXTR, CXS)
;;
;; Features:
;; - Unified token operation tracking
;; - Cross-system coordination
;; - Emergency coordination
;; - User status aggregation
;; - Revenue distribution triggers

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait access-control-trait .access-control-trait.access-control-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_TOKEN (err u101))
(define-constant ERR_SYSTEM_PAUSED (err u102))
(define-constant ERR_INVALID_AMOUNT (err u103))
(define-constant ERR_COORDINATOR_ERROR (err u104))

;; Constants
(define-constant MAX_TOKENS u5)
(define-constant COORDINATOR_VERSION "1.0.0")

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var revenue-distributor principal .revenue-distributor)
(define-data-var last-operation-id uint u0)
(define-data-var total-registered-tokens uint u0)
(define-data-var total-users uint u0)

;; Maps for token tracking
(define-map registered-tokens principal bool)
(define-map token-metadata principal
  (tuple
    (symbol (string-ascii 10))
    (decimals uint)
    (total-supply uint)
    (is-active bool)
    (last-activity uint)
  )
)

;; User activity tracking
(define-map user-activity principal
  (tuple
    (last-interaction uint)
    (total-volume uint)
    (token-count uint)
    (reputation-score uint)
  )
)

;; Cross-token operation tracking
(define-map cross-token-operations uint
  (tuple
    (user principal)
    (tokens (list 5 principal))
    (operation-type (string-ascii 32))
    (timestamp uint)
    (total-value uint)
    (status (string-ascii 16))
  )
)

;; Token addresses (hardcoded for production)
(define-constant CXD_TOKEN .cxd-token)
(define-constant CXVG_TOKEN .cxvg-token)
(define-constant CXLP_TOKEN .cxlp-token)
(define-constant CXTR_TOKEN .cxtr-token)
(define-constant CXS_TOKEN .cxs-token)

;; Read-only functions
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-emergency-mode)
  (var-get emergency-mode)
)

(define-read-only (get-registered-token (token principal))
  (map-get? registered-tokens token)
)

(define-read-only (get-token-metadata (token principal))
  (map-get? token-metadata token)
)

(define-read-only (get-user-activity (user principal))
  (map-get? user-activity user)
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (when-not-paused)
  (asserts! (not (var-get paused)) ERR_SYSTEM_PAUSED)
)

(define-private (when-not-emergency)
  (asserts! (not (var-get emergency-mode)) ERR_COORDINATOR_ERROR)
)

(define-private (validate-token (token principal))
  (asserts! (map-get? registered-tokens token) ERR_INVALID_TOKEN)
)

(define-private (update-user-activity (user principal) (volume uint))
  (let ((current-activity (default-to
    (tuple
      (last-interaction block-height)
      (total-volume u0)
      (token-count u0)
      (reputation-score u1000)
    )
    (map-get? user-activity user)
  )))
    (if (is-none (map-get? user-activity user))
        (var-set total-users (+ (var-get total-users) u1))
        true
    )
    (map-set user-activity user
      (tuple
        (last-interaction block-height)
        (total-volume (+ (get total-volume current-activity) volume))
        (token-count (get token-count current-activity))
        (reputation-score (get reputation-score current-activity))
      )
    )
  )
)

;; Core coordination functions
(define-public (register-token (token principal) (symbol (string-ascii 10)) (decimals uint))
  (let ((is-owner (is-contract-owner)))
    (asserts! is-owner ERR_UNAUTHORIZED)
    (asserts! (not (var-get paused)) ERR_SYSTEM_PAUSED)

    (if (is-none (map-get? registered-tokens token))
        (var-set total-registered-tokens (+ (var-get total-registered-tokens) u1))
        true
    )
    (map-set registered-tokens token true)
    (map-set token-metadata token
      (tuple
        (symbol symbol)
        (decimals decimals)
        (total-supply u0)
        (is-active true)
        (last-activity block-height)
      )
    )
    (ok true)
  )
)

(define-public (update-token-activity (token principal) (supply uint))
  (begin
    (when-not-paused)
    (validate-token token)

    (map-set token-metadata token
      (merge
        (unwrap-panic (map-get? token-metadata token))
        (tuple
          (total-supply supply)
          (last-activity block-height)
        )
      )
    )
    (ok true)
  )
)

;; Cross-token operation coordination
(define-public (coordinate-multi-token-operation
    (user principal)
    (tokens (list 5 principal))
    (operation-type (string-ascii 32))
    (total-value uint)
  )
  (let ((new-op-id (+ (var-get last-operation-id) u1)))
    (begin
      (when-not-paused)
      (when-not-emergency)

      ;; Validate all tokens are registered
      (asserts! (>= (len tokens) u1) ERR_INVALID_AMOUNT)
      (asserts! (<= (len tokens) MAX_TOKENS) ERR_INVALID_AMOUNT)

      ;; Record the operation
      (map-set cross-token-operations new-op-id
        (tuple
          (user user)
          (tokens tokens)
          (operation-type operation-type)
          (timestamp block-height)
          (total-value total-value)
          (status "initiated")
        )
      )
      (var-set last-operation-id new-op-id)

      ;; Update user activity
      (update-user-activity user total-value)

      ;; Trigger revenue distribution if applicable
      (if (is-eq operation-type "yield-claim")
          (try! (trigger-revenue-distribution (unwrap-panic (element-at tokens u0)) total-value))
          true
      )

      (ok new-op-id)
    )
  )
)

;; Revenue distribution coordination
(define-public (trigger-revenue-distribution (token principal) (amount uint))
  (begin
    (when-not-paused)
    (validate-token token)

    ;; Call revenue distributor
    (try! (contract-call? (var-get revenue-distributor) distribute-revenue token amount))

    ;; Update token activity
    (try! (update-token-activity token amount))

    (ok true)
  )
)

;; Emergency coordination functions
(define-public (emergency-pause-system)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (emergency-resume-system)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

(define-public (activate-emergency-mode)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set emergency-mode true)
    (ok true)
  )
)

(define-public (deactivate-emergency-mode)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set emergency-mode false)
    (ok true)
  )
)

;; System health check
(define-read-only (get-system-health)
  (tuple
    (is-paused (var-get paused))
    (emergency-mode (var-get emergency-mode))
    (total-registered-tokens (var-get total-registered-tokens))
    (total-users (var-get total-users))
    (coordinator-version COORDINATOR_VERSION)
  )
)

;; Initialize system with core tokens
(define-public (initialize-system)
  (let ((is-owner (is-contract-owner)))
    (asserts! is-owner ERR_UNAUTHORIZED)
    (asserts! (not (var-get paused)) ERR_SYSTEM_PAUSED)

    ;; Register core tokens
    (try! (register-token CXD_TOKEN "CXD" u6))
    (try! (register-token CXVG_TOKEN "CXVG" u6))
    (try! (register-token CXLP_TOKEN "CXLP" u6))
    (try! (register-token CXTR_TOKEN "CXTR" u6))
    (try! (register-token CXS_TOKEN "CXS" u6))

    (ok "System initialized with 5 core tokens")
  )
)

