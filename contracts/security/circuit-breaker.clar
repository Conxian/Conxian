;; ===========================================
;; Circuit Breaker Contract
;; ===========================================

;; This contract provides emergency circuit breaker functionality for the Conxian Protocol,
;; allowing rapid response to critical issues while maintaining decentralized governance.

;; Use centralized traits
(use-trait rbac-trait .traits.rbac-trait.rbac-trait)

;; ===========================================
;; CONSTANTS
;; ===========================================

(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_ALREADY_PAUSED (err u2002))
(define-constant ERR_NOT_PAUSED (err u2003))
(define-constant ERR_INVALID_DURATION (err u2004))
(define-constant ERR_CIRCUIT_ALREADY_EXISTS (err u2005))
(define-constant ERR_CIRCUIT_NOT_FOUND (err u2006))
(define-constant ERR_EMERGENCY_ACTIVE (err u2007))

;; Circuit breaker types
(define-constant TYPE_TRADING u1)
(define-constant TYPE_LENDING u2)
(define-constant TYPE_ORACLE u3)
(define-constant TYPE_GOVERNANCE u4)
(define-constant TYPE_EMERGENCY u5)

;; ===========================================
;; DATA VARIABLES
;; ===========================================

;; Global emergency pause
(define-data-var global-emergency-pause bool false)

;; Emergency pause timestamp
(define-data-var emergency-pause-time uint u0)

;; Maximum pause duration (in blocks)
(define-data-var max-pause-duration uint u10080) ;; ~1 week

;; ===========================================
;; DATA MAPS
;; ===========================================

;; Circuit breaker states
(define-map circuit-breakers
  { circuit-type: uint }
  {
    paused: bool,
    paused-at: uint,
    pause-duration: uint,
    triggered-by: principal,
    reason: (string-ascii 256),
    governance-approval: bool
  }
)

;; Pause event log
(define-map pause-events
  { event-id: uint }
  {
    circuit-type: uint,
    action: (string-ascii 20), ;; "pause" or "resume"
    timestamp: uint,
    actor: principal,
    reason: (string-ascii 256)
  }
)

;; Emergency recovery proposals
(define-map recovery-proposals
  { proposal-id: uint }
  {
    circuit-type: uint,
    proposed-by: principal,
    proposed-at: uint,
    execution-time: uint,
    executed: bool,
    description: (string-ascii 256)
  }
)

;; ===========================================
;; PRIVATE FUNCTIONS
;; ===========================================

(define-private (is-authorized-breaker)
  (or
    (contract-call? .traits.rbac-trait.rbac-trait is-owner tx-sender)
    (contract-call? .traits.rbac-trait.rbac-trait has-role tx-sender "emergency-breaker")
  )
)

(define-private (is-governance-approved (circuit-type uint))
  (default-to false (get governance-approval (map-get? circuit-breakers { circuit-type: circuit-type })))
)

(define-private (log-pause-event (circuit-type uint) (action (string-ascii 20)) (reason (string-ascii 256)))
  (let ((event-id (+ u1 (var-get emergency-pause-time)))) ;; Simple counter
    (map-set pause-events
      { event-id: event-id }
      {
        circuit-type: circuit-type,
        action: action,
        timestamp: block-height,
        actor: tx-sender,
        reason: reason
      }
    )
    (var-set emergency-pause-time event-id)
    event-id
  )
)

(define-private (circuit-exists (circuit-type uint))
  (is-some (map-get? circuit-breakers { circuit-type: circuit-type }))
)

;; ===========================================
;; PUBLIC FUNCTIONS
;; ===========================================

;; @desc Initialize a circuit breaker for a specific system
;; @param circuit-type The type of circuit (trading, lending, etc.)
;; @param pause-duration Maximum pause duration in blocks
(define-public (initialize-circuit (circuit-type uint) (pause-duration uint))
  (begin
    (asserts! (is-authorized-breaker) ERR_UNAUTHORIZED)
    (asserts! (<= pause-duration (var-get max-pause-duration)) ERR_INVALID_DURATION)
    (asserts! (not (circuit-exists circuit-type)) ERR_CIRCUIT_ALREADY_EXISTS)

    (map-set circuit-breakers
      { circuit-type: circuit-type }
      {
        paused: false,
        paused-at: u0,
        pause-duration: pause-duration,
        triggered-by: tx-sender,
        reason: "",
        governance-approval: false
      }
    )

    (log-pause-event circuit-type "initialized" "circuit breaker initialized")
    (ok true)
  )
)

