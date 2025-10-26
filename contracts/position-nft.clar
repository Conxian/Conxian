;; position-nft.clar
;; NFT representation of dimensional positions

(use-trait sip-009-nft-trait .all-traits.sip-009-nft-trait)
(use-trait dimensional-core-trait .all-traits.dimensional-core-trait)
(use-trait position-nft-trait .all-traits.position-nft-trait)

(impl-trait position-nft-trait)

;; ===== Constants =====
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_NOT_APPROVED (err u7001))
(define-constant ERR_NONEXISTENT_TOKEN (err u7002))
(define-constant ERR_INVALID_POSITION (err u7003))
(define-constant ERR_ALREADY_EXISTS (err u7004))

;; ===== Data Variables =====
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var base-uri (optional (string-utf8 1024)) none)
(define-data-var next-token-id uint u1)

;; ===== Data Maps =====
(define-non-fungible-token position-token uint)

(define-map positions 
  { token-id: uint } 
  {
    owner: principal,
    core-contract: principal,
    position-id: uint,
    created-at: uint,
    last-updated: uint,
    metadata: (optional (string-utf8 1024))
  })

(define-map token-approvals { token-id: uint } principal)
(define-map operator-approvals { owner: principal, operator: principal } bool)

;; ===== Private Functions =====
(define-private (is-owner-or-approved (token-id uint) (sender principal))
  (let ((token-owner (unwrap! (nft-get-owner? position-token token-id) false)))
    (or 
      (is-eq sender token-owner)
      (default-to false (map-get? operator-approvals { owner: token-owner, operator: sender }))
      (is-eq (some sender) (map-get? token-approvals { token-id: token-id })))))

(define-private (uint-to-string (value uint))
  (if (is-eq value u0)
    "0"
    (unwrap-panic (as-max-len? (fold concat-digit (list value) "") u10))))

(define-private (concat-digit (value uint) (acc (string-ascii 10)))
  (unwrap-panic (as-max-len? (concat (unwrap-panic (element-at "0123456789" (mod value u10))) acc) u10)))

;; ===== Read-Only Functions =====
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (ok (match (var-get base-uri)
    base-uri (some (concat base-uri (uint-to-string token-id)))
    none)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? position-token token-id) ERR_NONEXISTENT_TOKEN)))

(define-read-only (get-position-data (token-id uint))
  (ok (unwrap! (map-get? positions { token-id: token-id }) ERR_NONEXISTENT_TOKEN)))

(define-read-only (get-approval (token-id uint))
  (ok (map-get? token-approvals { token-id: token-id })))

(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (ok (default-to false (map-get? operator-approvals { owner: owner, operator: operator }))))

;; ===== Public Functions =====
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((token-owner (unwrap! (nft-get-owner? position-token token-id) ERR_NONEXISTENT_TOKEN)))
    (asserts! (is-eq sender token-owner) ERR_UNAUTHORIZED)
    (asserts! (is-owner-or-approved token-id tx-sender) ERR_NOT_APPROVED)
    
    (try! (nft-transfer? position-token token-id sender recipient))
    (map-delete token-approvals { token-id: token-id })
    
    (match (map-get? positions { token-id: token-id })
      position (map-set positions { token-id: token-id } (merge position { owner: recipient, last-updated: block-height }))
      false)
    
    (ok true)))

(define-public (approve (token-id uint) (approved principal))
  (let ((token-owner (unwrap! (nft-get-owner? position-token token-id) ERR_NONEXISTENT_TOKEN)))
    (asserts! (is-eq tx-sender token-owner) ERR_UNAUTHORIZED)
    (map-set token-approvals { token-id: token-id } approved)
    (ok true)))

(define-public (set-approval-for-all (operator principal) (approved bool))
  (begin
    (map-set operator-approvals { owner: tx-sender, operator: operator } approved)
    (ok true)))

(define-public (mint-position 
    (recipient principal)
    (core-contract principal)
    (position-id uint)
    (metadata (optional (string-utf8 1024))))
  (let ((token-id (var-get next-token-id)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (try! (nft-mint? position-token token-id recipient))
    
    (map-set positions 
      { token-id: token-id } 
      {
        owner: recipient,
        core-contract: core-contract,
        position-id: position-id,
        created-at: block-height,
        last-updated: block-height,
        metadata: metadata
      })
    
    (var-set next-token-id (+ token-id u1))
    (ok token-id)))

(define-public (burn (token-id uint))
  (let ((token-owner (unwrap! (nft-get-owner? position-token token-id) ERR_NONEXISTENT_TOKEN)))
    (asserts! (is-eq tx-sender token-owner) ERR_UNAUTHORIZED)
    
    (try! (nft-burn? position-token token-id token-owner))
    (map-delete positions { token-id: token-id })
    (map-delete token-approvals { token-id: token-id })
    (ok true)))

(define-public (update-position-metadata (token-id uint) (metadata (string-utf8 1024)))
  (let ((position (unwrap! (map-get? positions { token-id: token-id }) ERR_NONEXISTENT_TOKEN)))
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    
    (map-set positions 
      { token-id: token-id } 
      (merge position { metadata: (some metadata), last-updated: block-height }))
    (ok true)))

;; ===== Admin Functions =====
(define-public (set-base-uri (uri (string-utf8 1024)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set base-uri (some uri))
    (ok true)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))
