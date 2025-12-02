;; @desc Conxian Protocol Core Coordinator
;; This contract serves as the central coordination point for the Conxian Protocol,
;; managing protocol-wide configuration, authorized contracts, and emergency controls.

;; @constants
;; @var ERR_UNAUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_UNAUTHORIZED (err u1001))
;; @var ERR_INVALID_CONFIG_KEY: The specified configuration key is invalid.
(define-constant ERR_INVALID_CONFIG_KEY (err u1005))
;; @var ERR_CONTRACT_ALREADY_AUTHORIZED: The specified contract is already authorized.
(define-constant ERR_CONTRACT_ALREADY_AUTHORIZED (err u9001))
;; @var ERR_CONTRACT_NOT_AUTHORIZED: The specified contract is not authorized.
(define-constant ERR_CONTRACT_NOT_AUTHORIZED (err u9001))
;; @var ERR_PROTOCOL_PAUSED: The protocol is currently paused.
(define-constant ERR_PROTOCOL_PAUSED (err u1003))

;; @data-vars
;; @var protocol-owner: The principal of the protocol owner.
(define-data-var protocol-owner principal tx-sender)
;; @var emergency-paused: A boolean indicating if the protocol is in an emergency pause.
(define-data-var emergency-paused bool false)
;; @var protocol-version: The version of the protocol.
(define-data-var protocol-version uint u1)
;; @var protocol-config: A map of protocol-wide configuration.
(define-map protocol-config { key: (string-ascii 32) } { value: uint, updated-at: uint })
;; @var authorized-contracts: A map of authorized contracts.
(define-map authorized-contracts principal { authorized: bool, authorized-at: uint, authorized-by: principal })
;; @var protocol-events: A map of protocol events.
(define-map protocol-events
  { event-id: uint }
  {
    event-type: (string-ascii 32),
    data: (string-ascii 256),
    timestamp: uint,
  }
)

;; --- Private Functions ---
;; @desc Check if the caller is the protocol owner.
;; @returns (bool): True if the caller is the protocol owner, false otherwise.
(define-private (is-protocol-owner)
  (is-eq tx-sender (var-get protocol-owner))
)

;; @desc Check if a contract is authorized.
;; @param contract-principal: The principal of the contract to check.
;; @returns (bool): True if the contract is authorized, false otherwise.
(define-private (is-authorized-contract (contract-principal principal))
  (default-to false (get authorized (map-get? authorized-contracts contract-principal)))
)

;; @desc Log a protocol event.
;; @param event-type: The type of the event.
;; @param data: The data associated with the event.
;; @returns (uint): The ID of the new event.
(define-private (log-protocol-event (event-type (string-ascii 32)) (data (string-ascii 256)))
  (let ((event-id (+ (var-get protocol-version) u1)))
    (map-set protocol-events
      { event-id: event-id }
      { event-type: event-type, data: data, timestamp: block-height }
    )
    event-id
  )
)

;; --- Public Functions ---
;; @desc Update a protocol configuration value (owner only).
;; @param key: The configuration key.
;; @param value: The configuration value.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (update-protocol-config (key (string-ascii 32)) (value uint))
  (begin
    (asserts! (is-protocol-owner) ERR_UNAUTHORIZED)
    (map-set protocol-config
      { key: key }
      { value: value, updated-at: block-height }
    )
    (log-protocol-event "config-updated"
      (concat key " updated")
    )
    (ok true)
  )
)

;; @desc Authorize or de-authorize a contract for protocol interactions.
;; @param contract-principal: The contract to authorize.
;; @param authorized: A boolean indicating whether to authorize or de-authorize.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
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

;; @desc Pause or unpause the protocol in an emergency.
;; @param pause: A boolean indicating whether to pause or unpause.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (emergency-pause (pause bool))
  (begin
    (asserts! (is-protocol-owner) ERR_UNAUTHORIZED)
    (var-set emergency-paused pause)
    (if pause
      (log-protocol-event "protocol-paused"
        "emergency pause activated"
      )
      (log-protocol-event "protocol-unpaused"
        "emergency pause deactivated"
      )
    )
    (ok true)
  )
)

;; @desc Transfer ownership of the protocol (owner only, with safety delay).
;; @param new-owner: The principal of the new protocol owner.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-protocol-owner) ERR_UNAUTHORIZED)
    (var-set protocol-owner new-owner)
    (log-protocol-event "ownership-transferred" "protocol ownership updated")
    (ok true)
  )
)

;; --- Read-Only Functions ---
;; @desc Get a protocol configuration value.
;; @param key: The configuration key.
;; @returns (optional uint): The configuration value, or none if not found.
(define-read-only (get-protocol-config (key (string-ascii 32)))
  (match (map-get? protocol-config { key: key })
    config (some (get value config))
    none
  )
)

;; @desc Check if a contract is authorized.
;; @param contract-principal: The contract to check.
;; @returns (bool): True if the contract is authorized, false otherwise.
(define-read-only (is-authorized (contract-principal principal))
  (is-authorized-contract contract-principal)
)

;; @desc Get the protocol owner.
;; @returns (principal): The principal of the protocol owner.
(define-read-only (get-protocol-owner)
  (var-get protocol-owner)
)

;; @desc Get the emergency pause status.
;; @returns (bool): True if the protocol is in an emergency pause, false otherwise.
(define-read-only (get-emergency-status)
  (var-get emergency-paused)
)

;; @desc Get the protocol version.
;; @returns (uint): The version of the protocol.
(define-read-only (get-protocol-version)
  (var-get protocol-version)
)

;; @desc Get the authorization details for a contract.
;; @param contract-principal: The contract to check.
;; @returns (optional { ... }): A tuple containing the authorization details, or none if not found.
(define-read-only (get-contract-authorization (contract-principal principal))
  (map-get? authorized-contracts contract-principal)
)

;; @desc Get the details for a protocol event.
;; @param event-id: The ID of the event to retrieve.
;; @returns (optional { ... }): A tuple containing the event details, or none if not found.
(define-read-only (get-protocol-event (event-id uint))
  (map-get? protocol-events { event-id: event-id })
)

;; --- Initialization ---
(begin
  ;; Set initial configuration
  (map-set protocol-config { key: "max-slippage" } { value: u1000, updated-at: block-height }) ;; 10% max slippage
  (map-set protocol-config { key: "min-liquidity" } { value: u1000000, updated-at: block-height }) ;; 1M min liquidity
  (map-set protocol-config { key: "emergency-delay" } { value: u1008, updated-at: block-height }) ;; ~1 week in blocks

  ;; Log initialization
  (log-protocol-event "protocol-initialized" "Conxian Protocol v1 initialized")
)
