;; cxlp-token.clar
;; Conxian Liquidity Provider Token (SIP-010 FT) - represents liquidity provider positions
;; Enhanced with staking, yield distribution, and system integration hooks

;; --- Traits ---


;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_ENOUGH_BALANCE u101)
(define-constant ERR_MIGRATION_NOT_SET u102)
(define-constant ERR_MIGRATION_NOT_STARTED u103)
(define-constant ERR_CXD_NOT_SET u104)
(define-constant ERR_CXD_MISMATCH u105)
(define-constant ERR_EPOCH_CAP_EXCEEDED u106)
(define-constant ERR_USER_CAP_EXCEEDED u107)
(define-constant ERR_OVERFLOW u108)
(define-constant ERR_SUB_UNDERFLOW u109)
(define-constant ERR_SYSTEM_PAUSED u110)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian LP Token")
(define-data-var symbol (string-ascii 10) "CXLP")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-map balances principal uint)
(define-map minters principal bool)

;; Priority/allowance tracking
(define-map balance-since principal uint)

;; Migration configuration
(define-data-var migration-queue-contract (optional principal) none)
(define-data-var cxd-contract (optional principal) none)
(define-data-var migration-start-height (optional uint) none)
(define-data-var epoch-length uint u0)

;; Epoch liquidity controls (caps measured in CXD minted)
(define-data-var epoch-cap-cxd uint u0)
(define-map epoch-minted uint uint)
(define-map epoch-user-minted { epoch: uint, who: principal } uint)

;; User allowance parameters (measured in CXD minted)
(define-data-var user-base-cap-cxd uint u0)
(define-data-var user-duration-factor uint u0)
(define-data-var user-max-cap-cxd uint u0)

;; Mid-year auto-adjust controls
(define-data-var last-midyear-adjustment uint u0)
(define-data-var midyear-blocks uint u0)
(define-data-var midyear-adjust-bps uint u0)
(define-data-var epoch-override bool false)

;; Migration bands
(define-constant BAND0 u10000) ;; 1.00x
(define-constant BAND1 u12500) ;; 1.25x
(define-constant BAND2 u15000) ;; 1.50x
(define-constant BAND3 u20000) ;; 2.00x

;; System integration
(define-data-var protocol-monitor (optional principal) none)
(define-data-var system-integration-enabled bool true)

;; --- Safe Math ---
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (>= result a)
      (ok result)
      (err ERR_OVERFLOW))))

(define-private (safe-sub (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    (err ERR_SUB_UNDERFLOW)))

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

(define-read-only (is-minter (who principal))
  (default-to false (map-get? minters who)))

(define-private (check-system-pause)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor (default-to false (contract-call? monitor is-paused))
      false)
    false))

;; Returns the current epoch index since migration start
(define-read-only (current-epoch)
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
    )
    (begin
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (ok (/ (- block-height start) len))
    )
  ))

(define-read-only (current-band)
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
    )
    (begin
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (let ((band (/ (- block-height start) len)))
        (ok (if (>= band u3) u3 band))
      )
    )
  ))

(define-read-only (band-multiplier (band uint))
  (ok (if (is-eq band u0)
        BAND0
        (if (is-eq band u1)
          BAND1
          (if (is-eq band u2)
            BAND2
            BAND3)))))

;; --- Liquidity controls helpers ---
(define-read-only (get-epoch-minted (epoch uint))
  (default-to u0 (map-get? epoch-minted epoch)))

(define-read-only (get-user-epoch-minted (epoch uint) (who principal))
  (default-to u0 (map-get? epoch-user-minted { epoch: epoch, who: who })))

(define-read-only (get-balance-since (who principal))
  (let (
      (maybe-since (map-get? balance-since who))
      (start (var-get migration-start-height))
    )
    (default-to (default-to block-height start) maybe-since)
  ))

(define-read-only (user-epoch-capacity (who principal))
  (let (
      (base (var-get user-base-cap-cxd))
      (factor (var-get user-duration-factor))
      (max-cap (var-get user-max-cap-cxd))
      (since (get-balance-since who))
      (duration (- block-height since))
      (calc (+ base (* factor duration)))
    )
    (ok (if (> calc max-cap) max-cap calc))
  ))

(define-private (maybe-auto-adjust)
  (let (
      (mb (var-get midyear-blocks))
      (bps (var-get midyear-adjust-bps))
      (last (var-get last-midyear-adjustment))
      (override (var-get epoch-override))
    )
    (if (and (> mb u0) (> bps u0) (is-eq override false) (>= (- block-height last) mb))
      (begin
        (var-set epoch-cap-cxd (/ (* (var-get epoch-cap-cxd) bps) u10000))
        (var-set last-midyear-adjustment block-height)
        true
      )
      false
    )
  ))

;; --- Owner/Admin ---
;; @desc Sets the contract owner. Only the current owner can call this.
;; @param new-owner The principal of the new contract owner.
;; @returns A response containing a boolean indicating success or an error code.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  ))

;; @desc Sets or unsets a principal as a minter. Only the contract owner can call this.
;; @param who The principal to set or unset as a minter.
;; @param enabled A boolean indicating whether the principal should be enabled (true) or disabled (false) as a minter.
;; @returns A response containing a boolean indicating success or an error code.
(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (map-set minters who enabled)
    (ok true)
  ))

