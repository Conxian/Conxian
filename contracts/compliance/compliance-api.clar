;; compliance-api.clar
;; Compliance API endpoints for enterprise integration
;; Provides REST-like interfaces for compliance operations

(use-trait compliance-trait .compliance.compliance-trait)

(define-constant ERR_UNAUTHORIZED (err u9500))
(define-constant ERR_INVALID_INPUT (err u9501))
(define-constant ERR_NOT_FOUND (err u9502))
(define-constant ERR_RATE_LIMITED (err u9503))

;; --- Constants ---
(define-constant API_RATE_LIMIT u100)  ;; requests per hour
(define-constant MAX_BATCH_SIZE u50)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var api-enabled bool true)
(define-data-var total-api-calls uint u0)

;; --- API Rate Limiting ---
(define-map api-usage {
  caller: principal,
} {
  calls-this-hour uint,
  last-call-block uint,
})

;; --- API Endpoints State ---
(define-map api-sessions {
  session-id: (string 64),
} {
  caller principal,
  created-at uint,
  last-access uint,
  requests-count uint,
})

;; --- Compliance Service References ---
(define-data-var sanctions-oracle principal tx-sender)
(define-data-var travel-rule-service principal tx-sender)
(define-data-var kyc-registry principal tx-sender)

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-api-enabled)
  (var-get api-enabled)
)

(define-private (check-rate-limit)
  (let ((current-height block-height)
        (usage (map-get? api-usage {caller: tx-sender}))
        (blocks-in-hour u720))  ;; 1 hour at 5s blocks
    (if (some? usage)
      (let ((last-call (get last-call-block (unwrap! usage false)))
            (calls-count (get calls-this-hour (unwrap! usage false))))
        (if (>= (- current-height last-call) blocks-in-hour)
          ;; Reset counter for new hour
          (begin
            (map-set api-usage {caller: tx-sender} {
              calls-this-hour: u1,
              last-call-block: current-height,
            })
            true
          )
          ;; Check if within rate limit
          (if (< calls-count API_RATE_LIMIT)
            (begin
              (map-set api-usage {caller: tx-sender} {
                calls-this-hour: (+ calls-count u1),
                last-call-block: current-height,
              })
              true
            )
            false
          )
        )
      )
      ;; First call from this address
      (begin
        (map-set api-usage {caller: tx-sender} {
          calls-this-hour: u1,
          last-call-block: current-height,
        })
        true
      )
    )
  )
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-api-enabled (enabled bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set api-enabled enabled)
    (print {
      event: "api-status-changed",
      enabled: enabled,
      changed-at: block-height,
    })
    (ok true)
  )
)

(define-public (set-compliance-services
    (sanctions-oracle principal)
    (travel-rule-service principal)
    (kyc-registry principal)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set sanctions-oracle sanctions-oracle)
    (var-set travel-rule-service travel-rule-service)
    (var-set kyc-registry kyc-registry)
    (ok true)
  )
)

;; --- API Session Management ---

;; @notice Create an API session for enterprise clients
(define-public (create-api-session (client-id (string 64)))
  (begin
    (asserts! (is-api-enabled) ERR_UNAUTHORIZED)
    (asserts! (check-rate-limit) ERR_RATE_LIMITED)
    
    (let ((session-id (as-max-len? (concat "session-" (tx-sender)) u64)))
      (map-set api-sessions {session-id: session-id} {
        caller: tx-sender,
        created-at: block-height,
        last-access: block-height,
        requests-count: u0,
      })
      
      (print {
        event: "api-session-created",
        session-id: session-id,
        client: tx-sender,
        created-at: block-height,
      })
      (ok session-id)
    )
  )
)

;; --- Compliance API Endpoints ---

