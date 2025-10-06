;; audit-badge-nft.clar
;; SIP-009 compliant NFT contract for audit badges

(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(impl-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(define-non-fungible-token audit-badge-nft uint)
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NONEXISTENT_TOKEN (err u101))
(define-constant ERR_ALREADY_CLAIMED (err u102))

;; Data Storage
(define-data-var next-token-id uint u1)
(define-data-var base-token-uri (optional (string-utf8 256)) none)

;; Maps token ID to audit ID
(define-map tokens uint (tuple (audit-id uint) (metadata (string-utf8 256))))

;; Maps audit ID to token ID
(define-map audit-to-token uint (tuple (token-id uint)))

;; --- SIP-009 Required Functions ---

(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? audit-badge-nft token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? tokens token-id)
    token
      (match (var-get base-token-uri)
        base-uri (ok (some base-uri))
        (ok none)
      )
    (ok none)
  )
)

(define-read-only (get-token-uri-raw (token-id uint))
  (match (map-get? tokens token-id)
    token (ok (some (get metadata token)))
    (ok none)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (try! (nft-transfer? audit-badge-nft token-id sender recipient))
    (ok true)
  )
)

;; --- Custom Functions ---

(define-public (mint (audit-id uint) (metadata (string-utf8 256)) (recipient principal))
  (let ((caller tx-sender))
    (asserts! (is-eq caller .audit-registry) ERR_UNAUTHORIZED)
    
    ;; Check if audit already has a token
    (asserts! (is-none (map-get? audit-to-token audit-id)) ERR_ALREADY_CLAIMED)
    
    (let ((token-id (var-get next-token-id)))
      (try! (nft-mint? audit-badge-nft token-id recipient))
      
      (map-set tokens token-id
        (tuple (audit-id audit-id) (metadata metadata)))
      
      (map-set audit-to-token audit-id
        (tuple (token-id token-id)))
      
      (var-set next-token-id (+ token-id u1))
      (ok token-id)
    )
  )
)

(define-read-only (get-token-by-audit (audit-id uint))
  (match (map-get? audit-to-token audit-id)
    entry (ok (some (get token-id entry)))
    (ok none)
  )
)

(define-read-only (get-audit-by-token (token-id uint))
  (match (map-get? tokens token-id)
    token (ok (some (get audit-id token)))
    (ok none)
  )
)

;; --- Admin Functions ---

(define-public (set-base-token-uri (uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set base-token-uri (some uri))
    (ok true)
  )
)

(define-public (update-metadata (token-id uint) (metadata (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? tokens token-id)
      token
        (begin
          (map-set tokens token-id
            (merge token (tuple (metadata metadata))))
          (ok true)
        )
      (err ERR_NONEXISTENT_TOKEN)
    )
  )
)

