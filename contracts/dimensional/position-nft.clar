;; dimensional/position-nft.clar
;; NFT representation of dimensional positions
;; This is a dimensional-specific implementation that differs from the main position-nft.clar

(use-trait sip-009-nft-trait .sip-009-nft-trait.sip-009-nft-trait)

;; Implement required traits
(impl-trait .sip-009-nft-trait.sip-009-nft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED u6000)
(define-constant ERR_NOT_APPROVED u6001)
(define-constant ERR_NONEXISTENT_TOKEN u6002)
(define-constant ERR_INVALID_POSITION u6003)
(define-constant ERR_DIMENSIONAL_ONLY u6004)

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var base-uri (optional (string-utf8 256)) none)
(define-data-var next-token-id uint u1)

;; NFT ownership
(define-non-fungible-token dimensional-position-token uint)

;; Position metadata - dimensional specific
(define-map dimensional-positions
  { id: uint }
  {
    owner: principal,
    core-contract: principal,
    position-id: uint,
    dimensional-data: (string-ascii 1024),
    created-at: uint,
    last-updated: uint,
    metadata: (optional (string-utf8 1024)),
  }
)

;; Token approvals
(define-map token-approvals
  { token-id: uint }
  principal
)
(define-map operator-approvals
  {
    owner: principal,
    operator: principal,
  }
  bool
)

;; ===== Core NFT Functions =====
(define-read-only (get-token-uri (token-id uint))
  (ok (var-get base-uri))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? dimensional-position-token token-id))
)

(define-public (transfer
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  (match (nft-get-owner? dimensional-position-token token-id)
    token-owner (begin
      (asserts!
        (or
          (is-eq tx-sender token-owner)
          (is-eq (some tx-sender)
            (map-get? token-approvals { token-id: token-id })
          )
          (default-to false
            (map-get? operator-approvals {
              owner: token-owner,
              operator: tx-sender,
            })
          )
        )
        (err ERR_NOT_APPROVED)
      )

      (match (nft-transfer? dimensional-position-token token-id sender recipient)
        ok-val (begin
          (map-delete token-approvals { token-id: token-id })
          (ok true)
        )
        err-code (err err-code)
      )
    )
    (err ERR_NONEXISTENT_TOKEN)
  )
)

;; ===== Position NFT Trait Implementation =====
(define-public (mint-position-nft
    (recipient principal)
    (position-data {
      position-id: uint,
      pool: principal,
      lower-tick: int,
      upper-tick: int,
      liquidity: uint,
    })
  )
  (let (
      (token-id (var-get next-token-id))
      (current-block u0)
    )
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))

    ;; Mint NFT
    (try! (nft-mint? dimensional-position-token token-id recipient))

    ;; Store dimensional position data
    (map-set dimensional-positions { id: token-id } {
      owner: recipient,
      core-contract: (get pool position-data),
      position-id: (get position-id position-data),
      dimensional-data: "dimensional-position",
      created-at: current-block,
      last-updated: current-block,
      metadata: none,
    })

    ;; Increment token ID
    (var-set next-token-id (+ token-id u1))

    (ok token-id)
  )
)

(define-public (burn-position-nft
    (token-id uint)
    (token-owner principal)
  )
  (let ((position (unwrap! (map-get? dimensional-positions { id: token-id })
      (err ERR_NONEXISTENT_TOKEN)
    )))
    (asserts! (is-eq tx-sender (get owner position)) (err ERR_UNAUTHORIZED))

    ;; Burn NFT
    (try! (nft-burn? dimensional-position-token token-id token-owner))

    ;; Remove position data
    (map-delete dimensional-positions { id: token-id })

    (ok true)
  )
)

(define-public (transfer-position-nft
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  (let ((position (unwrap! (map-get? dimensional-positions { id: token-id })
      (err ERR_NONEXISTENT_TOKEN)
    )))
    (asserts! (is-eq tx-sender (get owner position)) (err ERR_UNAUTHORIZED))

    ;; Update position ownership
    (map-set dimensional-positions { id: token-id }
      (merge position {
        owner: recipient,
        last-updated: u0,
      })
    )

    ;; Transfer NFT
    (try! (transfer token-id sender recipient))

    (ok true)
  )
)

(define-read-only (get-position-from-nft (token-id uint))
  (match (map-get? dimensional-positions { id: token-id })
    position (ok {
      position-id: (get position-id position),
      pool: (get core-contract position),
      lower-tick: 0,
      upper-tick: 0,
      liquidity: u0,
    })
    (err ERR_NONEXISTENT_TOKEN)
  )
)

(define-public (set-authorized-pool (pool principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

(define-read-only (get-nft-metadata (token-id uint))
  (match (map-get? dimensional-positions { id: token-id })
    position (ok (get metadata position))
    (err ERR_NONEXISTENT_TOKEN)
  )
)

;; ===== Admin Functions =====
(define-public (set-base-uri (uri (string-utf8 256)))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    (var-set base-uri (some uri))
    (ok true)
  )
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))
    (var-set owner new-owner)
    (ok true)
  )
)

;; ===== SIP-009 Compliance =====
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1))
)
