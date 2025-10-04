;; rate-limiter.clar
;; Global rate limiting system for DDoS prevention and fair resource allocation
;; Implements sliding window, token bucket, and per-user rate limiting

(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u3001))
(define-constant ERR_RATE_LIMIT_EXCEEDED (err u3002))
(define-constant ERR_INVALID_LIMIT (err u3003))
(define-constant ERR_INVALID_WINDOW (err u3004))

;; Default rate limits
(define-constant DEFAULT_GLOBAL_LIMIT_PER_BLOCK u100)
(define-constant DEFAULT_USER_LIMIT_PER_WINDOW u10)
(define-constant DEFAULT_WINDOW_SIZE u10) ;; blocks
(define-constant DEFAULT_BURST_LIMIT u20)

;; Rate limit tiers for different user types
(define-constant TIER_BASIC u1)
(define-constant TIER_PREMIUM u2)
(define-constant TIER_ENTERPRISE u3)

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var rate-limiting-enabled bool true)
(define-data-var global-request-count uint u0)
(define-data-var current-block-count uint u0)

;; ===== Rate Limit Configuration =====

;; Per-operation rate limits
(define-map operation-limits (string-ascii 64) {
  requests-per-window: uint,
  window-size: uint,
  burst-limit: uint,
  enabled: bool
})

;; User tier configuration
(define-map user-tiers principal {
  tier: uint,
  custom-limit: (optional uint),
  whitelisted: bool
})

;; Rate limit tracking per user per operation
(define-map user-rate-limits {user: principal, operation: (string-ascii 64)} {
  requests-in-window: uint,
  window-start: uint,
  total-requests: uint,
  last-request: uint,
  blocked-count: uint
})

;; Global operation tracking
(define-map operation-stats (string-ascii 64) {
  total-requests: uint,
  total-blocked: uint,
  last-reset: uint
})

;; Token bucket per user (for burst handling)
(define-map token-buckets principal {
  tokens: uint,
  last-refill: uint,
  capacity: uint,
  refill-rate: uint
})

;; IP-based rate limiting (via principal mapping)
(define-map ip-rate-limits (buff 16) {
  requests-in-window: uint,
  window-start: uint,
  blocked-until: uint
})

;; ===== Authorization =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

;; ===== Admin Functions =====
(define-public (set-rate-limiting-enabled (enabled bool))
  (begin
    (try! (check-is-owner))
    (var-set rate-limiting-enabled enabled)
    (ok true)))

(define-public (configure-operation-limit
  (operation (string-ascii 64))
  (requests-per-window uint)
  (window-size uint)
  (burst-limit uint))
  (begin
    (try! (check-is-owner))
    (asserts! (> requests-per-window u0) ERR_INVALID_LIMIT)
    (asserts! (> window-size u0) ERR_INVALID_WINDOW)
    
    (map-set operation-limits operation {
      requests-per-window: requests-per-window,
      window-size: window-size,
      burst-limit: burst-limit,
      enabled: true
    })
    (ok true)))

(define-public (set-user-tier (user principal) (tier uint) (custom-limit (optional uint)))
  (begin
    (try! (check-is-owner))
    (map-set user-tiers user {
      tier: tier,
      custom-limit: custom-limit,
      whitelisted: false
    })
    (ok true)))

(define-public (whitelist-user (user principal))
  (begin
    (try! (check-is-owner))
    (match (map-get? user-tiers user)
      tier-info
      (map-set user-tiers user (merge tier-info {whitelisted: true}))
      (map-set user-tiers user {
        tier: TIER_PREMIUM,
        custom-limit: none,
        whitelisted: true
      }))
    (ok true)))

(define-public (remove-whitelist (user principal))
  (begin
    (try! (check-is-owner))
    (match (map-get? user-tiers user)
      tier-info
      (begin
        (map-set user-tiers user (merge tier-info {whitelisted: false}))
        (ok true))
      ERR_UNAUTHORIZED)))

;; ===== Rate Limiting Logic =====

;; Main rate limit check function
(define-public (check-rate-limit (operation (string-ascii 64)))
  (begin
    ;; Skip if rate limiting disabled
    (if (not (var-get rate-limiting-enabled))
        (ok true)
        (let ((user-tier (get-user-tier-info tx-sender))
              (op-limits (get-operation-limits operation)))
          
          ;; Allow whitelisted users
          (if (get whitelisted user-tier)
              (ok true)
              (begin
                ;; Check token bucket
                (try! (check-token-bucket tx-sender))
                
                ;; Check sliding window
                (try! (check-sliding-window tx-sender operation op-limits))
                
                ;; Record successful request
                (record-request tx-sender operation)
                (ok true)))))))

;; Token bucket algorithm for burst control
(define-private (check-token-bucket (user principal))
  (let ((bucket (get-or-init-bucket user)))
    (let ((refilled-bucket (refill-bucket bucket)))
      
      ;; Check if tokens available
      (if (>= (get tokens refilled-bucket) u1)
          (begin
            ;; Consume one token
            (map-set token-buckets user (merge refilled-bucket {
              tokens: (- (get tokens refilled-bucket) u1)
            }))
            (ok true))
          ERR_RATE_LIMIT_EXCEEDED))))

