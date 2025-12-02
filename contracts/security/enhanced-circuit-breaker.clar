;; ===========================================
;; Enhanced Circuit Breaker Contract
;; ===========================================
;; Version: 1.0.0
;; 
;; This contract provides advanced circuit breaker functionality with:
;; - Automated triggers based on configurable conditions
;; - Comprehensive event logging
;; - Sophisticated recovery mechanisms
;; - Integration with regulatory systems

;; Use centralized traits
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait oracle-trait .oracle-pricing.oracle-trait)
(use-trait compliance-trait .compliance-trait.compliance-trait)

;; ===========================================
;; CONSTANTS
;; ===========================================

;; Error codes (1000-1999)
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_ALREADY_PAUSED (err u2002))
(define-constant ERR_NOT_PAUSED (err u2003))
(define-constant ERR_INVALID_DURATION (err u2004))
(define-constant ERR_CIRCUIT_ALREADY_EXISTS (err u2005))
(define-constant ERR_CIRCUIT_NOT_FOUND (err u2006))
(define-constant ERR_EMERGENCY_ACTIVE (err u2007))
(define-constant ERR_INVALID_TRIGGER (err u2008))
(define-constant ERR_TRIGGER_ALREADY_EXISTS (err u2009))
(define-constant ERR_TRIGGER_NOT_FOUND (err u2010))

;; Circuit breaker types
(define-constant CB_TYPE_PRICE_VOLATILITY u1)
(define-constant CB_TYPE_VOLUME_SPIKE u2)
(define-constant CB_TYPE_LIQUIDITY_DRAIN u3)
(define-constant CB_TYPE_GOVERNANCE u4)
(define-constant CB_TYPE_EMERGENCY u5)
(define-constant CB_TYPE_COMPLIANCE u6)

;; Trigger types
(define-constant TRIGGER_TYPE_PRICE_DELTA u1)
(define-constant TRIGGER_TYPE_VOLUME_DELTA u2)
(define-constant TRIGGER_TYPE_ABSOLUTE_PRICE u3)
(define-constant TRIGGER_TYPE_TIME_BASED u4)
(define-constant TRIGGER_TYPE_GOVERNANCE_VOTE u5)
(define-constant TRIGGER_TYPE_COMPLIANCE_ALERT u6)

;; ===========================================
;; DATA STRUCTURES
;; ===========================================

;; Circuit breaker configuration
(define-data-var next-circuit-id uint u1)
(define-data-var next-event-id uint u0)

(define-map circuit-breakers
  { circuit-id: uint }
  {
    circuit-type: uint,
    name: (string-ascii 32),
    description: (string-ascii 256),
    is-active: bool,
    created-at: uint,
    created-by: principal,
    max-pause-duration: uint,
    cooldown-period: uint,
    auto-recovery: bool,
    min-recovery-time: uint,
    requires-governance-approval: bool
  })

;; Circuit breaker state
(define-map circuit-states
  { circuit-id: uint }
  {
    is-tripped: bool,
    last-tripped: uint,
    last-reset: uint,
    trip-count: uint,
    last-trigger-id: uint,
    current-cooldown: uint
  })

;; Trigger configurations
(define-map triggers
  { circuit-id: uint, trigger-id: uint }
  {
    trigger-type: uint,
    is-active: bool,
    threshold: uint,
    window-size: uint,
    comparison: uint,  ;; 1: >, 2: <, 3: =, 4: !=, 5: >=, 6: <=
    cooldown: uint,
    last-triggered: uint,
    trigger-count: uint,
    metadata: (optional (string-utf8 1024))
  })

;; Event logging
(define-map events
  { event-id: uint }
  {
    event-type: (string-ascii 32),
    circuit-id: uint,
    trigger-id: (optional uint),
    severity: uint,  ;; 1: Info, 2: Warning, 3: Critical
    message: (string-utf8 1024),
    metadata: (optional (string-utf8 4096)),
    timestamp: uint,
    block-height: uint,
    tx-sender: principal
  })

;; Recovery actions
(define-map recovery-actions
  { circuit-id: uint, action-id: uint }
  {
    action-type: uint,  ;; 1: Auto-recover, 2: Governance vote, 3: Time delay
    is-completed: bool,
    created-at: uint,
    completed-at: (optional uint),
    required-approvals: uint,
    current-approvals: uint,
    approvers: (list 100 principal)
  })

;; ===========================================
;; PRIVATE FUNCTIONS
;; ===========================================

;; Check if caller has permission to manage circuit breakers
(define-private (can-manage-circuit (caller principal))
  (or
    (contract-call? .core-traits.rbac-trait is-owner caller)
    (contract-call? .core-traits.rbac-trait has-role caller "circuit-admin")
  )
)

