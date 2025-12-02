(use-trait sip-009-nft-trait .defi-traits.sip-009-nft-trait)
(impl-trait .defi-traits.sip-009-nft-trait)

(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_TRANSFER_DISABLED (err u2002))
(define-constant ERR_NOT_OWNER (err u2003))

(define-data-var admin principal tx-sender)
(define-data-var minter (optional principal) none)
(define-data-var last-id uint u0)

(define-map owners uint principal)

(define-read-only (get-last-token-id)
  (ok (var-get last-id)))

(define-read-only (get-owner (token-id uint))
  (ok (map-get? owners token-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok none))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (err u2002))

(define-public (set-minter (who principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set minter (some who))
    (ok true)))

(define-public (mint-role (role (string-ascii 32)) (to principal))
  (let ((m (var-get minter)))
    (begin
      (asserts!
        (match m x (is-eq tx-sender x) false)
        ERR_UNAUTHORIZED)
      (var-set last-id (+ (var-get last-id) u1))
      (map-set owners (var-get last-id) to)
      (print { event: "role-minted", role: role, token-id: (var-get last-id), to: to })
      (ok (var-get last-id)))))

(define-public (burn-role (token-id uint))
  (let ((caller tx-sender)
        (m (var-get minter)))
    (begin
      (asserts!
        (or (match m x (is-eq caller x) false)
            (is-eq caller (var-get admin)))
        ERR_UNAUTHORIZED)
      (match (map-get? owners token-id)
        owner (begin
                (map-delete owners token-id)
                (ok true))
        (ok true)))))

