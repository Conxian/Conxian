;; @desc Core integration contract that coordinates all token operations
;; across the Conxian 5-token ecosystem (CXD, CXVG, CXLP, CXTR, CXS).
;;
;; @features
;; - Unified token operation tracking
;; - Cross-system coordination
;; - Emergency coordination
;; - User status aggregation
;; - Revenue distribution triggers

(use-trait rbac-trait .core-traits.rbac-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u1001)
(define-constant ERR_INVALID_TOKEN u3006)
(define-constant ERR_SYSTEM_PAUSED u1003)
(define-constant ERR_INVALID_AMOUNT u8001)
(define-constant ERR_COORDINATOR_ERROR u1000)
(define-constant MAX_TOKENS u5)
(define-constant COORDINATOR_VERSION "1.0.0")

;; Token Constants
(define-constant CXD_TOKEN .cxd-token)
(define-constant CXVG_TOKEN .cxvg-token)
(define-constant CXLP_TOKEN .cxlp-token)
(define-constant CXTR_TOKEN .cxtr-token)
(define-constant CXS_TOKEN .cxs-token)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var revenue-distributor principal tx-sender)
(define-data-var last-operation-id uint u0)
(define-data-var total-registered-tokens uint u0)
(define-data-var total-users uint u0)

;; --- Data Maps ---
(define-map registered-tokens principal bool)

(define-map token-metadata
  principal
  {
    symbol: (string-ascii 10),
    decimals: uint,
    total-supply: uint,
    is-active: bool,
    last-activity: uint
  }
)

(define-map user-activity
  principal
  {
    last-interaction: uint,
    total-volume: uint,
    token-count: uint,
    reputation-score: uint
  }
)

(define-map cross-token-operations
  uint
  {
    user: principal,
    tokens: (list 5 principal),
    operation-type: (string-ascii 32),
    timestamp: uint,
    total-value: uint,
    status: (string-ascii 16)
  }
)

;; --- Read-Only Functions ---
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

(define-read-only (get-system-health)
  {
    is-paused: (var-get paused),
    emergency-mode: (var-get emergency-mode),
    total-registered-tokens: (var-get total-registered-tokens),
    total-users: (var-get total-users),
    coordinator-version: COORDINATOR_VERSION
  }
)

;; --- Private Helper Functions ---
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (when-not-paused)
  (if (var-get paused)
    (err ERR_SYSTEM_PAUSED)
    (ok true)
  )
)

(define-private (when-not-emergency)
  (if (var-get emergency-mode)
    (err ERR_COORDINATOR_ERROR)
    (ok true)
  )
)

(define-private (validate-token (token principal))
  (if (default-to false (map-get? registered-tokens token))
    (ok true)
    (err ERR_INVALID_TOKEN)
  )
)

(define-private (update-user-activity (user principal) (volume uint))
  (let (
    (existing-activity (map-get? user-activity user))
    (current-activity (default-to
      {
        last-interaction: block-height,
        total-volume: u0,
        token-count: u0,
        reputation-score: u1000
      }
      existing-activity
    ))
  )
    (if (is-none existing-activity)
      (var-set total-users (+ (var-get total-users) u1))
      true
    )
    (map-set user-activity user {
      last-interaction: block-height,
      total-volume: (+ (get total-volume current-activity) volume),
      token-count: (get token-count current-activity),
      reputation-score: (get reputation-score current-activity)
    })
    true
  )
)

;; --- Public Functions ---
(define-public (register-token (token principal) (symbol (string-ascii 10)) (decimals uint))
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (if (is-none (map-get? registered-tokens token))
      (begin
        (var-set total-registered-tokens (+ (var-get total-registered-tokens) u1))
        (map-set registered-tokens token true)
        (map-set token-metadata token {
          symbol: symbol,
          decimals: decimals,
          total-supply: u0,
          is-active: true,
          last-activity: block-height
        })
        (ok true)
      )
      (ok true)
    )
  )
)

