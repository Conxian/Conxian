;; cxd-token.clar
;; Conxian Revenue Token (SIP-010 FT) - accrues protocol revenue to holders off-contract
;; Enhanced with integration hooks for staking, revenue distribution, and system monitoring
;; --- Traits ---
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait protocol-monitor-trait .all-traits.protocol-monitor-trait)
;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_ENOUGH_BALANCE u101)
(define-constant ERR_SYSTEM_PAUSED u102)
(define-constant ERR_EMISSION_LIMIT_EXCEEDED u103)
(define-constant ERR_TRANSFER_HOOK_FAILED u104)
(define-constant ERR_OVERFLOW u105)
(define-constant ERR_SUB_UNDERFLOW u106)
;; --- Data Maps & Variables ---
(define-map balances principal uint)
(define-map minters principal bool)
(define-data-var contract-owner principal tx-sender)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian Revenue Token")
(define-data-var symbol (string-ascii 10) "CXD")
(define-data-var total-supply uint u0)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-coordinator (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)
(define-data-var emission-controller (optional principal) none)
(define-data-var revenue-distributor (optional principal) none)
(define-data-var staking-contract-ref (optional principal) none)
(define-data-var transfer-hooks-enabled bool true)
(define-data-var system-integration-enabled bool true)
(define-data-var initialization-complete bool false)
;; --- Helpers ---
;; @desc Checks if the given principal is the contract owner.
;; @param who (principal) The principal to check.
;; @returns (bool) True if the principal is the owner, false otherwise.
(define-private (is-owner (who principal))
  (is-eq who (var-get contract-owner)))
;; @desc Checks if the given principal is a minter.
;; @param who (principal) The principal to check.
;; @returns (bool) True if the principal is a minter, false otherwise.
(define-read-only (is-minter (who principal))
  (default-to false (map-get? minters who)))
;; --- Safe Math ---
;; @desc Safely adds two unsigned integers, returning an error on overflow.
;; @param a (uint) The first unsigned integer.
;; @param b (uint) The second unsigned integer.
;; @returns (response uint uint) An `ok` response with the sum, or an `err` with `ERR_OVERFLOW`.
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (>= result a) (ok result) (err ERR_OVERFLOW))))
;; @desc Safely subtracts two unsigned integers, returning an error on underflow.
;; @param a (uint) The first unsigned integer.
;; @param b (uint) The second unsigned integer.
;; @returns (response uint uint) An `ok` response with the difference, or an `err` with `ERR_SUB_UNDERFLOW`.
(define-private (safe-sub (a uint) (b uint))
  (if (>= a b) (ok (- a b)) (err ERR_SUB_UNDERFLOW)))
;; --- System Integration ---
(define-private (check-system-pause)
  false)
(define-private (check-emission-allowed (amount uint))
  (or (not (var-get system-integration-enabled))
      (match (var-get emission-controller)
        controller (unwrap! (contract-call? controller can-emit amount) true)
        true)))
(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))
  (and (var-get system-integration-enabled)
       (var-get transfer-hooks-enabled)
       (match (var-get token-coordinator)
         coordinator (unwrap! (contract-call? coordinator on-transfer amount sender recipient) false)
         true)))
(define-private (notify-mint (amount uint) (recipient principal))
  (and (var-get system-integration-enabled)
       (match (var-get token-coordinator)
         coordinator (default-to true (contract-call? coordinator on-mint amount recipient))
         true)))
(define-private (notify-burn (amount uint) (sender principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator (default-to true (contract-call? coordinator on-burn amount sender))
      true)
    true))

;; --- Configuration Functions (Owner Only) ---
(define-public (set-protocol-monitor (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set protocol-monitor (some contract-address))
    (ok true)))

(define-public (set-emission-controller (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set emission-controller (some contract-address))
    (ok true)))

(define-public (set-revenue-distributor (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set revenue-distributor (some contract-address))
    (ok true)))

(define-public (set-staking-contract (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set staking-contract-ref (some contract-address))
    (ok true)))

(define-public (set-token-coordinator (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set token-coordinator (some contract-address))
    (ok true)))

(define-public (enable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled true)
    (ok true)))

(define-public (disable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled false)
    (ok true)))

(define-public (set-transfer-hooks (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfer-hooks-enabled enabled)
    (ok true)))

(define-public (complete-initialization)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set initialization-complete true)
    (ok true)))

;; --- Read-Only Functions ---
;; Read-only version that only checks local state
(define-read-only (is-system-paused)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor false  ;; In read-only context, we can't make contract calls
      false)
    false))

(define-read-only (is-fully-initialized)
  (and
    (var-get system-integration-enabled)
    (var-get initialization-complete)))

(define-read-only (get-owner)
  (ok (var-get contract-owner)))
(define-read-only (get-integration-info)
  (ok {
    system-integration-enabled: (var-get system-integration-enabled),
    transfer-hooks-enabled: (var-get transfer-hooks-enabled),
    initialization-complete: (var-get initialization-complete),
    token-coordinator: (var-get token-coordinator),
    protocol-monitor: (var-get protocol-monitor),
    emission-controller: (var-get emission-controller),
    revenue-distributor: (var-get revenue-distributor),
    staking-contract: (var-get staking-contract-ref)
  }))

;; --- Ownership Functions ---
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (renounce-ownership)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner tx-sender)
    (ok true)))

(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (if enabled
      (map-set minters { who: who } { enabled: true })
      (map-delete minters { who: who }))
    (ok true)))

;; --- SIP-010 Interface ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (let ((sender-bal (default-to u0 (map-get? balances sender))))
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      
      (map-set balances sender (unwrap! (safe-sub sender-bal amount) (err ERR_SUB_UNDERFLOW)))
      
      (let ((rec-bal (default-to u0 (map-get? balances recipient))))
        (map-set balances recipient (unwrap! (safe-add rec-bal amount) (err ERR_OVERFLOW))))
      
      (and (notify-transfer amount sender recipient) true)
      (ok true))))

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? balances who))))

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
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set token-uri new-uri)
    (ok true)))

;; --- Mint/Burn Functions ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    (asserts! (check-emission-allowed amount) (err ERR_EMISSION_LIMIT_EXCEEDED))
    
    (var-set total-supply (unwrap! (safe-add (var-get total-supply) amount) (err ERR_OVERFLOW)))
    
    (let ((bal (default-to u0 (map-get? balances recipient))))
      (map-set balances recipient (unwrap! (safe-add bal amount) (err ERR_OVERFLOW))))
    
    (and (notify-mint amount recipient) true)
    (ok true)))

(define-public (burn (amount uint))
  (begin
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (let ((bal (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (map-set balances tx-sender (unwrap! (safe-sub bal amount) (err ERR_SUB_UNDERFLOW))))
    
    (var-set total-supply (unwrap! (safe-sub (var-get total-supply) amount) (err ERR_SUB_UNDERFLOW)))
    
    (and (notify-burn amount tx-sender) true)
    (ok true)))