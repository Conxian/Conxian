;; position-nft.clar
;; NFT representation of dimensional positions

(use-trait sip-009-nft-trait .all-traits.sip-009-nft-trait)
(use-trait dimensional-core-trait .all-traits.dimensional-core-trait)
(use-trait position-nft-trait .all-traits.position-nft-trait)

(use-trait position_nft_trait .all-traits.position-nft-trait)
 sip-009-nft-trait)
(impl-trait position_nft_trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_NOT_APPROVED (err u7001))
(define-constant ERR_NONEXISTENT_TOKEN (err u7002))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var base-uri (optional (string-utf8 1024)) none)
(define-data-var next-token-id uint u1)

;; NFT ownership
(define-non-fungible-token position-token uint)

;; Position metadata
(define-map positions {id: uint} {
  owner: principal,
  core-contract: principal,
  position-id: uint,
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
  (match (nft-get-owner? position-token token-id)
    owner (ok owner)
    (err ERR_NONEXISTENT_TOKEN)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let (
    (token-owner (unwrap! (nft-get-owner? position-token token-id) (err ERR_NONEXISTENT_TOKEN)))
  )
    (asserts! (or 
      (is-eq tx-sender token-owner)
      (is-eq (some tx-sender) (map-get? token-approvals {token-id: token-id}))
      (unwrap! (map-get? operator-approvals {owner: token-owner, operator: tx-sender}) false)
    ) ERR_NOT_APPROVED)
    
    (nft-transfer? position-token token-id sender recipient)
    (map-delete token-approvals {token-id: token-id})
    
    (match memo 
      memo (print memo)
      _ (ok 0)
    )
    
    (ok true)
  )
)

;; ===== Position Management =====
(define-public (mint-position 
    (recipient principal)
    (core-contract principal)
    (position-id uint)
    (metadata (optional (string-utf8 1024)))
  )
  (let (
    (token-id (var-get next-token-id))
    (current-block (block-height))
  )
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    
    ;; Verify position exists in core contract
    (match (contract-call? core-contract get-position recipient position-id)
      position (ok 0)
      error (err (err-to-uint error))
    )
    
    ;; Mint NFT
    (nft-mint? position-token token-id recipient)
    
    ;; Store position data
    (map-set positions {id: token-id} {
      owner: recipient,
      core-contract: core-contract,
      position-id: position-id,
      created-at: current-block,
      last-updated: current-block,
      metadata: metadata
    })
    
    ;; Increment token ID
    (var-set next-token-id (+ token-id u1))
    
    (ok token-id)
  )
)

(define-read-only (get-position-data (token-id uint))
  (match (map-get? positions {id: token-id})
    position (ok position)
    (err ERR_NONEXISTENT_TOKEN)
  )
)

(define-public (update-position-metadata 
    (token-id uint)
    (metadata (string-utf8 1024))
  )
  (let (
    (position (unwrap! (map-get? positions {id: token-id}) (err ERR_NONEXISTENT_TOKEN)))
  )
    (asserts! (is-eq tx-sender (get position 'owner)) ERR_UNAUTHORIZED)
    
    (map-set positions {id: token-id} (merge position {
      'metadata: (some metadata),
      'last-updated: block-height
    }))
    
    (ok true)
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

(define-read-only (get-token-uri (token-id uint))
  (match (var-get base-uri)
    base-uri (some (concat base-uri (unwrap-panic (uint-to-utf8 token-id) u0)))
    none none
  )
)

(define-read-only (get-owner (token-id uint))
  (match (nft-get-owner? position-token token-id)
    owner (ok owner)
    (err ERR_NONEXISTENT_TOKEN)
  )
)
