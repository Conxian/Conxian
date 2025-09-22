;; cxlp-token.clar
;; Conxian Liquidity Provider Token (SIP-010 FT) - represents liquidity provider positions
;; Enhanced with staking, yield distribution, and system integration hooks

;; --- Traits ---
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait ownable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.ownable-trait)

;; Implement the standard traits
(impl-trait .sip-010-ft-trait)
(impl-trait .ownable-trait)

;; Constants
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)

;; Returns the current epoch index since migration start (not capped)
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
  )
)
;; Supports migration to CXD via epoch bands (1.0x -> 2.0x)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_ENOUGH_BALANCE u101)
(define-constant ERR_MIGRATION_NOT_SET u102)
(define-constant ERR_MIGRATION_NOT_STARTED u103)
(define-constant ERR_CXD_NOT_SET u104)
(define-constant ERR_CXD_MISMATCH u105)
(define-constant ERR_EPOCH_CAP_EXCEEDED u106)
(define-constant ERR_USER_CAP_EXCEEDED u107)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian LP Token")
(define-data-var symbol (string-ascii 10) "CXLP")
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-map balances { who: principal } { bal: uint })
(define-map minters { who: principal } { enabled: bool })

;; Priority/allowance tracking
(define-map balance-since { who: principal } { since: uint })

;; Migration configuration
(define-data-var migration-queue-contract (optional principal) none)
(define-data-var cxd-contract (optional principal) none)
(define-data-var migration-start-height (optional uint) none)
(define-data-var epoch-length uint u0)

;; Epoch liquidity controls (caps measured in CXD minted)
(define-data-var epoch-cap-cxd uint u0)
(define-map epoch-minted { epoch: uint } { amount: uint })
(define-map epoch-user-minted { epoch: uint, who: principal } { amount: uint })

;; User allowance parameters (measured in CXD minted)
(define-data-var user-base-cap-cxd uint u0)
(define-data-var user-duration-factor uint u0) ;; CXD per block added to cap
(define-data-var user-max-cap-cxd uint u0)

;; Mid-year auto-adjust controls
(define-data-var last-midyear-adjustment uint u0)
(define-data-var midyear-blocks uint u0)
(define-data-var midyear-adjust-bps uint u0) ;; e.g., 11000 = +10%
(define-data-var epoch-override bool false)

(define-constant BAND0 u10000) ;; 1.00x
(define-constant BAND1 u12500) ;; 1.25x
(define-constant BAND2 u15000) ;; 1.50x
(define-constant BAND3 u20000) ;; 2.00x

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-read-only (is-minter (who principal))
  (is-some (map-get? minters { who: who }))
)

(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    
    ;; Update total supply
    (var-set total-supply (+ (var-get total-supply) amount))
    
    ;; Update recipient balance
    (let ((bal (default-to u0 (get bal (map-get? balances { who: recipient })))))
      (map-set balances { who: recipient } { bal: (+ bal amount) })
    )
    
    (ok true)
  )
)

(define-read-only (current-band)
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
    )
    (begin
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (let ((delta (- block-height start))
            (band (/ (- block-height start) len))
          )
        (ok (if (>= band u3) u3 band))
      )
    )
  )
)

(define-read-only (band-multiplier (band uint))
  (ok (if (is-eq band u0)
        BAND0
        (if (is-eq band u1)
          BAND1
          (if (is-eq band u2)
            BAND2
            BAND3))))
)

;; --- Liquidity controls helpers ---

(define-read-only (get-epoch-minted (epoch uint))
  (default-to u0 (get amount (map-get? epoch-minted { epoch: epoch })))
)

(define-read-only (get-user-epoch-minted (epoch uint) (who principal))
  (default-to u0 (get amount (map-get? epoch-user-minted { epoch: epoch, who: who })))
)

(define-read-only (get-balance-since (who principal))
  (let (
      (maybe-since (get since (map-get? balance-since { who: who })))
      (start (var-get migration-start-height))
    )
    (default-to (default-to block-height start) maybe-since)
  )
)

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
  )
)

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
  )
)

;; --- Owner/Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (if enabled
      (map-set minters { who: who } { enabled: true })
      (map-delete minters { who: who })
    )
    (ok true)
  )
)

(define-public (set-migration-queue-contract (queue principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set migration-queue-contract (some queue))
    (ok true)
  )
)

(define-public (configure-migration (cxd principal) (start-height uint) (epoch-len uint))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (> epoch-len u0) (err ERR_MIGRATION_NOT_SET))
    (var-set cxd-contract (some cxd))
    (var-set migration-start-height (some start-height))
    (var-set epoch-length epoch-len)
    (ok true)
  )
)