;; @desc Trigger circuit breaker pause (emergency stop)
;; @param circuit-type The circuit to pause
;; @param reason Reason for the pause
(define-public (pause-circuit (circuit-type uint) (reason (string-ascii 256)))
  (begin
    (asserts! (is-authorized-breaker) ERR_UNAUTHORIZED)
    (asserts! (circuit-exists circuit-type) ERR_CIRCUIT_NOT_FOUND)
    (asserts! (not (var-get global-emergency-pause)) ERR_EMERGENCY_ACTIVE)

    (let ((circuit (unwrap-panic (map-get? circuit-breakers { circuit-type: circuit-type }))))
      (asserts! (not (get paused circuit)) ERR_ALREADY_PAUSED)

      (map-set circuit-breakers
        { circuit-type: circuit-type }
        (merge circuit {
          paused: true,
          paused-at: block-height,
          triggered-by: tx-sender,
          reason: reason
        })
      )

      (log-pause-event circuit-type "pause" reason)
      (ok true)
    )
  )
)

;; @desc Resume circuit breaker (normal operation)
;; @param circuit-type The circuit to resume
(define-public (resume-circuit (circuit-type uint))
  (begin
    (asserts! (is-authorized-breaker) ERR_UNAUTHORIZED)
    (asserts! (circuit-exists circuit-type) ERR_CIRCUIT_NOT_FOUND)

    (let ((circuit (unwrap-panic (map-get? circuit-breakers { circuit-type: circuit-type }))))
      (asserts! (get paused circuit) ERR_NOT_PAUSED)

      ;; Check if pause duration has expired
      (let ((pause-duration (get pause-duration circuit))
            (paused-at (get paused-at circuit)))
        (asserts! (< (- block-height paused-at) pause-duration) ERR_INVALID_DURATION)

        (map-set circuit-breakers
          { circuit-type: circuit-type }
          (merge circuit { paused: false })
        )

        (log-pause-event circuit-type "resume" "circuit resumed")
        (ok true)
      )
    )
  )
)

;; @desc Global emergency pause (ultimate circuit breaker)
;; @param reason Reason for emergency pause
(define-public (global-emergency-pause (reason (string-ascii 256)))
  (begin
    (asserts! (is-authorized-breaker) ERR_UNAUTHORIZED)
    (asserts! (not (var-get global-emergency-pause)) ERR_ALREADY_PAUSED)

    (var-set global-emergency-pause true)
    (var-set emergency-pause-time block-height)

    (log-pause-event TYPE_EMERGENCY "global-pause" reason)
    (ok true)
  )
)

;; @desc Resume from global emergency pause
(define-public (resume-global-emergency)
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (var-get global-emergency-pause) ERR_NOT_PAUSED)

    (var-set global-emergency-pause false)

    (log-pause-event TYPE_EMERGENCY "global-resume" "emergency pause lifted")
    (ok true)
  )
)

;; @desc Propose circuit breaker recovery (governance)
;; @param circuit-type The circuit to recover
;; @param description Description of recovery plan
;; @param execution-delay Delay before execution (blocks)
(define-public (propose-recovery (circuit-type uint) (description (string-ascii 256)) (execution-delay uint))
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait has-role tx-sender "governance") ERR_UNAUTHORIZED)

    (let ((proposal-id (+ u1 (var-get max-pause-duration)))) ;; Simple counter
      (map-set recovery-proposals
        { proposal-id: proposal-id }
        {
          circuit-type: circuit-type,
          proposed-by: tx-sender,
          proposed-at: block-height,
          execution-time: (+ block-height execution-delay),
          executed: false,
          description: description
        }
      )

      (log-pause-event circuit-type "recovery-proposed" description)
      (ok proposal-id)
    )
  )
)