;; Sliding window rate limiting
(define-private (check-sliding-window 
  (user principal)
  (operation (string-ascii 64))
  (limits {requests-per-window: uint, window-size: uint, burst-limit: uint, enabled: bool}))
  
  (if (not (get enabled limits))
      (ok true)
      (let ((current-window (get-user-rate-limit user operation)))
        
        ;; Check if window expired
        (if (>= (- block-height (get window-start current-window)) (get window-size limits))
            ;; New window - reset
            (begin
              (map-set user-rate-limits {user: user, operation: operation} {
                requests-in-window: u1,
                window-start: block-height,
                total-requests: (+ (get total-requests current-window) u1),
                last-request: block-height,
                blocked-count: (get blocked-count current-window)
              })
              (ok true))
            
            ;; Within window - check limit
            (if (< (get requests-in-window current-window) (get requests-per-window limits))
                (begin
                  (map-set user-rate-limits {user: user, operation: operation} (merge current-window {
                    requests-in-window: (+ (get requests-in-window current-window) u1),
                    total-requests: (+ (get total-requests current-window) u1),
                    last-request: block-height
                  }))
                  (ok true))
                (begin
                  ;; Rate limit exceeded
                  (map-set user-rate-limits {user: user, operation: operation} (merge current-window {
                    blocked-count: (+ (get blocked-count current-window) u1)
                  }))
                  (update-operation-stats operation false)
                  ERR_RATE_LIMIT_EXCEEDED))))))

;; ===== Helper Functions =====

(define-private (get-user-tier-info (user principal))
  (default-to {tier: TIER_BASIC, custom-limit: none, whitelisted: false}
              (map-get? user-tiers user)))

(define-private (get-operation-limits (operation (string-ascii 64)))
  (default-to {
    requests-per-window: DEFAULT_USER_LIMIT_PER_WINDOW,
    window-size: DEFAULT_WINDOW_SIZE,
    burst-limit: DEFAULT_BURST_LIMIT,
    enabled: true
  } (map-get? operation-limits operation)))

(define-private (get-user-rate-limit (user principal) (operation (string-ascii 64)))
  (default-to {
    requests-in-window: u0,
    window-start: block-height,
    total-requests: u0,
    last-request: u0,
    blocked-count: u0
  } (map-get? user-rate-limits {user: user, operation: operation})))

(define-private (get-or-init-bucket (user principal))
  (default-to {
    tokens: DEFAULT_BURST_LIMIT,
    last-refill: block-height,
    capacity: DEFAULT_BURST_LIMIT,
    refill-rate: u2 ;; 2 tokens per block
  } (map-get? token-buckets user)))

(define-private (refill-bucket (bucket {tokens: uint, last-refill: uint, capacity: uint, refill-rate: uint}))
  (let ((blocks-elapsed (- block-height (get last-refill bucket)))
        (tokens-to-add (* blocks-elapsed (get refill-rate bucket)))
        (new-tokens (min (+ (get tokens bucket) tokens-to-add) (get capacity bucket))))
    {
      tokens: new-tokens,
      last-refill: block-height,
      capacity: (get capacity bucket),
      refill-rate: (get refill-rate bucket)
    }))

(define-private (min (a uint) (b uint))
  (if (< a b) a b))

(define-private (record-request (user principal) (operation (string-ascii 64)))
  (begin
    (var-set global-request-count (+ (var-get global-request-count) u1))
    (update-operation-stats operation true)
    true))

(define-private (update-operation-stats (operation (string-ascii 64)) (success bool))
  (match (map-get? operation-stats operation)
    stats
    (map-set operation-stats operation {
      total-requests: (+ (get total-requests stats) u1),
      total-blocked: (if success (get total-blocked stats) (+ (get total-blocked stats) u1)),
      last-reset: (get last-reset stats)
    })
    (map-set operation-stats operation {
      total-requests: u1,
      total-blocked: (if success u0 u1),
      last-reset: block-height
    })))

;; ===== Read-Only Functions =====

(define-read-only (get-user-limit-status (user principal) (operation (string-ascii 64)))
  (let ((limits (get-operation-limits operation))
        (current (get-user-rate-limit user operation)))
    {
      requests-used: (get requests-in-window current),
      requests-allowed: (get requests-per-window limits),
      requests-remaining: (if (> (get requests-per-window limits) (get requests-in-window current))
                              (- (get requests-per-window limits) (get requests-in-window current))
                              u0),
      window-expires-in: (if (> (+ (get window-start current) (get window-size limits)) block-height)
                             (- (+ (get window-start current) (get window-size limits)) block-height)
                             u0),
      total-blocked: (get blocked-count current)
    }))

(define-read-only (get-token-bucket-status (user principal))
  (let ((bucket (get-or-init-bucket user)))
    (let ((refilled (refill-bucket bucket)))
      {
        available-tokens: (get tokens refilled),
        capacity: (get capacity refilled),
        refill-rate: (get refill-rate refilled),
        next-refill: u1
      })))

(define-read-only (get-operation-stats (operation (string-ascii 64)))
  (map-get? operation-stats operation))

(define-read-only (get-global-stats)
  {
    total-requests: (var-get global-request-count),
    rate-limiting-enabled: (var-get rate-limiting-enabled),
    current-block: block-height
  })

(define-read-only (is-rate-limited (user principal) (operation (string-ascii 64)))
  (let ((limits (get-operation-limits operation))
        (current (get-user-rate-limit user operation))
        (user-tier (get-user-tier-info user)))
    
    (if (get whitelisted user-tier)
        false
        (and (get enabled limits)
             (< (- block-height (get window-start current)) (get window-size limits))
             (>= (get requests-in-window current) (get requests-per-window limits))))))

(define-read-only (get-user-tier (user principal))
  (map-get? user-tiers user))

(define-read-only (estimate-wait-time (user principal) (operation (string-ascii 64)))
  (let ((limits (get-operation-limits operation))
        (current (get-user-rate-limit user operation)))
    (if (is-rate-limited user operation)
        (- (+ (get window-start current) (get window-size limits)) block-height)
        u0)))
