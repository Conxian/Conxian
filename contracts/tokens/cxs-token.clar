;; @contract Conxian Staking Position (CXS)
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc This contract implements the Conxian Staking Position (CXS), a SIP-009 compliant non-fungible token.
;; Each NFT represents a unique staked position in the Conxian protocol, providing a clear and transferable
;; representation of a user's stake.

;; --- Traits ---
(use-trait protocol-monitor-trait .security-monitoring.protocol-monitor-trait)
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

;; --- Constants ---

;; @var ERR_UNAUTHORIZED The caller is not authorized to perform the action.
(define-constant ERR_UNAUTHORIZED u1001)
;; @var ERR_NOT_OWNER The caller is not the owner of the token.
(define-constant ERR_NOT_OWNER u1002)
;; @var ERR_TRANSFER_DISABLED Token transfers are currently disabled.
(define-constant ERR_TRANSFER_DISABLED u3004)
;; @var ERR_NO_SUCH_TOKEN The specified token does not exist.
(define-constant ERR_NO_SUCH_TOKEN u3006)
;; @var ERR_SYSTEM_PAUSED The system is currently paused.
(define-constant ERR_SYSTEM_PAUSED u1003)
;; @var ERR_INVALID_CONTRACT_PRINCIPAL The provided contract principal is invalid.
(define-constant ERR_INVALID_CONTRACT_PRINCIPAL u9001)
;; @var ERR_INVALID_RECIPIENT The specified recipient is invalid.
(define-constant ERR_INVALID_RECIPIENT u3007)
;; @var ERR_INVALID_URI The provided URI is invalid.
(define-constant ERR_INVALID_URI u3006)

;; --- Data Variables and Maps ---

;; @var contract-owner The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @var last-token-id The ID of the last token minted.
;; @var last-token-id The ID of the last token minted.
(define-data-var last-token-id uint u0)
;; @var transfers-enabled A boolean indicating if token transfers are enabled.
(define-data-var transfers-enabled bool false)
;; @var owners A map of token IDs to their owners.
(define-map owners uint principal)
;; @var token-uris A map of token IDs to their metadata URIs.
(define-map token-uris uint (optional (string-utf8 256)))
;; @var staking-contract The principal of the staking contract.
(define-data-var staking-contract (optional principal) none)
;; @var protocol-monitor The principal of the protocol monitor contract.
(define-data-var protocol-monitor (optional principal) none)

;; --- Private Functions ---

;; @desc Checks if the system is paused.
;; @returns A boolean indicating if the system is paused.
(define-private (check-system-pause)
  false)

;; --- Read-Only Functions ---

;; @desc Checks if a principal is the contract owner.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is the owner.
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

;; @desc Checks if a token exists.
;; @param id The ID of the token to check.
;; @returns A boolean indicating if the token exists.
(define-read-only (exists (id uint))
  (is-some (map-get? owners id)))

;; --- Admin Functions ---

;; @desc Sets the principal of the staking contract.
;; @param contract-address The principal of the staking contract.
;; @returns A response indicating success or failure.
(define-public (set-staking-contract (contract-address principal))
  (begin
    (asserts! (is-ok (contract-call? .roles has-role "contract-owner" tx-sender))
      (err ERR_UNAUTHORIZED)
    )
    (var-set staking-contract (some contract-address))
    (print {event: "staking-contract-set", sender: tx-sender, contract-address: contract-address, block-height: block-height})
    (ok true)))

;; @desc Sets the principal of the protocol monitor contract.
;; @param monitor The principal of the protocol monitor contract.
;; @returns A response indicating success or failure.
(define-public (set-protocol-monitor (monitor principal))
  (begin
    (asserts! (is-ok (contract-call? .roles has-role "contract-owner" tx-sender)) (err ERR_UNAUTHORIZED))
    (var-set protocol-monitor (some monitor))
    (print {event: "protocol-monitor-set", sender: tx-sender, monitor: monitor, block-height: block-height})
    (ok true)))

;; @desc Enables token transfers.
;; @returns A response indicating success or failure.
(define-public (enable-transfers)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfers-enabled true)
    (print {event: "transfers-enabled", sender: tx-sender, enabled: true, block-height: block-height})
    (ok true)))

;; @desc Disables token transfers.
;; @returns A response indicating success or failure.
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
;; @returns The ID of the newly minted token, or an error.
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
;; @returns A response indicating success or failure.
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
;; @returns A response indicating success or failure.
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
;; @returns The principal of the owner, or none if the token does not exist.
(define-read-only (get-owner (id uint))
  (ok (map-get? owners id)))

;; @desc Returns the ID of the last minted token.
;; @returns The ID of the last minted token.
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

;; @desc Returns the URI of a given token ID.
;; @param id The ID of the token.
;; @returns The URI of the token, or none if not set.
(define-read-only (get-token-uri (id uint))
  (ok (map-get? token-uris id)))

;; @desc Returns whether token transfers are enabled.
;; @returns `true` if transfers are enabled, `false` otherwise.
(define-read-only (get-transfers-enabled)
  (ok (var-get transfers-enabled)))