;; Log an event
(define-private (log-event 
    (event-type (string-ascii 32))
    (circuit-id uint)
    (severity uint)
    (message (string-utf8 1024))
    (metadata (optional (string-utf8 4096)))
    (trigger-id (optional uint))
)
  (let ((event-id (+ (var-get next-event-id) u1)))
    (map-set events {event-id: event-id} {
      event-type: event-type,
      circuit-id: circuit-id,
      trigger-id: trigger-id,
      severity: severity,
      message: message,
      metadata: metadata,
      timestamp: block-height,
      block-height: block-height,
      tx-sender: tx-sender
    })
    (var-set next-event-id event-id)
    (ok event-id)
  )
)

;; Check if a circuit can be tripped (respects cooldown)
(define-private (can-trip-circuit (circuit-id uint))
  (match (map-get? circuit-states {circuit-id: circuit-id})
    state 
    (let ((cooldown (get current-cooldown state)))
      (if (get is-tripped state)
        (err ERR_ALREADY_PAUSED)
        (if (and (> cooldown u0) (< (- block-height (get last-reset state)) cooldown))
          (err ERR_INVALID_DURATION)
          (ok true)
        )
      )
    )
    (ok true)  ;; No state yet, can trip
  )
)

;; ===========================================
;; PUBLIC FUNCTIONS - CIRCUIT MANAGEMENT
;; ===========================================

;; Create a new circuit breaker
(define-public (create-circuit 
    (name (string-ascii 32))
    (description (string-ascii 256))
    (circuit-type uint)
    (max-pause-duration uint)
    (cooldown-period uint)
    (auto-recovery bool)
    (min-recovery-time uint)
    (requires-gov-approval bool)
)
  (begin
    (asserts! (can-manage-circuit tx-sender) ERR_UNAUTHORIZED)
    
    (let ((circuit-id (var-get next-circuit-id)))
      (map-set circuit-breakers {circuit-id: circuit-id} {
        name: name,
        description: description,
        circuit-type: circuit-type,
        is-active: true,
        created-at: block-height,
        created-by: tx-sender,
        max-pause-duration: max-pause-duration,
        cooldown-period: cooldown-period,
        auto-recovery: auto-recovery,
        min-recovery-time: min-recovery-time,
        requires-governance-approval: requires-gov-approval
      })
      
      ;; Initialize state
      (map-set circuit-states {circuit-id: circuit-id} {
        is-tripped: false,
        last-tripped: u0,
        last-reset: block-height,
        trip-count: u0,
        last-trigger-id: u0,
        current-cooldown: cooldown-period
      })
      
      (var-set next-circuit-id (+ circuit-id u1))
      
      (log-event 
        "CIRCUIT_CREATED" 
        circuit-id 
        u1 
        (unwrap-panic (string-utf8-append "Circuit " name " created"))
        none
        none
      )
      
      (ok circuit-id)
    )
  )
)

;; Add a trigger to a circuit
(define-public (add-trigger
    (circuit-id uint)
    (trigger-type uint)
    (threshold uint)
    (window-size uint)
    (comparison uint)
    (cooldown uint)
    (metadata (optional (string-utf8 1024)))
)
  (begin
    (asserts! (can-manage-circuit tx-sender) ERR_UNAUTHORIZED)
    (asserts! (map-get? circuit-breakers {circuit-id: circuit-id}) ERR_CIRCUIT_NOT_FOUND)
    
    (let ((trigger-id (+ (get last-trigger-id (unwrap-panic (map-get? circuit-states {circuit-id: circuit-id}))) u1)))
      (map-set triggers {circuit-id: circuit-id, trigger-id: trigger-id} {
        trigger-type: trigger-type,
        is-active: true,
        threshold: threshold,
        window-size: window-size,
        comparison: comparison,
        cooldown: cooldown,
        last-triggered: u0,
        trigger-count: u0,
        metadata: metadata
      })
      
      ;; Update last trigger ID in circuit state
      (map-set circuit-states {circuit-id: circuit-id} 
        (merge (unwrap-panic (map-get? circuit-states {circuit-id: circuit-id})) 
          {last-trigger-id: trigger-id}))
      
      (log-event 
        "TRIGGER_ADDED" 
        circuit-id 
        u1 
        (unwrap-panic (string-utf8-append "Trigger " (unwrap-panic (to-utf8 (some trigger-id))) " added"))
        metadata
        (some trigger-id)
      )
      
      (ok trigger-id)
    )
  )
)

