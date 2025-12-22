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
;; Updated to align with standard error codes and SDK test expectations
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_TOKEN u101)
(define-constant ERR_SYSTEM_PAUSED u104)
(define-constant ERR_INVALID_AMOUNT u103)
(define-constant ERR_COORDINATOR_ERROR u104)
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
;; Tracks an explicit admin separate from the deployer for compatibility with
;; higher-level security tests and access-control conventions
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var emergency-mode bool false)
;; Default revenue-distributor to the canonical system contract once deployed
(define-data-var revenue-distributor principal .revenue-distributor)
(define-data-var last-operation-id uint u0)
(define-data-var total-registered-tokens uint u0)
(define-data-var total-users uint u0)

;; --- Data Maps ---
(define-map registered-tokens
  principal
  bool
)

(define-map token-metadata
  principal
  {
    symbol: (string-ascii 10),
    decimals: uint,
    total-supply: uint,
    is-active: bool,
    last-activity: uint,
  }
)

(define-map user-activity
  principal
  {
    last-interaction: uint,
    total-volume: uint,
    token-count: uint,
    reputation-score: uint,
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
    status: (string-ascii 16),
  }
)

;; --- Read-Only Functions ---
;; All externally consumed views now use `(response ...)` semantics so that
;; SDK helpers can rely on `toBeOk` style assertions.
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-read-only (get-emergency-mode)
  (ok (var-get emergency-mode))
)

(define-read-only (get-registered-token (token principal))
  (ok (default-to false (map-get? registered-tokens token)))
)

(define-read-only (get-token-metadata (token principal))
  (ok (default-to {
    symbol: "",
    decimals: u0,
    total-supply: u0,
    is-active: false,
    last-activity: u0,
  }
    (map-get? token-metadata token)
  ))
)

(define-read-only (get-user-activity (user principal))
  (ok (default-to {
    last-interaction: u0,
    total-volume: u0,
    token-count: u0,
    reputation-score: u1000,
  }
    (map-get? user-activity user)
  ))
)

(define-read-only (get-system-health)
  (ok {
    is-paused: (var-get paused),
    emergency-mode: (var-get emergency-mode),
    total-registered-tokens: (var-get total-registered-tokens),
    total-users: (var-get total-users),
    coordinator-version: COORDINATOR_VERSION,
  })
)

;; --- Private Helper Functions ---
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; Treat the configured admin as an operator that can be rotated without
;; redeploying the coordinator contract.
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
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

(define-private (update-user-activity
    (user principal)
    (volume uint)
  )
  (let (
      (existing-activity (map-get? user-activity user))
      (current-activity (default-to {
        last-interaction: block-height,
        total-volume: u0,
        token-count: u0,
        reputation-score: u1000,
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
      ;; Track at least one token per active user for monitoring dashboards
      token-count: (if (is-none existing-activity)
        u1
        (get token-count current-activity)
      ),
      reputation-score: (get reputation-score current-activity),
    })
    true
  )
)

;; --- Public Functions ---
;; Configure admin operator; only contract-owner may rotate the admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (register-token
    (token principal)
    (symbol (string-ascii 10))
    (decimals uint)
  )
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
          last-activity: block-height,
        })
        (ok true)
      )
      (ok true)
    )
  )
)

(define-public (update-token-activity
    (token principal)
    (supply uint)
  )
  (begin
    (try! (when-not-paused))
    (try! (validate-token token))
    (map-set token-metadata token
      (merge (unwrap-panic (map-get? token-metadata token)) {
        total-supply: supply,
        last-activity: block-height,
      })
    )
    (ok true)
  )
)

(define-public (on-transfer
    (amount uint)
    (sender principal)
    (recipient principal)
  )
  (begin
    (try! (when-not-paused))
    (try! (validate-token contract-caller))
    (update-user-activity sender amount)
    (update-user-activity recipient amount)
    (ok true)
  )
)

(define-public (on-mint
    (amount uint)
    (recipient principal)
  )
  (begin
    (try! (when-not-paused))
    (try! (validate-token contract-caller))
    (update-user-activity recipient amount)
    (let ((meta (unwrap-panic (map-get? token-metadata contract-caller))))
      (map-set token-metadata contract-caller
        (merge meta {
          total-supply: (+ (get total-supply meta) amount),
          last-activity: block-height,
        })
      )
    )
    (ok true)
  )
)

