;; Concentrated Position NFT Contract
;; NFT representation for concentrated liquidity positions
;; Provides ERC-721 style functionality for position management

;; Traits
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait position-nft-trait .all-traits.position-nft-trait)

;; Implementation
(impl-trait .all-traits.position-nft-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_SUPPLY u1000000) ;; Maximum NFT supply
(define-constant METADATA_URI "https://conxian.io/api/positions/")

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_TOKEN_NOT_FOUND (err u2001))
(define-constant ERR_INVALID_AMOUNT (err u2002))
(define-constant ERR_MAX_SUPPLY_REACHED (err u2003))
(define-constant ERR_NOT_TOKEN_OWNER (err u2004))

;; NFT Data Variables
(define-data-var token-id-nonce uint u1)
(define-data-var max-supply uint MAX_SUPPLY)

;; NFT Maps
(define-map token-metadata
    uint
    {
        token-uri: (string-ascii 256),
        extension: {
            name: (string-ascii 256),
            description: (string-ascii 256),
            image: (string-ascii 256),
            properties: {
                pool: principal, ;; Changed from (string-ascii 256) to principal
                "tick-lower": int,
                "tick-upper": int,
                "liquidity-amount": uint,
                "asset-x-amount": uint,
                "asset-y-amount": uint,
                "creation-block": uint,
                "last-updated-block": uint
            }
        }
    }
)

(define-map token-owners
  uint ;; token ID
  principal ;; owner
)

(define-map owner-token-count
  principal ;; owner
  uint ;; token count
)

(define-map token-approvals
  uint ;; token ID
  principal ;; approved operator
)

(define-map operator-approvals
  principal ;; owner
  principal ;; operator
  bool ;; approved
)

;; Read-only functions
(define-read-only (get-token-uri (token-id uint))
  (let ((metadata (unwrap-panic (map-get? token-metadata token-id))))
    (some (concat METADATA_URI (to-ascii token-id)))
  )
)

(define-read-only (get-owner (token-id uint))
  (map-get? token-owners token-id)
)

(define-read-only (get-balance (owner principal))
  (default-to u0 (map-get? owner-token-count owner))
)

(define-read-only (get-approved (token-id uint))
  (map-get? token-approvals token-id)
)

(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (default-to false (map-get? operator-approvals { owner: owner, operator: operator }))
)

(define-read-only (get-token-metadata (token-id uint))
  (map-get? token-metadata token-id)
)

(define-read-only (get-total-supply)
  (- (var-get token-id-nonce) u1)
)

;; Private helper functions
(define-private (mint-position-nft
  (recipient principal)
  (pool-contract principal)
  (tick-lower int)
  (tick-upper int)
  (liquidity uint)
)
  (let ((token-id (var-get token-id-nonce)))
    (asserts! (<= token-id (var-get max-supply)) ERR_MAX_SUPPLY_REACHED)

    ;; Create metadata
    (map-set token-metadata token-id
      {
        name: (concat "Concentrated Position #" (to-ascii token-id)),
        description: (concat "Concentrated liquidity position from tick " (to-ascii tick-lower) " to " (to-ascii tick-upper)),
        image: (concat "https://conxian.io/positions/" (to-ascii token-id) ".png"),
        attributes: (list
          { trait_type: "Pool", value: (contract-of pool-contract) }
          { trait_type: "Tick Lower", value: (to-ascii tick-lower) }
          { trait_type: "Tick Upper", value: (to-ascii tick-upper) }
          { trait_type: "Liquidity", value: (to-ascii liquidity) }
        ),
        properties: {
          pool: pool-contract,
          "tick-lower": tick-lower,
          "tick-upper": tick-upper,
          "liquidity-amount": liquidity,
          "asset-x-amount": u0, ;; Placeholder, actual value to be calculated
          "asset-y-amount": u0, ;; Placeholder, actual value to be calculated
          "creation-block": (unwrap-panic (get-block-info? height)),
          "last-updated-block": (unwrap-panic (get-block-info? height))
        }
      }
    )

    ;; Set ownership
    (map-set token-owners token-id recipient)
    (map-set owner-token-count recipient (+ (get-balance recipient) u1))

    ;; Increment token ID
    (var-set token-id-nonce (+ token-id u1))

    (print {
      event: "mint",
      token-id: token-id,
      recipient: recipient,
      pool: pool-contract,
      tick-lower: tick-lower,
      tick-upper: tick-upper,
      liquidity: liquidity
    })

    (ok token-id)
  )
)

