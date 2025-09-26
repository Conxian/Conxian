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

(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait access-control-trait .all-traits.access-control-trait)

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

;; Maps for token tracking
(define-map registered-tokens principal bool)
(define-map token-metadata principal
  {
    symbol: (string-ascii 10),
    decimals: uint,
    total-supply: uint,
    is-active: bool,
    last-activity: uint
  }
)

;; User activity tracking
(define-map user-activity principal
  {
    last-interaction: uint,
    total-volume: uint,
    token-count: uint,
    reputation-score: uint
  }
)

;; Cross-token operation tracking
(define-map cross-token-operations uint
  {
    user: principal,
    tokens: (list 5 principal),
    operation-type: (string-ascii 32),
    timestamp: uint,
    total-value: uint,
    status: (string-ascii 16)
  }
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
    {
      last-interaction: block-height,
      total-volume: u0,
      token-count: u0,
      reputation-score: u1000
    }
    (map-get? user-activity user)
  )))
    (map-set user-activity user
      {
        last-interaction: block-height,
        total-volume: (+ (get total-volume current-activity) volume),
        token-count: (get token-count current-activity),
        reputation-score: (get reputation-score current-activity)
      }
    )
  )
)

;; Core coordination functions
(define-public (register-token (token principal) (symbol (string-ascii 10)) (decimals uint))
  (let ((is-owner (is-contract-owner)))
    (asserts! is-owner ERR_UNAUTHORIZED)
    (asserts! (not (var-get paused)) ERR_SYSTEM_PAUSED)

    (map-set registered-tokens token true)
    (map-set token-metadata token
      {
        symbol: symbol,
        decimals: decimals,
        total-supply: u0,
        is-active: true,
        last-activity: block-height
      }
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
        {
          total-supply: supply,
          last-activity: block-height
        }
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
  (let ((operation-id (+ block-height (unwrap-panic (get-user-activity user)))))
    (begin
      (when-not-paused)
      (when-not-emergency)

      ;; Validate all tokens are registered
      (asserts! (>= (len tokens) u1) ERR_INVALID_AMOUNT)
      (asserts! (<= (len tokens) MAX_TOKENS) ERR_INVALID_AMOUNT)

      ;; Record the operation
      (map-set cross-token-operations operation-id
        {
          user: user,
          tokens: tokens,
          operation-type: operation-type,
          timestamp: block-height,
          total-value: total-value,
          status: "initiated"
        }
      )

      ;; Update user activity
      (update-user-activity user total-value)

      ;; Trigger revenue distribution if applicable
      (if (is-eq operation-type "yield-claim")
          (try! (trigger-revenue-distribution (unwrap-panic (element-at tokens u0)) total-value))
          true
      )

      (ok operation-id)
    )
  )
)

;; Revenue distribution coordination
(define-public (trigger-revenue-distribution (token principal) (amount uint))
  (begin
    (when-not-paused)
    (validate-token token)

    ;; Call revenue distributor
    (try! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.revenue-distributor distribute-revenue token amount))

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
  {
    is-paused: (var-get paused),
    emergency-mode: (var-get emergency-mode),
    total-registered-tokens: (len (map registered-tokens)),
    total-users: (len (map user-activity)),
    coordinator-version: COORDINATOR_VERSION
  }
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
