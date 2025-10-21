;; cxvg-token.clar

;; Conxian Governance Token (SIP-010 FT) - used for governance and protocol parameter adjustments
;; Enhanced with delegation, voting power, and governance features

;; --- Traits ---
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(impl-trait sip-010-ft-trait)

;; --- Constants ---
(define-constant TRAIT_REGISTRY .trait-registry)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_ENOUGH_BALANCE (err u101))
(define-constant ERR_SYSTEM_PAUSED (err u102))
(define-constant ERR_EMISSION_DENIED (err u103))
(define-constant ERR_OVERFLOW (err u105))
(define-constant ERR_INVALID_PARAMETERS (err u104))

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian Governance Token")
(define-data-var symbol (string-ascii 10) "CXVG")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-map balances {who: principal} {bal: uint})
(define-map minters {who: principal} {enabled: bool})

;; --- System Integration ---
(define-data-var system-integration-enabled bool true)
(define-data-var token-coordinator (optional principal) none)
(define-data-var emission-controller (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; --- Governance Features ---
(define-map delegations {delegator: principal} {delegate: principal, amount: uint})
(define-map voting-power {holder: principal} {power: uint})

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

(define-read-only (is-minter (who principal))
  (default-to false (get enabled (map-get? minters {who: who}))))

;; --- Owner/Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (map-set minters {who: who} {enabled: enabled})
    (ok true)))

;; --- System Integration Setup ---
(define-public (enable-system-integration
    (coordinator-contract principal)
    (emission-contract principal)
    (monitor-contract principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set token-coordinator (some coordinator-contract))
    (var-set emission-controller (some emission-contract))
    (var-set protocol-monitor (some monitor-contract))
    (var-set system-integration-enabled true)
    (ok true)))

(define-public (disable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set system-integration-enabled false)
    (ok true)))

;; --- System Integration Helpers ---
(define-private (check-system-pause)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor-contract true
      true)
    true))

(define-private (check-emission-allowed (amount uint))
  (if (var-get system-integration-enabled)
    (match (var-get emission-controller)
      controller-contract true
      true)
    true))

(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract true
      true)
    true))

(define-private (notify-mint (amount uint) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract true
      true)
    true))

(define-private (notify-burn (amount uint) (burner principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract true
      true)
    true))

;; --- SIP-010 Interface ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (check-system-pause) ERR_SYSTEM_PAUSED)
    (let ((sender-bal (get bal (default-to {bal: u0} (map-get? balances {who: sender})))))
      (asserts! (>= sender-bal amount) ERR_NOT_ENOUGH_BALANCE)
      (map-set balances {who: sender} {bal: (- sender-bal amount)})
      (let ((rec-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
        (map-set balances {who: recipient} {bal: (+ rec-bal amount)}))
      (notify-transfer amount sender recipient))
    (ok true)))

(define-read-only (get-balance (who principal))
  (ok (get bal (default-to {bal: u0} (map-get? balances {who: who})))))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-decimals)
  (ok (var-get decimals)))

(define-read-only (get-name)
  (ok (var-get name)))

(define-read-only (get-symbol)
  (ok (var-get symbol)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)))

;; --- Mint/Burn ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (check-system-pause) ERR_SYSTEM_PAUSED)
    (asserts! (check-emission-allowed amount) ERR_EMISSION_DENIED)
    (var-set total-supply (+ (var-get total-supply) amount))
    (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
      (map-set balances {who: recipient} {bal: (+ bal amount)}))
    (notify-mint amount recipient)
    (ok true)))

(define-public (burn (amount uint))
  (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: tx-sender})))))
    (asserts! (>= bal amount) ERR_NOT_ENOUGH_BALANCE)
    (asserts! (check-system-pause) ERR_SYSTEM_PAUSED)
    (map-set balances {who: tx-sender} {bal: (- bal amount)})
    (var-set total-supply (- (var-get total-supply) amount))
    (notify-burn amount tx-sender)
    (ok true)))

;; --- System Integration Interface ---
(define-read-only (get-system-info)
  (ok {
    integration-enabled: (var-get system-integration-enabled),
    coordinator: (var-get token-coordinator),
    emission-controller: (var-get emission-controller),
    protocol-monitor: (var-get protocol-monitor)}))

;; --- Governance Functions ---
(define-public (delegate (delegate principal) (amount uint))
  (let ((sender-bal (get bal (default-to {bal: u0} (map-get? balances {who: tx-sender})))))
    (asserts! (>= sender-bal amount) ERR_NOT_ENOUGH_BALANCE)
    (map-set delegations {delegator: tx-sender} {delegate: delegate, amount: amount})
    (let ((current-power (get power (default-to {power: u0} (map-get? voting-power {holder: delegate})))))
      (map-set voting-power {holder: delegate} {power: (+ current-power amount)}))
    (ok true)))

(define-read-only (get-voting-power (holder principal))
  (ok (get power (default-to {power: u0} (map-get? voting-power {holder: holder})))))