;; @desc Sets the protocol monitor contract. Only the contract owner can call this.
;; @param contract-address The principal of the protocol monitor contract.
;; @returns A response containing a boolean indicating success or an error code.
(define-public (set-protocol-monitor (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set protocol-monitor (some contract-address))
    (ok true)
  ))

;; @desc Sets the migration queue contract. Only the contract owner can call this.
;; @param queue The principal of the migration queue contract.
;; @returns A response containing a boolean indicating success or an error code.
(define-public (set-migration-queue-contract (queue principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set migration-queue-contract (some queue))
    (ok true)
  ))

;; @desc Configures the migration parameters for CXLP to CXD. Only the contract owner can call this.
;; @param cxd The principal of the CXD token contract.
;; @param start-height The block height at which the migration starts.
;; @param epoch-len The length of each epoch in blocks.
;; @returns A response containing a boolean indicating success or an error code.
(define-public (configure-migration (cxd principal) (start-height uint) (epoch-len uint))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (> epoch-len u0) (err ERR_MIGRATION_NOT_SET))
    (var-set cxd-contract (some cxd))
    (var-set migration-start-height (some start-height))
    (var-set epoch-length epoch-len)
    (ok true)
  ))

;; @desc Sets various liquidity parameters for the CXLP token. Only the contract owner can call this.
;; @param epoch-cap The maximum amount of CXD that can be minted in an epoch.
;; @param user-base The base user capacity for CXD minting.
;; @param user-factor The duration factor for user capacity calculation.
;; @param user-max The maximum user capacity for CXD minting.
;; @param midyear The number of blocks after which a mid-year adjustment can occur.
;; @param adjust-bps The basis points for mid-year adjustment.
;; @returns A response containing a boolean indicating success or an error code.
(define-public (set-liquidity-params (epoch-cap uint) (user-base uint) (user-factor uint) (user-max uint) (midyear uint) (adjust-bps uint))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set epoch-cap-cxd epoch-cap)
    (var-set user-base-cap-cxd user-base)
    (var-set user-duration-factor user-factor)
    (var-set user-max-cap-cxd user-max)
    (var-set midyear-blocks midyear)
    (var-set midyear-adjust-bps adjust-bps)
    (ok true)
  ))

;; @desc Sets the epoch override value. Only the contract owner can call this.
;; @param value A boolean indicating whether epoch override is enabled (true) or disabled (false).
;; @returns A response containing a boolean indicating success or an error code.
(define-public (set-epoch-override (value bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set epoch-override value)
    (ok true)
  ))

(define-public (auto-adjust)
  (ok (maybe-auto-adjust)))

;; --- SIP-010 interface ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (let ((sender-bal (default-to u0 (map-get? balances sender))))
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (map-set balances sender (unwrap! (safe-sub sender-bal amount) (err ERR_SUB_UNDERFLOW)))
      
      (let ((rec-bal (default-to u0 (map-get? balances recipient))))
        (map-set balances recipient (unwrap! (safe-add rec-bal amount) (err ERR_OVERFLOW)))
        (map-set balance-since recipient block-height)
      )
    )
    
    ;; Hook for migration queue
    (match (var-get migration-queue-contract)
      queue-contract (try! (contract-call? queue-contract on-cxlp-transfer sender recipient amount))
      true
    )
    (ok true)
  ))

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
    (ok true)
  ))

;; --- Mint/Burn ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (var-set total-supply (unwrap! (safe-add (var-get total-supply) amount) (err ERR_OVERFLOW)))
    
    (let ((bal (default-to u0 (map-get? balances recipient))))
      (map-set balances recipient (unwrap! (safe-add bal amount) (err ERR_OVERFLOW)))
      (map-set balance-since recipient block-height)
    )
    
    ;; Hook for migration queue
    (match (var-get migration-queue-contract)
      queue-contract (try! (contract-call? queue-contract initialize-duration-tracking recipient))
      true
    )
    (ok true)
  ))

(define-public (burn (amount uint))
  (begin
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (let ((bal (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (map-set balances tx-sender (unwrap! (safe-sub bal amount) (err ERR_SUB_UNDERFLOW)))
    )
    
    (var-set total-supply (unwrap! (safe-sub (var-get total-supply) amount) (err ERR_SUB_UNDERFLOW)))
    (ok true)
  ))

;; --- Migration: CXLP -> CXD ---
(define-public (migrate-to-cxd (amount uint) (recipient principal) (cxd-contract principal))
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
      (cxd-stored (unwrap! (var-get cxd-contract) (err ERR_CXD_NOT_SET)))
      (sender-bal (default-to u0 (map-get? balances tx-sender)))
    )
    (begin
      (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
      (maybe-auto-adjust)
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (asserts! (is-eq cxd-stored cxd-contract) (err ERR_CXD_MISMATCH))
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      
      ;; Burn CXLP from sender
      (map-set balances tx-sender (unwrap! (safe-sub sender-bal amount) (err ERR_SUB_UNDERFLOW)))
      (var-set total-supply (unwrap! (safe-sub (var-get total-supply) amount) (err ERR_SUB_UNDERFLOW)))
      
      ;; Compute band and multiplier
      (let (
          (band (unwrap! (current-band) (err u999)))
          (mult (unwrap! (band-multiplier band) (err ERR_OVERFLOW)))
          (cxd-to-mint (/ (* amount mult) u10000))
        )
        ;; Mint CXD tokens to recipient
        (try! (contract-call? cxd-contract mint cxd-to-mint recipient))
        (ok cxd-to-mint)
      )
    )
  )
)
