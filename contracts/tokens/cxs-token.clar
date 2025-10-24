;; cxs-token.clar
;; Conxian Staking Token (SIP-009 NFT) - represents staked positions in the Conxian protocol
;; Implements SIP-009 NFT standard with staking and governance features

;; --- Traits ---
(use-trait protocol-monitor .all-traits.protocol-monitor-trait)
(use-trait sip-009-nft-trait .all-traits.sip-009-nft-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_OWNER u101)
(define-constant ERR_TRANSFER_DISABLED u102)
(define-constant ERR_NO_SUCH_TOKEN u103)
(define-constant ERR_SYSTEM_PAUSED u104)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var last-token-id uint u0)
(define-data-var transfers-enabled bool false)
(define-map owners uint principal)
(define-map token-uris uint (optional (string-utf8 256)))

;; Integration contracts
(define-data-var staking-contract (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

(define-read-only (exists (id uint))
  (is-some (map-get? owners id)))

(define-private (check-system-pause)
  (match (var-get protocol-monitor)
    monitor (contract-call? monitor is-paused)
    false))

;; --- Configuration ---
;; @desc Sets the contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

;; @desc Sets the principal of the staking contract.
;; @param contract-address The principal of the staking contract.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (set-staking-contract (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set staking-contract (some contract-address))
    (ok true)))

;; @desc Sets the principal of the protocol monitor contract.
;; @param monitor The principal of the protocol monitor contract.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (set-protocol-monitor (monitor principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set protocol-monitor (some monitor))
    (ok true)))

;; @desc Enables token transfers.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (enable-transfers)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfers-enabled true)
    (ok true)))

;; @desc Disables token transfers.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (disable-transfers)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfers-enabled false)
    (ok true)))

;; --- Mint / Burn ---
;; @desc Mints a new NFT and assigns it to a recipient.
;; @param recipient The principal to receive the new NFT.
;; @param uri An optional URI for the token metadata.
;; @returns (ok id) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner, (err ERR_SYSTEM_PAUSED) if the system is paused.
(define-public (mint (recipient principal) (uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    (var-set last-token-id (+ (var-get last-token-id) u1))
    (let ((id (var-get last-token-id)))
      (map-set owners id recipient)
      (map-set token-uris id uri)
      (ok id))))

(define-public (burn (id uint))
  (let ((owner (unwrap! (map-get? owners id) (err ERR_NO_SUCH_TOKEN))))
    (begin
      (asserts! (or (is-owner tx-sender) (is-eq tx-sender owner)) (err ERR_NOT_OWNER))
      (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
      (map-delete owners id)
      (map-delete token-uris id)
      (ok true))))

;; --- SIP-009 Interface ---
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (let ((owner (unwrap! (map-get? owners id) (err ERR_NO_SUCH_TOKEN))))
    (begin
      (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
      (asserts! (is-eq sender owner) (err ERR_NOT_OWNER))
      (asserts! (var-get transfers-enabled) (err ERR_TRANSFER_DISABLED))
      (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
      (map-set owners id recipient)
      (ok true))))

(define-read-only (get-owner (id uint))
  (ok (map-get? owners id)))

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (id uint))
  (ok (map-get? token-uris id)))

(define-read-only (get-transfers-enabled)
  (ok (var-get transfers-enabled))))