(define-private (burn-position-nft (token-id uint))
  (let ((owner (unwrap-panic (get-owner token-id))))
    (asserts! (or (is-eq tx-sender owner) (is-approved-for-all owner tx-sender)) ERR_NOT_TOKEN_OWNER)

    ;; Clear metadata
    (map-delete token-metadata token-id)

    ;; Clear ownership
    (map-delete token-owners token-id)
    (map-set owner-token-count owner (- (get-balance owner) u1))

    (print {
      event: "burn",
      token-id: token-id,
      owner: owner
    })

    (ok true)
  )
)

;; Public functions
(define-public (approve (to principal) (token-id uint))
  (let ((owner (unwrap-panic (get-owner token-id))))
    (asserts! (or (is-eq tx-sender owner) (is-approved-for-all owner tx-sender)) ERR_NOT_TOKEN_OWNER)
    (map-set token-approvals token-id to)
    (print { event: "approve", owner: owner, approved: to, token-id: token-id })
    (ok true)
  )
)

(define-public (set-approval-for-all (operator principal) (approved bool))
  (map-set operator-approvals { owner: tx-sender, operator: operator } approved)
  (print { event: "approval-for-all", owner: tx-sender, operator: operator, approved: approved })
  (ok true)
)

(define-public (transfer-from (from principal) (to principal) (token-id uint))
  (let ((owner (unwrap-panic (get-owner token-id))))
    (asserts! (or (is-eq tx-sender owner) (is-approved-for-all owner tx-sender)) ERR_NOT_TOKEN_OWNER)
    (asserts! (is-eq owner from) ERR_UNAUTHORIZED)

    (map-set token-owners token-id to)
    (map-set owner-token-count from (- (get-balance from) u1))
    (map-set owner-token-count to (+ (get-balance to) u1))

    (print { event: "transfer", from: from, to: to, token-id: token-id })
    (ok true)
  )
)

(define-public (safe-transfer-from (from principal) (to principal) (token-id uint) (data (buff 256)))
  (try! (transfer-from from to token-id))
  (ok true)
)

;; Position-specific functions
(define-public (create-position
  (pool-contract principal)
  (tick-lower int)
  (tick-upper int)
  (liquidity uint)
)
  (mint-position-nft tx-sender pool-contract tick-lower tick-upper liquidity)
)

(define-public (update-position-liquidity
  (token-id uint)
  (new-liquidity uint)
)
  (let ((metadata (unwrap-panic (map-get? token-metadata token-id))))
    (map-set token-metadata token-id
      (merge metadata
        {
          properties: (merge (get properties metadata) { liquidity: new-liquidity }),
          attributes: (replace-in-list
            (get attributes metadata)
            { trait_type: "Liquidity", value: (to-ascii new-liquidity) }
            3
          )
        }
      )
    )

    (print {
      event: "update-liquidity",
      token-id: token-id,
      new-liquidity: new-liquidity
    })

    (ok true)
  )
)

(define-public (close-position (token-id uint))
  (try! (burn-position-nft token-id))
  (ok true)
)

;; Administrative functions
(define-public (set-max-supply (new-max-supply uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set max-supply new-max-supply)
    (ok true)
  )
)

(define-public (set-base-uri (new-base-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    ;; Update global base URI - would need to be implemented
    (ok true)
  )
)

;; Helper function for updating list elements
(define-private (replace-in-list (lst (list 20 (tuple (trait_type (string-ascii 64)) (value (string-ascii 256))))) (new-item (tuple (trait_type (string-ascii 64)) (value (string-ascii 256)))) (index uint))
  (if (is-eq index u0)
      (unwrap-panic (as-max-len? (append (list new-item) (unwrap-panic (as-max-len? (slice? lst u1 (len lst)) (list)))) (list)))
      (if (< index (len lst))
          (unwrap-panic (as-max-len?
            (concat
              (unwrap-panic (as-max-len? (slice? lst u0 index) (list)))
              (list new-item)
              (unwrap-panic (as-max-len? (slice? lst (+ index u1) (len lst)) (list)))
            )
            (list)
          ))
          lst
      )
  )
)
