(use-trait position-nft-trait .all-traits.position-nft-trait)

;; position-nft.clar
;; NFT representation of dimensional positions

(use-trait position_nft_trait .all-traits.position-nft-trait)
 .all-traits.position-nft-trait)

;; SIP-009 Non-Fungible Token for Concentrated Liquidity Positions
(define-non-fungible-token concentrated-liquidity-positions uint)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_POSITION_NOT_FOUND (err u102))
(define-constant ERR_POOL_NOT_AUTHORIZED (err u103))
(define-constant CONTRACT_OWNER tx-sender)

;; --- Data Variables ---
(define-data-var last-token-id uint u0)
(define-data-var pool-contract principal tx-sender)

;; Position data storage
(define-map position-data uint {
  position-id: uint,
  pool: principal,
  lower-tick: int,
  upper-tick: int,
  liquidity: uint
})

;; --- Trait Implementation ---

(define-public (mint-position-nft (recipient principal) (position-data (tuple (position-id uint) (pool principal) (lower-tick int) (upper-tick int) (liquidity uint))))
  (begin
    (asserts! (is-eq tx-sender (var-get pool-contract)) ERR_POOL_NOT_AUTHORIZED)

    (let ((token-id (+ (var-get last-token-id) u1)))
      (try! (nft-mint? concentrated-liquidity-positions token-id recipient))

      ;; Store position data
      (map-set position-data token-id position-data)

      (var-set last-token-id token-id)
      (ok token-id))))

(define-public (burn-position-nft (token-id uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get pool-contract)) ERR_POOL_NOT_AUTHORIZED)
    (asserts! (is-eq (unwrap! (nft-get-owner? concentrated-liquidity-positions token-id) ERR_NOT_TOKEN_OWNER) owner) ERR_NOT_TOKEN_OWNER)

    (map-delete position-data token-id)
    (try! (nft-burn? concentrated-liquidity-positions token-id owner))
    (ok true)))

(define-public (transfer-position-nft (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (is-some (nft-get-owner? concentrated-liquidity-positions token-id)) (err ERR_POSITION_NOT_FOUND))
    (asserts! (is-eq (unwrap! (nft-get-owner? concentrated-liquidity-positions token-id) ERR_NOT_TOKEN_OWNER) sender) ERR_NOT_TOKEN_OWNER)

    (try! (nft-transfer? concentrated-liquidity-positions token-id sender recipient))
    (ok true)))

(define-read-only (get-position-from-nft (token-id uint))
  (ok (unwrap! (map-get? position-data token-id) ERR_POSITION_NOT_FOUND)))

(define-public (set-authorized-pool (pool principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set pool-contract pool)
    (ok true)))

(define-read-only (get-nft-metadata (token-id uint))
  (ok (some "https://conxian.io/positions/")))

;; --- Legacy Functions (for backward compatibility) ---

(define-public (set-pool-contract (pool principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set pool-contract pool)
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (transfer-position-nft token-id sender recipient))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? concentrated-liquidity-positions token-id)))

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
  (get-nft-metadata token-id))

(define-public (mint (recipient principal))
  (mint-position-nft recipient {position-id: u0, pool: (var-get pool-contract), lower-tick: i0, upper-tick: i0, liquidity: u0}))

(define-public (burn (token-id uint) (owner principal))
  (burn-position-nft token-id owner))