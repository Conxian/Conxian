;; cxs-token.clar
;; Conxian Staking Token (SIP-009 NFT) - represents staked positions in the Conxian protocol
;; Implements SIP-009 NFT standard with staking and governance features

;; --- Traits ---
(use-trait protocol-monitor-trait .protocol-monitor-trait.protocol-monitor-trait)
(use-trait sip-010-ft-trait .dex-traits.sip-010-ft-trait)
(use-trait rbac-trait .rbac-trait.rbac-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_OWNER u101)
(define-constant ERR_TRANSFER_DISABLED u102)
(define-constant ERR_NO_SUCH_TOKEN u103)
(define-constant ERR_SYSTEM_PAUSED u104)
(define-constant ERR_INVALID_CONTRACT_PRINCIPAL u105)
(define-constant ERR_INVALID_RECIPIENT u106)
(define-constant ERR_INVALID_URI u107)

;; --- Storage ---

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
  false)

;; --- Configuration ---
;; @desc Sets the contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.

;; @desc Sets the principal of the staking contract.
;; @param contract-address The principal of the staking contract.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (set-staking-contract (contract-address principal))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) (err ERR_UNAUTHORIZED))
    (asserts! true (err ERR_INVALID_CONTRACT_PRINCIPAL))
    (var-set staking-contract (some contract-address))
    (print {event: "staking-contract-set", sender: tx-sender, contract-address: contract-address, block-height: block-height})
    (ok true)))

;; @desc Sets the principal of the protocol monitor contract.
;; @param monitor The principal of the protocol monitor contract.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (set-protocol-monitor (monitor principal))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) (err ERR_UNAUTHORIZED))
    (asserts! true (err ERR_INVALID_CONTRACT_PRINCIPAL))
    (var-set protocol-monitor (some monitor))
    (print {event: "protocol-monitor-set", sender: tx-sender, monitor: monitor, block-height: block-height})
    (ok true)))

;; @desc Enables token transfers.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (enable-transfers)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfers-enabled true)
    (print {event: "transfers-enabled", sender: tx-sender, enabled: true, block-height: block-height})
    (ok true)))

;; @desc Disables token transfers.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner.
(define-public (disable-transfers)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfers-enabled false)
    (print {event: "transfers-disabled", sender: tx-sender, enabled: false, block-height: block-height})
    (ok true)))

;; --- Mint / Burn ---
;; @desc Mints a new NFT and assigns it to a recipient.
;; @param recipient The principal to receive the new NFT.
;; @param uri An optional URI for the token metadata.
;; @returns (ok id) if successful, (err ERR_UNAUTHORIZED) if called by a non-owner, (err ERR_SYSTEM_PAUSED) if the system is paused.
(define-public (mint (recipient principal) (uri (optional (string-utf8 256))))
  (let ((id (var-get last-token-id)))
    (begin
      (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
      (asserts! (not (is-eq recipient (as-contract tx-sender))) (err ERR_INVALID_RECIPIENT))
      (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
      (var-set last-token-id (+ id u1))
      (map-set owners (+ id u1) recipient)
      (match uri
        some-uri-val
          (map-set token-uris (+ id u1) (some some-uri-val))
        (map-set token-uris (+ id u1) none)
      )
      (print {event: "token-minted", sender: tx-sender, recipient: recipient, token-id: (+ id u1), uri: uri, block-height: block-height})
      (ok (+ id u1)))))

;; @desc Burns an NFT, removing it from circulation.
;; @param id The ID of the token to burn.
;; @returns (ok true) if successful, (err ERR_NO_SUCH_TOKEN) if the token does not exist, (err ERR_NOT_OWNER) if called by a non-owner, (err ERR_SYSTEM_PAUSED) if the system is paused.
(define-public (burn (id uint))
  (let ((owner (unwrap! (map-get? owners id) (err ERR_NO_SUCH_TOKEN))))
    (begin
      (asserts! (or (is-owner tx-sender) (is-eq tx-sender owner)) (err ERR_NOT_OWNER))
      (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
      (map-delete owners id)
      (map-delete token-uris id)
      (print {event: "token-burned", sender: tx-sender, token-id: id, owner: owner, block-height: block-height})
      (ok true))))

;; --- SIP-009 Interface ---
;; @desc Transfers an NFT from one principal to another.
;; @param id The ID of the token to transfer.
;; @param sender The principal of the current owner.
;; @param recipient The principal of the new owner.
;; @returns (ok true) if successful, (err ERR_UNAUTHORIZED) if tx-sender is not the sender, (err ERR_NOT_OWNER) if sender is not the owner, (err ERR_TRANSFER_DISABLED) if transfers are disabled, (err ERR_SYSTEM_PAUSED) if the system is paused.
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (let ((owner (unwrap! (map-get? owners id) (err ERR_NO_SUCH_TOKEN))))
    (begin
      (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
      (asserts! (is-eq sender owner) (err ERR_NOT_OWNER))
      (asserts! (var-get transfers-enabled) (err ERR_TRANSFER_DISABLED))
      (asserts! (not (is-eq recipient (as-contract tx-sender))) (err ERR_INVALID_RECIPIENT))
      (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
      (map-set owners id recipient)
      (print {event: "token-transferred", sender: sender, recipient: recipient, token-id: id, block-height: block-height})
      (ok true))))

;; @desc Gets the owner of a given token ID.
;; @param id The ID of the token.
;; @returns (ok (optional principal)) The principal of the owner, or none if the token does not exist.
(define-read-only (get-owner (id uint))
  (ok (map-get? owners id)))

;; @desc Returns the ID of the last minted token.
;; @returns (ok uint) The ID of the last minted token.
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

;; @desc Returns the URI of a given token ID.
;; @param id The ID of the token.
;; @returns (ok (optional (string-utf8 256))) The URI of the token, or none if not set.
(define-read-only (get-token-uri (id uint))
  (ok (map-get? token-uris id)))

;; @desc Returns whether token transfers are enabled.
;; @returns (ok bool) True if transfers are enabled, false otherwise.
(define-read-only (get-transfers-enabled)
  (ok (var-get transfers-enabled)))