;; @notice API endpoint: Check if address is sanctioned
(define-public (api-check-sanctions (address principal))
  (begin
    (asserts! (is-api-enabled) ERR_UNAUTHORIZED)
    (asserts! (check-rate-limit) ERR_RATE_LIMITED)
    
    (var-set total-api-calls (+ (var-get total-api-calls) u1))
    
    (let ((oracle (var-get sanctions-oracle)))
      (match (contract-call? oracle is-sanctioned address)
        is-sanctioned (ok {
          address: address,
          is-sanctioned: is-sanctioned,
          checked-at: block-height,
          api-call-id: (var-get total-api-calls),
        })
        error (err error)
      )
    )
  )
)

;; @notice API endpoint: Get KYC verification level
(define-public (api-get-kyc-level (user principal))
  (begin
    (asserts! (is-api-enabled) ERR_UNAUTHORIZED)
    (asserts! (check-rate-limit) ERR_RATE_LIMITED)
    
    (var-set total-api-calls (+ (var-get total-api-calls) u1))
    
    (let ((kyc-contract (var-get kyc-registry)))
      (match (contract-call? kyc-contract get-verification-level user)
        level (ok {
          user: user,
          verification-level: level,
          checked-at: block-height,
          api-call-id: (var-get total-api-calls),
        })
        error (err error)
      )
    )
  )
)

;; @notice API endpoint: Initiate Travel Rule transfer
(define-public (api-initiate-travel-rule
    (transfer-id (string 64))
    (to-vasp principal)
    (to-address principal)
    (amount uint)
    (token principal)
    (originator-info (string 512))
    (beneficiary-info (string 512))
  )
  (begin
    (asserts! (is-api-enabled) ERR_UNAUTHORIZED)
    (asserts! (check-rate-limit) ERR_RATE_LIMITED)
    
    (var-set total-api-calls (+ (var-get total-api-calls) u1))
    
    (let ((travel-service (var-get travel-rule-service)))
      (match (contract-call? travel-service initiate-travel-rule-transfer
              transfer-id to-vasp to-address amount token originator-info beneficiary-info)
        success (ok {
          transfer-id: transfer-id,
          status: "initiated",
          initiated-at: block-height,
          api-call-id: (var-get total-api-calls),
        })
        error (err error)
      )
    )
  )
)

;; @notice API endpoint: Batch compliance check
(define-public (api-batch-compliance-check (addresses (list 50 principal)))
  (begin
    (asserts! (is-api-enabled) ERR_UNAUTHORIZED)
    (asserts! (check-rate-limit) ERR_RATE_LIMITED)
    (asserts! (<= (len addresses) MAX_BATCH_SIZE) ERR_INVALID_INPUT)
    
    (var-set total-api-calls (+ (var-get total-api-calls) u1))
    
    (let ((oracle (var-get sanctions-oracle))
          (results (list)))
      ;; Process batch and collect results
      (ok {
        addresses: addresses,
        results: results,  // Would populate with actual results
        checked-at: block-height,
        api-call-id: (var-get total-api-calls),
      })
    )
  )
)

;; --- Read-Only Views ---

(define-read-only (get-api-stats)
  (ok {
    total-calls: (var-get total-api-calls),
    enabled: (var-get api-enabled),
    active-sessions: u0,  // Would calculate from sessions
  })
)

(define-read-only (get-session-info (session-id (string 64)))
  (map-get? api-sessions {session-id: session-id})
)

(define-read-only (get-rate-limit-status (caller principal))
  (let ((usage (map-get? api-usage {caller: caller})))
    (if (some? usage)
      (ok {
        calls-this-hour: (get calls-this-hour (unwrap! usage false)),
        last-call: (get last-call-block (unwrap! usage false)),
        remaining: (- API_RATE_LIMIT (get calls-this-hour (unwrap! usage false))),
      })
      (ok {
        calls-this-hour: u0,
        last-call: u0,
        remaining: API_RATE_LIMIT,
      })
    )
  )
)

(define-read-only (get-compliance-services)
  (ok {
    sanctions-oracle: (var-get sanctions-oracle),
    travel-rule-service: (var-get travel-rule-service),
    kyc-registry: (var-get kyc-registry),
  })
)
