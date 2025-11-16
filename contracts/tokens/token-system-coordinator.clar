;; @desc Core integration contract that coordinates all token operations
;; across the Conxian 5-token ecosystem (CXD, CXVG, CXLP, CXTR, CXS).
;;
;; @features
;; - Unified token operation tracking
;; - Cross-system coordination
;; - Emergency coordination
;; - User status aggregation
;; - Revenue distribution triggers

(use-trait rbac-trait .base-traits.rbac-trait)

;; @constants
;; @var ERR_UNAUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_UNAUTHORIZED u1001)
;; @var ERR_INVALID_TOKEN: The provided token is invalid.
(define-constant ERR_INVALID_TOKEN u3006)
;; @var ERR_SYSTEM_PAUSED: The system is currently paused.
(define-constant ERR_SYSTEM_PAUSED u1003)
;; @var ERR_INVALID_AMOUNT: The provided amount is invalid.
(define-constant ERR_INVALID_AMOUNT u8001)
;; @var ERR_COORDINATOR_ERROR: An error occurred in the coordinator.
(define-constant ERR_COORDINATOR_ERROR u1000)
;; @var MAX_TOKENS: The maximum number of tokens that can be registered.
(define-constant MAX_TOKENS u5)
;; @var COORDINATOR_VERSION: The version of the coordinator contract.
(define-constant COORDINATOR_VERSION "1.0.0")

;; @data-vars
;; @var CXD_TOKEN: The principal of the CXD token contract.
(define-constant CXD_TOKEN .cxd-token)
;; @var CXVG_TOKEN: The principal of the CXVG token contract.
(define-constant CXVG_TOKEN .cxvg-token)
;; @var CXLP_TOKEN: The principal of the CXLP token contract.
(define-constant CXLP_TOKEN .cxlp-token)
;; @var CXTR_TOKEN: The principal of the CXTR token contract.
(define-constant CXTR_TOKEN .cxtr-token)
;; @var CXS_TOKEN: The principal of the CXS token contract.
(define-constant CXS_TOKEN .cxs-token)
;; @var contract-owner: The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @var paused: A boolean indicating if the system is paused.
(define-data-var paused bool false)
;; @var emergency-mode: A boolean indicating if the system is in emergency mode.
(define-data-var emergency-mode bool false)
;; @var revenue-distributor: The principal of the revenue distributor contract.
(define-data-var revenue-distributor principal tx-sender)
;; @var last-operation-id: The ID of the last operation.
(define-data-var last-operation-id uint u0)
;; @var total-registered-tokens: The total number of registered tokens.
(define-data-var total-registered-tokens uint u0)
;; @var total-users: The total number of users.
(define-data-var total-users uint u0)
;; @var registered-tokens: A map of registered tokens.
(define-map registered-tokens principal bool)
;; @var token-metadata: A map of token metadata.
(define-map token-metadata principal {symbol: (string-ascii 10), decimals: uint, total-supply: uint, is-active: bool, last-activity: uint})
;; @var user-activity: A map of user activity.
(define-map user-activity principal {last-interaction: uint, total-volume: uint, token-count: uint, reputation-score: uint})
;; @var cross-token-operations: A map of cross-token operations.
(define-map cross-token-operations uint {user: principal, tokens: (list 5 principal), operation-type: (string-ascii 32), timestamp: uint, total-value: uint, status: (string-ascii 16)})

;; @desc Get the contract owner.
;; @returns (principal): The principal of the contract owner.
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; @desc Check if the system is paused.
;; @returns (bool): True if the system is paused, false otherwise.
(define-read-only (is-paused)
  (var-get paused)
)

;; @desc Check if the system is in emergency mode.
;; @returns (bool): True if the system is in emergency mode, false otherwise.
(define-read-only (get-emergency-mode)
  (var-get emergency-mode)
)

;; @desc Get a registered token.
;; @param token: The principal of the token.
;; @returns (optional bool): True if the token is registered, false otherwise.
(define-read-only (get-registered-token (token principal))
  (map-get? registered-tokens token)
)

;; @desc Get the metadata for a token.
;; @param token: The principal of the token.
;; @returns (optional { ... }): A tuple containing the token metadata, or none if the token is not registered.
(define-read-only (get-token-metadata (token principal))
  (map-get? token-metadata token)
)

;; @desc Get the activity for a user.
;; @param user: The principal of the user.
;; @returns (optional { ... }): A tuple containing the user's activity, or none if the user has no activity.
(define-read-only (get-user-activity (user principal))
  (map-get? user-activity user)
)

;; @desc Get the health of the system.
;; @returns ({ ... }): A tuple containing the system health.
(define-read-only (get-system-health)
  {is-paused: (var-get paused), emergency-mode: (var-get emergency-mode), total-registered-tokens: (var-get total-registered-tokens), total-users: (var-get total-users), coordinator-version: COORDINATOR_VERSION}
)

;; --- Private functions ---
;; @desc Check if the caller is the contract owner.
;; @returns (bool): True if the caller is the contract owner, false otherwise.
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; @desc Assert that the system is not paused.
(define-private (when-not-paused)
  (asserts! (not (var-get paused)) ERR_SYSTEM_PAUSED)
)

;; @desc Assert that the system is not in emergency mode.
(define-private (when-not-emergency)
  (asserts! (not (var-get emergency-mode)) ERR_COORDINATOR_ERROR)
)

