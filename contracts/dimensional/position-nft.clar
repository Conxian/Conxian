;; dimensional/position-nft.clar
;; NFT representation of dimensional positions
;; This is a dimensional-specific implementation that differs from the main position-nft.clar

(use-trait sip-009-nft-trait .all-traits.sip-009-nft-trait)

;; Implement required traits
(impl-trait .all-traits.sip-009-nft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_NOT_APPROVED (err u6001))
(define-constant ERR_NONEXISTENT_TOKEN (err u6002))
(define-constant ERR_INVALID_POSITION (err u6003))
(define-constant ERR_DIMENSIONAL_ONLY (err u6004))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var base-uri (optional (string-utf8 1024)) none)
(define-data-var next-token-id uint u1)

;; NFT ownership
(define-non-fungible-token dimensional-position-token uint)

;; Position metadata - dimensional specific
(define-map dimensional-positions {id: uint} {
  owner: principal,
  core-contract: principal,
  position-id: uint,
  dimensional-data: (string-utf8 1024),
  created-at: uint,
  last-updated: uint,
  metadata: (optional (string-utf8 1024))
})

;; Token approvals
(define-map token-approvals {token-id: uint} principal)
(define-map operator-approvals {owner: principal, operator: principal} bool)

;; ===== Core NFT Functions =====
(define-read-only (get-token-uri (token-id uint))
  (match (var-get base-uri)
    base-uri (some (concat base-uri (unwrap-panic (uint-to-utf8 token-id) u0)))
    none none
  )
)

(define-read-only (get-owner (token-id uint))
  (match (nft-get-owner? dimensional-position-token token-id)
    owner (ok owner)
    (err ERR_NONEXISTENT_TOKEN)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let (
    (token-owner (unwrap! (nft-get-owner? dimensional-position-token token-id) (err ERR_NONEXISTENT_TOKEN)))
  )
    (asserts! (or
      (is-eq tx-sender token-owner)
      (is-eq (some tx-sender) (map-get? token-approvals {token-id: token-id}))
      (unwrap! (map-get? operator-approvals {owner: token-owner, operator: tx-sender}) false)
    ) ERR_NOT_APPROVED)

    (nft-transfer? dimensional-position-token token-id sender recipient)
    (map-delete token-approvals {token-id: token-id})

    (ok true)
  )
)

;; ===== Position NFT Trait Implementation =====
(define-public (mint-position-nft
    (recipient principal)
    (position-data (tuple (position-id uint) (pool principal) (lower-tick int) (upper-tick int) (liquidity uint)))
  )
  (let (
    (token-id (var-get next-token-id))
    (current-block (block-height))
  )
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)

    ;; Mint NFT
    (nft-mint? dimensional-position-token token-id recipient)

    ;; Store dimensional position data
    (map-set dimensional-positions {id: token-id} {
      owner: recipient,
      core-contract: (get pool position-data),
      position-id: (get position-id position-data),
      dimensional-data: "dimensional-position",
      created-at: current-block,
      last-updated: current-block,
      metadata: none
    })

    ;; Increment token ID
    (var-set next-token-id (+ token-id u1))

    (ok token-id)
  )
)

(define-public (burn-position-nft (token-id uint) (owner principal))
  (let (
    (position (unwrap! (map-get? dimensional-positions {id: token-id}) (err ERR_NONEXISTENT_TOKEN)))
  )
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)

    ;; Burn NFT
    (nft-burn? dimensional-position-token token-id owner)

    ;; Remove position data
    (map-delete dimensional-positions {id: token-id})

    (ok true)
  )
)

(define-public (transfer-position-nft (token-id uint) (sender principal) (recipient principal))
  (let (
    (position (unwrap! (map-get? dimensional-positions {id: token-id}) (err ERR_NONEXISTENT_TOKEN)))
  )
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)

    ;; Update position ownership
    (map-set dimensional-positions {id: token-id} (merge position {
      owner: recipient,
      last-updated: block-height
    }))

    ;; Transfer NFT
    (try! (transfer token-id sender recipient))

    (ok true)
  )
)

(define-read-only (get-position-from-nft (token-id uint))
  (match (map-get? dimensional-positions {id: token-id})
    position (ok {
      position-id: (get position-id position),
      pool: (get core-contract position),
      lower-tick: i0,
      upper-tick: i0,
      liquidity: u0
    })
    (err ERR_NONEXISTENT_TOKEN)
  )
)

(define-public (set-authorized-pool (pool principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (ok true)
  )
)

(define-read-only (get-nft-metadata (token-id uint))
  (match (map-get? dimensional-positions {id: token-id})
    position (ok (get metadata position))
    (err ERR_NONEXISTENT_TOKEN)
  )
)

;; ===== Admin Functions =====
(define-public (set-base-uri (uri (string-utf8 1024)))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set base-uri (some uri))
    (ok true)
  )
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set owner new-owner)
    (ok true)
  )
)

;; ===== SIP-009 Compliance =====
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1))
)