;; Trip a circuit breaker
(define-public (trip-circuit 
    (circuit-id uint)
    (reason (string-utf8 1024))
    (trigger-id (optional uint))
)
  (begin
    (asserts! (can-manage-circuit tx-sender) ERR_UNAUTHORIZED)
    (asserts! (map-get? circuit-breakers {circuit-id: circuit-id}) ERR_CIRCUIT_NOT_FOUND)
    (try! (can-trip-circuit circuit-id))
    
    (let* (
        (circuit (unwrap-panic (map-get? circuit-breakers {circuit-id: circuit-id})))
        (state (unwrap-panic (map-get? circuit-states {circuit-id: circuit-id})))
        (cooldown (get cooldown-period circuit))
      )
      
      ;; Update circuit state
      (map-set circuit-states {circuit-id: circuit-id} {
        is-tripped: true,
        last-tripped: block-height,
        last-reset: (get last-reset state),
        trip-count: (+ (get trip-count state) u1),
        last-trigger-id: (get last-trigger-id state),
        current-cooldown: cooldown
      })
      
      ;; Log the trip event
      (log-event 
        (if (is-none trigger-id) "CIRCUIT_TRIPPED_MANUAL" "CIRCUIT_TRIPPED_AUTO")
        circuit-id 
        (if (is-none trigger-id) u2 u3)  ;; Manual trips are warnings, auto trips are critical
        reason
        none
        trigger-id
      )
      
      ;; If auto-recovery is enabled, schedule recovery
      (if (and (get auto-recovery circuit) (is-some trigger-id))
        (begin
          (map-set recovery-actions 
            {circuit-id: circuit-id, action-id: (unwrap-panic trigger-id)} 
            {
              action-type: u1,  ;; Auto-recover
              is-completed: false,
              created-at: block-height,
              completed-at: none,
              required-approvals: u1,
              current-approvals: u1,
              approvers: (list tx-sender)
            }
          )
          (ok (list circuit-id (unwrap-panic trigger-id)))
        )
        (ok (list circuit-id u0))
      )
    )
  )
)

;; Reset a tripped circuit breaker
(define-public (reset-circuit (circuit-id uint) (reason (string-utf8 1024)))
  (begin
    (asserts! (can-manage-circuit tx-sender) ERR_UNAUTHORIZED)
    (asserts! (map-get? circuit-breakers {circuit-id: circuit-id}) ERR_CIRCUIT_NOT_FOUND)
    
    (let* (
        (circuit (unwrap-panic (map-get? circuit-breakers {circuit-id: circuit-id})))
        (state (unwrap-panic (map-get? circuit-states {circuit-id: circuit-id})))
      )
      
      (asserts! (get is-tripped state) ERR_NOT_PAUSED)
      
      ;; Check if minimum recovery time has passed
      (asserts! 
        (>= (- block-height (get last-tripped state)) (get min-recovery-time circuit))
        ERR_INVALID_DURATION
      )
      
      ;; If governance approval is required, check if it's been granted
      (if (and 
            (get requires-governance-approval circuit)
            (not (contract-call? .core-traits.rbac-trait has-role tx-sender "governance")))
        (err ERR_UNAUTHORIZED)
        (begin
          ;; Update circuit state
          (map-set circuit-states {circuit-id: circuit-id} {
            is-tripped: false,
            last-tripped: (get last-tripped state),
            last-reset: block-height,
            trip-count: (get trip-count state),
            last-trigger-id: (get last-trigger-id state),
            current-cooldown: (get cooldown-period circuit)
          })
          
          ;; Log the reset event
          (log-event 
            "CIRCUIT_RESET" 
            circuit-id 
            u1  
            reason
            none
            none
          )
          
          (ok true)
        )
      )
    )
  )
)

;; ===========================================
;; AUTOMATED TRIGGERS
;; ===========================================

;; Check all active triggers for a circuit
(define-public (check-triggers (circuit-id uint))
  (begin
    (asserts! (map-get? circuit-breakers {circuit-id: circuit-id}) ERR_CIRCUIT_NOT_FOUND)
    
    (let* (
        (circuit (unwrap-panic (map-get? circuit-breakers {circuit-id: circuit-id})))
        (state (unwrap-panic (map-get? circuit-states {circuit-id: circuit-id})))
        (triggers (filter 
          (lambda ((trigger {circuit-id: uint, trigger-id: uint})) 
            (get is-active (unwrap-panic (map-get? triggers trigger))))
          (map 
            (lambda ((trigger-id uint)) {circuit-id: circuit-id, trigger-id: trigger-id})
            (range u1 (get last-trigger-id state))
          )
        ))
      )
      
      ;; Check each trigger
      (fold 
        (lambda ((trigger {circuit-id: uint, trigger-id: uint}) (result (response (list 10 uint) uint)))
          (let* (
              (trigger-data (unwrap-panic (map-get? triggers trigger)))
              (should-trip (try! (check-single-trigger circuit-id (get trigger-id trigger) trigger-data)))
            )
            (if should-trip
              (ok (append (unwrap-panic result) (list (get trigger-id trigger))))
              (ok (unwrap-panic result))
            )
          )
        )
        (ok (list))
        triggers
      )
    )
  )
)

