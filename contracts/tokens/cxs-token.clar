;; cxs-token.clar
;; Conxian Soulbound Reputation Token (SIP-009-style NFT)
;; Non-transferable: transfer is disabled to enforce soulbound semantics

;; Define SIP-009 NFT Trait
(define-trait sip-009-trait
  (
    (get-owner (uint) (response (optional principal) uint))
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    (transfer (principal principal uint (optional (buff 34))) (response bool uint))
  )
)

;; Implement the SIP-009 trait with proper syntax
(impl-trait .sip-009-trait)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_OWNER u101)
(define-constant ERR_TRANSFER_DISABLED u102)
(define-constant ERR_NO_SUCH_TOKEN u103)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var last-token-id uint u0)

(define-map owners { id: uint } { owner: principal })
(define-map token-uris { id: uint } { uri: (optional (string-utf8 256)) })

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-read-only (exists (id uint))
  (is-some (map-get? owners { id: id }))
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
      (map-set owners { id: id } { owner: recipient })
      (map-set token-uris { id: id } { uri: uri })
      (ok id)
    )
  )
)

(define-public (burn (id uint))
  (let (
      (owner (unwrap! (get owner (map-get? owners { id: id })) (err ERR_NO_SUCH_TOKEN)))
    )
    (begin
      (asserts! (or (is-owner tx-sender) (is-eq tx-sender owner)) (err ERR_NOT_OWNER))
      (map-delete owners { id: id })
      (map-delete token-uris { id: id })
      (ok true)
    )
  )
)

;; --- SIP-009 Interface ---
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (err ERR_TRANSFER_DISABLED)
)

(define-read-only (get-owner (id uint))
  (ok (match (map-get? owners { id: id })
        token
          (some (get owner token))
        none))
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (id uint))
  (ok (default-to none (get uri (map-get? token-uris { id: id }))))
)