(define-public (on-burn
    (amount uint)
    (sender principal)
  )
  (begin
    (try! (when-not-paused))
    (try! (validate-token contract-caller))
    (update-user-activity sender amount)
    (let ((meta (unwrap-panic (map-get? token-metadata contract-caller))))
      (map-set token-metadata contract-caller
        (merge meta {
          total-supply: (if (>= (get total-supply meta) amount)
            (- (get total-supply meta) amount)
            u0
          ),
          last-activity: block-height,
        })
      )
    )
    (ok true)
  )
)

(define-public (on-dimensional-yield
    (amount uint)
    (start-height uint)
    (end-height uint)
  )
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

    ;; Enforce non-empty token list and bounded size
    (asserts! (>= token-count u1) (err ERR_INVALID_AMOUNT))
    (asserts! (<= token-count MAX_TOKENS) (err ERR_INVALID_AMOUNT))
    ;; Operation type must be non-empty and value positive to be meaningful
    (asserts! (> (len operation-type) u0) (err ERR_INVALID_AMOUNT))
    (asserts! (> total-value u0) (err ERR_INVALID_AMOUNT))

    (map-set cross-token-operations new-op-id {
      user: user,
      tokens: tokens,
      operation-type: operation-type,
      timestamp: block-height,
      total-value: total-value,
      status: "initiated",
    })
    (var-set last-operation-id new-op-id)

    (update-user-activity user total-value)

    (if (is-eq operation-type "yield-claim")
      (try! (trigger-revenue-distribution (unwrap-panic (element-at tokens u0))
        total-value
      ))
      true
    )
    (ok new-op-id)
  )
)

(define-public (trigger-revenue-distribution
    (token principal)
    (amount uint)
  )
  (begin
    (try! (when-not-paused))
    (try! (validate-token token))
    (try! (contract-call? .revenue-distributor distribute-revenue token amount))
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

;; --- Genesis Distribution ---

(define-constant GENESIS_SUPPLY_CXD u100000000000000) ;; 100M CXD
(define-constant GENESIS_SUPPLY_CXVG u10000000000000) ;; 10M CXVG

;; Allocation Splits (BPS)
(define-constant ALLOC_FOUNDER u1500) ;; 15%
(define-constant ALLOC_TREASURY u3000) ;; 30%
(define-constant ALLOC_COMMUNITY u5500) ;; 55%

(define-data-var distribution-complete bool false)

(define-public (distribute-genesis-supply
    (founder-vesting principal)
    (treasury principal)
  )
  (let (
      (founder-amt-cxd (/ (* GENESIS_SUPPLY_CXD ALLOC_FOUNDER) u10000))
      (treasury-amt-cxd (/ (* GENESIS_SUPPLY_CXD ALLOC_TREASURY) u10000))
      (community-amt-cxd (/ (* GENESIS_SUPPLY_CXD ALLOC_COMMUNITY) u10000))
      (founder-amt-cxvg (/ (* GENESIS_SUPPLY_CXVG ALLOC_FOUNDER) u10000))
      (treasury-amt-cxvg (/ (* GENESIS_SUPPLY_CXVG ALLOC_TREASURY) u10000))
      ;; Community CXVG might be minted via liquidity mining, not pre-mine
    )
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get distribution-complete)) (err u105))
    ;; ERR_ALREADY_DISTRIBUTED

    ;; 1. Founder Allocation (Vested)
    (try! (contract-call? .cxd-token mint .founder-vesting founder-amt-cxd))
    (try! (contract-call? .founder-vesting add-vesting-allocation .cxd-token
      founder-amt-cxd
    ))

    (try! (contract-call? .cxvg-token mint founder-amt-cxvg .founder-vesting))
    (try! (contract-call? .founder-vesting add-vesting-allocation .cxvg-token
      founder-amt-cxvg
    ))

    ;; 2. Treasury Allocation
    (try! (contract-call? .cxd-token mint treasury treasury-amt-cxd))
    (try! (contract-call? .cxvg-token mint treasury-amt-cxvg treasury))

    ;; 3. Community/Liquidity (Held by coordinator or separate distributor)
    (try! (contract-call? .cxd-token mint tx-sender community-amt-cxd))

    (var-set distribution-complete true)
    (print {
      event: "genesis-distribution",
      founder-vesting: founder-vesting,
      treasury: treasury,
      cxd-founder: founder-amt-cxd,
      cxd-treasury: treasury-amt-cxd,
    })
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