;; Check a single trigger condition
(define-private (check-single-trigger 
    (circuit-id uint)
    (trigger-id uint)
    (trigger {
      trigger-type: uint,
      is-active: bool,
      threshold: uint,
      window-size: uint,
      comparison: uint,
      cooldown: uint,
      last-triggered: uint,
      trigger-count: uint,
      metadata: (optional (string-utf8 1024))
    })
  )
  (let* (
      (current-time block-height)
      (time-since-last (- current-time (get last-triggered trigger)))
    )
    
    ;; Skip if on cooldown
    (if (and (> (get last-triggered trigger) u0) (< time-since-last (get cooldown trigger)))
      (ok false)
      (match (get trigger-type trigger)
        TRIGGER_TYPE_PRICE_DELTA (check-price-delta-trigger circuit-id trigger-id trigger)
        TRIGGER_TYPE_VOLUME_DELTA (check-volume-delta-trigger circuit-id trigger-id trigger)
        TRIGGER_TYPE_ABSOLUTE_PRICE (check-absolute-price-trigger circuit-id trigger-id trigger)
        TRIGGER_TYPE_TIME_BASED (check-time-based-trigger circuit-id trigger-id trigger)
        TRIGGER_TYPE_GOVERNANCE_VOTE (check-governance-vote-trigger circuit-id trigger-id trigger)
        TRIGGER_TYPE_COMPLIANCE_ALERT (check-compliance-alert-trigger circuit-id trigger-id trigger)
        (err ERR_INVALID_TRIGGER)
      )
    )
  )
)

;; ===========================================
;; TRIGGER IMPLEMENTATIONS
;; ===========================================

(define-private (check-price-delta-trigger
    (circuit-id uint)
    (trigger-id uint)
    (trigger {
      trigger-type: uint,
      is-active: bool,
      threshold: uint,
      window-size: uint,
      comparison: uint,
      cooldown: uint,
      last-triggered: uint,
      trigger-count: uint,
      metadata: (optional (string-utf8 1024))
    })
  )
  (let* (
      (metadata (unwrap-panic (get metadata trigger)))
      (asset (unwrap! (parse-metadata metadata) (err ERR_INVALID_TRIGGER)))
      (current-price (unwrap! (contract-call? .oracle get-price asset) (err ERR_ORACLE_ERROR)))
      (historical-price (unwrap! (contract-call? .oracle get-historical-price asset (get window-size trigger)) (err ERR_ORACLE_ERROR)))
      (price-delta (abs (- current-price historical-price)))
      (price-delta-percent (/ (* price-delta u100) historical-price))
      (should-trip (compare-values price-delta-percent (get threshold trigger) (get comparison trigger)))
    )
    
    (if should-trip
      (begin
        ;; Update trigger state
        (map-set triggers {circuit-id: circuit-id, trigger-id: trigger-id} {
          trigger-type: (get trigger-type trigger),
          is-active: (get is-active trigger),
          threshold: (get threshold trigger),
          window-size: (get window-size trigger),
          comparison: (get comparison trigger),
          cooldown: (get cooldown trigger),
          last-triggered: block-height,
          trigger-count: (+ (get trigger-count trigger) u1),
          metadata: (get metadata trigger)
        })
        
        (log-event 
          "PRICE_DELTA_TRIGGER" 
          circuit-id 
          u3  ;; Critical
          (unwrap-panic (string-utf8-append 
            "Price delta trigger activated: " 
            (unwrap-panic (to-utf8 (some price-delta-percent)))
            "% over " 
            (unwrap-panic (to-utf8 (some (get window-size trigger))))
            " blocks"
          ))
          (get metadata trigger)
          (some trigger-id)
        )
        
        (ok true)
      )
      (ok false)
    )
  )
)

;; ===========================================
;; HELPER FUNCTIONS
;; ===========================================

;; Compare values based on comparison type
(define-private (compare-values (value uint) (threshold uint) (comparison uint))
  (match comparison
    1 (> value threshold)      ;; >
    2 (< value threshold)      ;; <
    3 (is-eq value threshold)  ;; ==
    4 (not (is-eq value threshold))  ;; !=
    5 (>= value threshold)     ;; >=
    6 (<= value threshold)     ;; <=
    false
  )
)

;; Parse metadata string
(define-private (parse-metadata (metadata (string-utf8 1024)))
  (match (parse-metadata-json metadata)
    parsed (ok parsed)
    (err "INVALID_METADATA")
  )
)

;; ===========================================
;; INITIALIZATION
;; ===========================================

;; Initialize with default values
(begin
  (var-set next-circuit-id u1)
  (var-set next-event-id u0)
  
  (log-event 
    "SYSTEM_INIT" 
    u0 
    u1 
    "Enhanced Circuit Breaker system initialized"
    none
    none
  )
)