;; @desc Validate that a token is registered.
;; @param token: The principal of the token.
(define-private (validate-token (token principal))
  (asserts! (default-to false (map-get? registered-tokens token)) ERR_INVALID_TOKEN)
)

;; @desc Update the activity for a user.
;; @param user: The principal of the user.
;; @param volume: The volume of the user's activity.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (update-user-activity (user principal) (volume uint))
  (let (
    (current-activity (default-to
      {last-interaction: block-height, total-volume: u0, token-count: u0, reputation-score: u1000}
      (map-get? user-activity user)
    ))
  )
    (if (is-none (map-get? user-activity user))
      (var-set total-users (+ (var-get total-users) u1))
      true
    )
    (map-set user-activity user
      {last-interaction: block-height, total-volume: (+ (get total-volume current-activity) volume), token-count: (get token-count current-activity), reputation-score: (get reputation-score current-activity)}
    )
    (ok true)
  )
)

;; @desc Register a token with the coordinator.
;; @param token: The principal of the token.
;; @param symbol: The symbol of the token.
;; @param decimals: The number of decimals for the token.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (register-token (token principal) (symbol (string-ascii 10)) (decimals uint))
  (let (
    (is-owner (is-contract-owner))
  )
    (asserts! is-owner ERR_UNAUTHORIZED)
    (try! (when-not-paused))
    (if (is-none (map-get? registered-tokens token))
      (var-set total-registered-tokens (+ (var-get total-registered-tokens) u1))
      true
    )
    (map-set registered-tokens token true)
    (map-set token-metadata token
      {symbol: symbol, decimals: decimals, total-supply: u0, is-active: true, last-activity: block-height}
    )
    (ok true)
  )
)

;; @desc Update the activity for a token.
;; @param token: The principal of the token.
;; @param supply: The new total supply of the token.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (update-token-activity (token principal) (supply uint))
  (begin
    (try! (when-not-paused))
    (try! (validate-token token))
    (map-set token-metadata token
      (merge
        (unwrap-panic (map-get? token-metadata token))
        {total-supply: supply, last-activity: block-height}
      )
    )
    (ok true)
  )
)

;; @desc Coordinate a multi-token operation.
;; @param user: The principal of the user.
;; @param tokens: A list of the tokens involved in the operation.
;; @param operation-type: The type of the operation.
;; @param total-value: The total value of the operation.
;; @returns (response uint uint): The ID of the new operation, or an error code.
(define-public (coordinate-multi-token-operation
    (user principal)
    (tokens (list 5 principal))
    (operation-type (string-ascii 32))
    (total-value uint)
  )
  (let (
    (new-op-id (+ (var-get last-operation-id) u1))
  )
    (try! (when-not-paused))
    (try! (when-not-emergency))
    
    ;; Validate all tokens are registered
    (asserts! (>= (len tokens) u1) ERR_INVALID_AMOUNT)
    (asserts! (<= (len tokens) MAX_TOKENS) ERR_INVALID_AMOUNT)
    
    ;; Record the operation
    (map-set cross-token-operations new-op-id
      {user: user, tokens: tokens, operation-type: operation-type, timestamp: block-height, total-value: total-value, status: "initiated"}
    )
    (var-set last-operation-id new-op-id)
    
    ;; Update user activity
    (try! (update-user-activity user total-value))
    
    ;; Trigger revenue distribution if applicable
    (if (is-eq operation-type "yield-claim")
      (try! (trigger-revenue-distribution (unwrap-panic (element-at tokens u0)) total-value))
      true
    )
    (ok new-op-id)
  )
)

;; @desc Trigger a revenue distribution.
;; @param token: The principal of the token.
;; @param amount: The amount of revenue to distribute.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (trigger-revenue-distribution (token principal) (amount uint))
  (begin
    (try! (when-not-paused))
    (try! (validate-token token))

    ;; Call revenue distributor
    (try! (contract-call? (var-get revenue-distributor) distribute-revenue token amount))

    ;; Update token activity
    (try! (update-token-activity token amount))
    (ok true)
  )
)

;; @desc Pause the system in an emergency.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (emergency-pause-system)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

;; @desc Resume the system after an emergency pause.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (emergency-resume-system)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

;; @desc Activate emergency mode.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (activate-emergency-mode)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set emergency-mode true)
    (ok true)
  )
)

;; @desc Deactivate emergency mode.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (deactivate-emergency-mode)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set emergency-mode false)
    (ok true)
  )
)

;; @desc Initialize the system with the core tokens.
;; @returns (response (string-ascii) uint): An `ok` response with a success message, or an error code.
(define-public (initialize-system)
  (let (
    (is-owner (is-contract-owner))
  )
    (asserts! is-owner ERR_UNAUTHORIZED)
    (try! (when-not-paused))
    
    ;; Register core tokens
    (try! (register-token CXD_TOKEN "CXD" u6))
    (try! (register-token CXVG_TOKEN "CXVG" u6))
    (try! (register-token CXLP_TOKEN "CXLP" u6))
    (try! (register-token CXTR_TOKEN "CXTR" u6))
    (try! (register-token CXS_TOKEN "CXS" u6))
    (ok "System initialized with 5 core tokens")
  )
)
