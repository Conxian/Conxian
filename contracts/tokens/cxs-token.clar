;; cxs-token.clar
;; Conxian Staking Token (SIP-009 NFT) - represents staked positions in the Conxian protocol
;; Implements SIP-009 NFT standard with staking and governance features

;; --- Traits ---
(use-trait sip-009-nft-trait .sip-009-nft-trait.sip-009-nft-trait)
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

;; Implement the standard trait
(impl-trait sip-009-nft-trait)

;; Constants
(define-constant TRAIT_REGISTRY .trait-registry)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_OWNER u101)
(define-constant ERR_TRANSFER_DISABLED u102)
(define-constant ERR_NO_SUCH_TOKEN u103)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var last-token-id uint u0)

(define-map owners uint principal)
(define-map token-uris uint (optional (string-utf8 256)))

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-read-only (exists (id uint))
  (is-some (map-get? owners id))
)

;; --- Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Mint / Burn ---
(define-public (mint (recipient principal) (uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set last-token-id (+ (var-get last-token-id) u1))
    (let ((id (var-get last-token-id)))
      (map-set owners id recipient)
      (map-set token-uris id uri)
      (ok id)
    )
  )
)

(define-public (burn (id uint))
  (let (
      (owner (unwrap! (map-get? owners id) (err ERR_NO_SUCH_TOKEN)))
    )
    (begin
      (asserts! (or (is-owner tx-sender) (is-eq tx-sender owner)) (err ERR_NOT_OWNER))
      (map-delete owners id)
      (map-delete token-uris id)
      (ok true)
    )
  )
)

;; --- SIP-009 Interface ---
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (err ERR_TRANSFER_DISABLED)
)

(define-read-only (get-owner (id uint))
  (ok (map-get? owners id))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (id uint))
  (ok (map-get? token-uris id))
)




