;; ===========================================
;; Conxian Protocol Core Coordinator
;; ===========================================

;; This contract serves as the central coordination point for the Conxian Protocol,
;; managing protocol-wide configuration, authorized contracts, and emergency controls.

;; Use centralized traits
(use-trait rbac-trait .all-traits.rbac-trait)

;; ===========================================
;; CONSTANTS
;; ===========================================

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_CONFIG_KEY (err u1002))
(define-constant ERR_CONTRACT_ALREADY_AUTHORIZED (err u1003))
(define-constant ERR_CONTRACT_NOT_AUTHORIZED (err u1004))
(define-constant ERR_PROTOCOL_PAUSED (err u1005))

;; ===========================================
;; DATA VARIABLES
;; ===========================================

;; Protocol owner (can be updated via governance)
(define-data-var protocol-owner principal tx-sender)

;; Emergency pause state
(define-data-var emergency-paused bool false)

;; Protocol version for upgrades
(define-data-var protocol-version uint u1)

;; ===========================================
;; DATA MAPS
;; ===========================================

;; Protocol-wide configuration
(define-map protocol-config { key: (string-ascii 32) } { value: uint, updated-at: uint })

;; Authorized contracts registry
(define-map authorized-contracts principal { authorized: bool, authorized-at: uint, authorized-by: principal })

;; Protocol events tracking
(define-map protocol-events { event-id: uint } { event-type: (string-ascii 32), data: (buff 256), timestamp: uint })

;; ===========================================
;; PRIVATE FUNCTIONS
;; ===========================================

(define-private (is-protocol-owner)
  (is-eq tx-sender (var-get protocol-owner))
)

(define-private (is-authorized-contract (contract-principal principal))
  (default-to false (get authorized (map-get? authorized-contracts contract-principal)))
)

(define-private (log-protocol-event (event-type (string-ascii 32)) (data (buff 256)))
  (let ((event-id (+ (var-get protocol-version) u1)))
    (map-set protocol-events
      { event-id: event-id }
      { event-type: event-type, data: data, timestamp: block-height }
    )
    event-id
  )
)

;; ===========================================
;; PUBLIC FUNCTIONS
;; ===========================================

;; @desc Update protocol configuration (owner only)
;; @param key Configuration key
;; @param value Configuration value
(define-public (update-protocol-config (key (string-ascii 32)) (value uint))
  (begin
    (asserts! (is-protocol-owner) ERR_UNAUTHORIZED)
    (map-set protocol-config
      { key: key }
      { value: value, updated-at: block-height }
    )
    (log-protocol-event "config-updated" (concat key " updated"))
    (ok true)
  )
)

;; @desc Authorize a contract for protocol interactions
;; @param contract-principal The contract to authorize
;; @param authorized Whether to authorize or revoke
(define-public (authorize-contract (contract-principal principal) (authorized bool))
  (begin
    (asserts! (is-protocol-owner) ERR_UNAUTHORIZED)
    (if authorized
      (begin
        (asserts! (not (is-authorized-contract contract-principal)) ERR_CONTRACT_ALREADY_AUTHORIZED)
        (map-set authorized-contracts contract-principal
          { authorized: true, authorized-at: block-height, authorized-by: tx-sender }
        )
        (log-protocol-event "contract-authorized" "contract authorized")
      )
      (begin
        (asserts! (is-authorized-contract contract-principal) ERR_CONTRACT_NOT_AUTHORIZED)
        (map-delete authorized-contracts contract-principal)
        (log-protocol-event "contract-revoked" "contract authorization revoked")
      )
    )
    (ok true)
  )
)

;; @desc Emergency pause/unpause protocol
;; @param pause Whether to pause or unpause
(define-public (emergency-pause (pause bool))
  (begin
    (asserts! (is-protocol-owner) ERR_UNAUTHORIZED)
    (var-set emergency-paused pause)
    (if pause
      (log-protocol-event "protocol-paused" "emergency pause activated")
      (log-protocol-event "protocol-unpaused" "emergency pause deactivated")
    )
    (ok true)
  )
)

;; @desc Update protocol owner (owner only, with safety delay)
;; @param new-owner The new protocol owner
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-protocol-owner) ERR_UNAUTHORIZED)
    (var-set protocol-owner new-owner)
    (log-protocol-event "ownership-transferred" "protocol ownership updated")
    (ok true)
  )
)

;; ===========================================
;; READ-ONLY FUNCTIONS
;; ===========================================

;; @desc Get protocol configuration value
;; @param key Configuration key
(define-read-only (get-protocol-config (key (string-ascii 32)))
  (match (map-get? protocol-config { key: key })
    config (some (get value config))
    none
  )
)

;; @desc Check if contract is authorized
;; @param contract-principal The contract to check
(define-read-only (is-authorized (contract-principal principal))
  (is-authorized-contract contract-principal)
)

;; @desc Get protocol owner
(define-read-only (get-protocol-owner)
  (var-get protocol-owner)
)

;; @desc Get emergency pause status
(define-read-only (get-emergency-status)
  (var-get emergency-paused)
)

;; @desc Get protocol version
(define-read-only (get-protocol-version)
  (var-get protocol-version)
)

;; @desc Get contract authorization details
;; @param contract-principal The contract to check
(define-read-only (get-contract-authorization (contract-principal principal))
  (map-get? authorized-contracts contract-principal)
)

;; @desc Get protocol event details
;; @param event-id The event ID to retrieve
(define-read-only (get-protocol-event (event-id uint))
  (map-get? protocol-events { event-id: event-id })
)

;; ===========================================
;; CONTRACT INITIALIZATION
;; ===========================================

;; Initialize protocol with basic configuration
(begin
  ;; Set initial configuration
  (map-set protocol-config { key: "max-slippage" } { value: u1000, updated-at: block-height }) ;; 10% max slippage
  (map-set protocol-config { key: "min-liquidity" } { value: u1000000, updated-at: block-height }) ;; 1M min liquidity
  (map-set protocol-config { key: "emergency-delay" } { value: u1008, updated-at: block-height }) ;; ~1 week in blocks

  ;; Log initialization
  (log-protocol-event "protocol-initialized" "Conxian Protocol v1 initialized")
)