;; @desc Execute approved recovery proposal
;; @param proposal-id The recovery proposal to execute
(define-public (execute-recovery (proposal-id uint))
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait has-role tx-sender "governance") ERR_UNAUTHORIZED)

    (let ((proposal (unwrap! (map-get? recovery-proposals { proposal-id: proposal-id }) ERR_CIRCUIT_NOT_FOUND)))
      (asserts! (>= block-height (get execution-time proposal)) ERR_INVALID_DURATION)
      (asserts! (not (get executed proposal)) ERR_ALREADY_PAUSED)

      ;; Execute recovery by resuming the circuit
      (try! (resume-circuit (get circuit-type proposal)))

      ;; Mark proposal as executed
      (map-set recovery-proposals
        { proposal-id: proposal-id }
        (merge proposal { executed: true })
      )

      (log-pause-event (get circuit-type proposal) "recovery-executed" "governance-approved recovery")
      (ok true)
    )
  )
)

;; ===========================================
;; READ-ONLY FUNCTIONS
;; ===========================================

;; @desc Check if a circuit is currently paused
;; @param circuit-type The circuit to check
(define-read-only (is-circuit-paused (circuit-type uint))
  (or
    (var-get global-emergency-pause)
    (default-to false (get paused (map-get? circuit-breakers { circuit-type: circuit-type })))
  )
)

;; @desc Get circuit breaker details
;; @param circuit-type The circuit to query
(define-read-only (get-circuit-details (circuit-type uint))
  (map-get? circuit-breakers { circuit-type: circuit-type })
)

;; @desc Get global emergency status
(define-read-only (get-global-emergency-status)
  {
    active: (var-get global-emergency-pause),
    activated-at: (var-get emergency-pause-time)
  }
)

;; @desc Get pause event details
;; @param event-id The event ID to retrieve
(define-read-only (get-pause-event (event-id uint))
  (map-get? pause-events { event-id: event-id })
)

;; @desc Get recovery proposal details
;; @param proposal-id The proposal ID to retrieve
(define-read-only (get-recovery-proposal (proposal-id uint))
  (map-get? recovery-proposals { proposal-id: proposal-id })
)

;; @desc Check if recovery can be executed
;; @param proposal-id The proposal to check
(define-read-only (can-execute-recovery (proposal-id uint))
  (match (map-get? recovery-proposals { proposal-id: proposal-id })
    proposal (and
               (>= block-height (get execution-time proposal))
               (not (get executed proposal))
             )
    false
  )
)

;; ===========================================
;; CONTRACT INITIALIZATION
;; ===========================================

;; Initialize with default circuit breakers
(begin
  ;; Initialize core circuits
  (map-set circuit-breakers
    { circuit-type: TYPE_TRADING }
    {
      paused: false,
      paused-at: u0,
      pause-duration: u1440, ;; ~1 day
      triggered-by: tx-sender,
      reason: "",
      governance-approval: false
    }
  )

  (map-set circuit-breakers
    { circuit-type: TYPE_LENDING }
    {
      paused: false,
      paused-at: u0,
      pause-duration: u2880, ;; ~2 days
      triggered-by: tx-sender,
      reason: "",
      governance-approval: false
    }
  )

  (map-set circuit-breakers
    { circuit-type: TYPE_ORACLE }
    {
      paused: false,
      paused-at: u0,
      pause-duration: u720, ;; ~12 hours
      triggered-by: tx-sender,
      reason: "",
      governance-approval: false
    }
  )

  (map-set circuit-breakers
    { circuit-type: TYPE_GOVERNANCE }
    {
      paused: false,
      paused-at: u0,
      pause-duration: u10080, ;; ~1 week
      triggered-by: tx-sender,
      reason: "",
      governance-approval: false
    }
  )

  ;; Log initialization
  (log-pause-event TYPE_EMERGENCY "initialized" "circuit breaker system initialized")
)