;; Liquidity parameter configuration (owner/DAO)
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
  )
)

(define-public (set-epoch-override (value bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set epoch-override value)
    (ok true)
  )
)

(define-public (auto-adjust)
  (ok (maybe-auto-adjust))
)

;; --- SIP-010 interface ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (let ((sender-bal (default-to u0 (get bal (map-get? balances { who: sender })))) )
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (map-set balances { who: sender } { bal: (- sender-bal amount) })
      (let ((rec-bal (default-to u0 (get bal (map-get? balances { who: recipient })))) )
        (map-set balances { who: recipient } { bal: (+ rec-bal amount) })
        (map-set balance-since { who: recipient } { since: block-height })
      )
    )
    ;; --- HOOK FOR MIGRATION QUEUE ---
    (match (var-get migration-queue-contract)
      queue-contract (try! (contract-call? queue-contract on-cxlp-transfer sender recipient amount))
      none           true ;; Do nothing if queue contract is not set
    )
    (ok true)
  )
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (get bal (map-get? balances { who: who }))))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-decimals)
  (ok (var-get decimals))
)

(define-read-only (get-name)
  (ok (var-get name))
)

(define-read-only (get-symbol)
  (ok (var-get symbol))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (if (is-eq tx-sender (var-get contract-owner))
    (begin
      (var-set token-uri new-uri)
      (ok true)
    )
    (err ERR_UNAUTHORIZED)
  )
)

;; --- Mint/Burn (admin or authorized minters) ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (var-set total-supply (+ (var-get total-supply) amount))
    (let ((bal (default-to u0 (get bal (map-get? balances { who: recipient })))) )
      (map-set balances { who: recipient } { bal: (+ bal amount) })
      (map-set balance-since { who: recipient } { since: block-height })
    )
    ;; --- HOOK FOR MIGRATION QUEUE ---
    (match (var-get migration-queue-contract)
      queue-contract (try! (contract-call? queue-contract initialize-duration-tracking recipient))
      none           true ;; Do nothing if queue contract is not set
    )
    (ok true)
  )
)

(define-public (burn (amount uint))
  (let ((bal (default-to u0 (get bal (map-get? balances { who: tx-sender })))) )
    (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
    (map-set balances { who: tx-sender } { bal: (- bal amount) })
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)

;; --- Migration: CXLP -> CXD ---
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.sip-010-ft-trait)
(define-public (migrate-to-cxd (amount uint) (recipient principal) (cxd <sip-010-ft-trait>))
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
      (cxd-stored (unwrap! (var-get cxd-contract) (err ERR_CXD_NOT_SET)))
      (sender-bal (default-to u0 (get bal (map-get? balances { who: tx-sender }))))
    )
    (begin
      (maybe-auto-adjust)
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (asserts! (is-eq cxd-stored (contract-of cxd)) (err ERR_CXD_MISMATCH))
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      ;; burn CXLP from sender
      (map-set balances { who: tx-sender } { bal: (- sender-bal amount) })
      (var-set total-supply (- (var-get total-supply) amount))
      ;; compute band and multiplier
      (let (
          (band (unwrap! (current-band) (err u999)))
          (mult (unwrap! (band-multiplier band) (err u998)))
          (cxd-out (/ (* amount mult) u10000))
          (epoch (unwrap! (current-epoch) (err u997)))
          (epoch-cap (var-get epoch-cap-cxd))
          (epoch-used (get-epoch-minted epoch))
          (user-cap (unwrap! (user-epoch-capacity tx-sender) (err u996)))
          (user-used (get-user-epoch-minted epoch tx-sender))
        )
        ;; enforce epoch cap if configured
        (asserts! (or (is-eq epoch-cap u0) (<= (+ epoch-used cxd-out) epoch-cap)) (err ERR_EPOCH_CAP_EXCEEDED))
        ;; enforce per-user cap
        (asserts! (<= (+ user-used cxd-out) user-cap) (err ERR_USER_CAP_EXCEEDED))
        ;; mint CXD to recipient (requires this contract to be an authorized minter in CXD)
        (try! (as-contract (contract-call? cxd mint recipient cxd-out)))
        ;; update epoch and user usage
        (map-set epoch-minted { epoch: epoch } { amount: (+ epoch-used cxd-out) })
        (map-set epoch-user-minted { epoch: epoch, who: tx-sender } { amount: (+ user-used cxd-out) })
        (ok {band: band, multiplier: mult, cxd-amount: cxd-out})
      )
    )
  )
)