(define-public (update-token-activity (token principal) (supply uint))
  (begin
    (try! (when-not-paused))
    (try! (validate-token token))
    (map-set token-metadata token
      (merge (unwrap-panic (map-get? token-metadata token)) {
        total-supply: supply,
        last-activity: block-height
      })
    )
    (ok true)
  )
)

(define-public (on-transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (try! (when-not-paused))
    (try! (validate-token contract-caller))
    (update-user-activity sender amount)
    (update-user-activity recipient amount)
    (ok true)
  )
)

(define-public (on-mint (amount uint) (recipient principal))
  (begin
    (try! (when-not-paused))
    (try! (validate-token contract-caller))
    (update-user-activity recipient amount)
    (let ((meta (unwrap-panic (map-get? token-metadata contract-caller))))
         (map-set token-metadata contract-caller (merge meta {
             total-supply: (+ (get total-supply meta) amount),
             last-activity: block-height
         }))
    )
    (ok true)
  )
)

(define-public (on-burn (amount uint) (sender principal))
  (begin
    (try! (when-not-paused))
    (try! (validate-token contract-caller))
    (update-user-activity sender amount)
    (let ((meta (unwrap-panic (map-get? token-metadata contract-caller))))
         (map-set token-metadata contract-caller (merge meta {
             total-supply: (if (>= (get total-supply meta) amount) (- (get total-supply meta) amount) u0),
             last-activity: block-height
         }))
    )
    (ok true)
  )
)

(define-public (on-dimensional-yield (amount uint) (start-height uint) (end-height uint))
    (ok true)
)

(define-public (coordinate-multi-token-operation
    (user principal)
    (tokens (list 5 principal))
    (operation-type (string-ascii 32))
    (total-value uint)
  )
  (let (
        (new-op-id (+ (var-get last-operation-id) u1))
        (token-count (len tokens))
       )
    (try! (when-not-paused))
    (try! (when-not-emergency))

    (asserts! (>= token-count u1) (err ERR_INVALID_AMOUNT))
    (asserts! (<= token-count MAX_TOKENS) (err ERR_INVALID_AMOUNT))

    (map-set cross-token-operations new-op-id {
      user: user,
      tokens: tokens,
      operation-type: operation-type,
      timestamp: block-height,
      total-value: total-value,
      status: "initiated"
    })
    (var-set last-operation-id new-op-id)

    (update-user-activity user total-value)

    (if (is-eq operation-type "yield-claim")
      (try! (trigger-revenue-distribution (unwrap-panic (element-at tokens u0)) total-value))
      true
    )
    (ok new-op-id)
  )
)

(define-public (trigger-revenue-distribution (token principal) (amount uint))
  (begin
    (try! (when-not-paused))
    (try! (validate-token token))

    ;; Call revenue distributor - commented out until revenue distributor contract exists
    ;; (try! (contract-call? .revenue-distributor distribute-revenue token amount))

    ;; Update token activity
    (try! (update-token-activity token amount))
    (ok true)
  )
)

(define-public (emergency-pause-system)
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (var-set paused true)
    (ok true)
  )
)

(define-public (emergency-resume-system)
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (var-set paused false)
    (ok true)
  )
)

(define-public (activate-emergency-mode)
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (var-set emergency-mode true)
    (ok true)
  )
)

(define-public (deactivate-emergency-mode)
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (var-set emergency-mode false)
    (ok true)
  )
)

(define-public (initialize-system)
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (try! (when-not-paused))

    (try! (register-token CXD_TOKEN "CXD" u6))
    (try! (register-token CXVG_TOKEN "CXVG" u6))
    (try! (register-token CXLP_TOKEN "CXLP" u6))
    (try! (register-token CXTR_TOKEN "CXTR" u6))
    (try! (register-token CXS_TOKEN "CXS" u6))
    (ok "System initialized with 5 core tokens")
  )
)
