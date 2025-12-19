;; identity-badge.clar
;; Soulbound NFT representing verified identity status
;; Implements SIP-009 (Non-Fungible Token) standard
;; @desc This token is non-transferable (Soulbound) and serves as an on-chain certification of KYC status.

(impl-trait .sip-standards.sip-009-nft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_SOULBOUND (err u1003))
(define-constant ERR_NOT_FOUND (err u1004))

(define-constant CONTRACT_OWNER tx-sender)

;; --- Variables ---
(define-non-fungible-token identity-badge uint)
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-utf8 256) u"https://api.conxian.com/identity/badge/")

;; Authorized minter (KYC Registry)
(define-data-var registry-contract principal tx-sender)

;; --- Maps ---
;; Map principal to token-id for reverse lookup
(define-map owner-to-token
  principal
  uint
)

;; --- Authorization ---
(define-private (is-registry)
  (is-eq tx-sender (var-get registry-contract))
)

(define-private (is-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

;; --- Admin ---
(define-public (set-registry-contract (registry principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set registry-contract registry)
    (ok true)
  )
)

(define-public (set-base-uri (uri (string-utf8 256)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set base-uri uri)
    (ok true)
  )
)

;; --- Core Logic (Registry Only) ---

(define-public (mint (recipient principal))
  (let ((next-id (+ (var-get last-token-id) u1)))
    (asserts! (is-registry) ERR_UNAUTHORIZED)
    ;; Ensure user doesn't already have a badge
    (match (map-get? owner-to-token recipient)
      existing-id
      (ok existing-id) ;; Idempotent
      (begin
        (try! (nft-mint? identity-badge next-id recipient))
        (map-set owner-to-token recipient next-id)
        (var-set last-token-id next-id)
        (ok next-id)
      )
    )
  )
)

(define-public (burn (owner principal))
  (begin
    (asserts! (is-registry) ERR_UNAUTHORIZED)
    (match (map-get? owner-to-token owner)
      token-id
      (begin
        (try! (nft-burn? identity-badge token-id owner))
        (map-delete owner-to-token owner)
        (ok true)
      )
      (ok true) ;; Idempotent
    )
  )
)

;; --- SIP-009 Implementation ---

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? identity-badge token-id))
)

;; Soulbound: Transfer is ALWAYS forbidden
(define-public (transfer
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  ERR_SOULBOUND
)

;; --- Helper Views ---

(define-read-only (get-token-id (owner principal))
  (ok (map-get? owner-to-token owner))
)
