;; @desc SIP-009 compliant NFT contract for audit badges.
;; This contract is used to mint and manage non-fungible tokens that represent
;; proof of a successful smart contract audit.

(define-non-fungible-token audit-badge-nft uint)

;; @constants
;; @var CONTRACT_OWNER: The principal of the contract owner.
(define-constant CONTRACT_OWNER tx-sender)
;; @var ERR_UNAUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_UNAUTHORIZED (err u1001))
;; @var ERR_NONEXISTENT_TOKEN: The specified token does not exist.
(define-constant ERR_NONEXISTENT_TOKEN (err u3006))
;; @var ERR_ALREADY_CLAIMED: The audit has already been claimed.
(define-constant ERR_ALREADY_CLAIMED (err u1006))

;; @data-vars
;; @var next-token-id: The ID of the next token to be minted.
(define-data-var next-token-id uint u1)
;; @var base-token-uri: The base URI for the token metadata.
(define-data-var base-token-uri (optional (string-utf8 256)) none)
;; @var tokens: A map of token IDs to their metadata.
(define-map tokens
  uint
  {
    audit-id: uint,
    metadata: (string-utf8 256),
  }
)
;; @var audit-to-token: A map of audit IDs to their corresponding token IDs.
(define-map audit-to-token
  uint
  { token-id: uint }
)

;; --- Private Helper Functions ---
;; @desc Checks if the caller is the contract owner.
;; @returns (response bool uint): An `ok` response with `true` if the caller is the owner, or an error code.
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED))
)

;; --- SIP-009 Required Functions ---
;; @desc Get the ID of the last token minted.
;; @returns (response uint uint): The ID of the last token minted.
(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1))
)

;; @desc Get the owner of a token.
;; @param token-id: The ID of the token.
;; @returns (response (optional principal) uint): The owner of the token, or none if the token does not exist.
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? audit-badge-nft token-id))
)

;; @desc Get the URI for a token's metadata.
;; @param token-id: The ID of the token.
;; @returns (response (optional (string-utf8 256)) uint): The URI for the token's metadata, or none if not set.
(define-read-only (get-token-uri (token-id uint))
  (match (map-get? tokens token-id)
    token (match (var-get base-token-uri)
      base-uri (ok (some base-uri))
      (ok none)
    )
    (ok none)
  )
)

;; @desc Get the raw metadata for a token.
;; @param token-id: The ID of the token.
;; @returns (response (optional (string-utf8 256)) uint): The raw metadata for the token, or none if not set.
(define-read-only (get-token-uri-raw (token-id uint))
  (match (map-get? tokens token-id)
    token (ok (some (get metadata token)))
    (ok none)
  )
)

;; @desc Transfer a token to a new owner.
;; @param token-id: The ID of the token to transfer.
;; @param sender: The principal of the current owner.
;; @param recipient: The principal of the new owner.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (transfer
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (try! (nft-transfer? audit-badge-nft token-id sender recipient))
    (ok true)
  )
)

;; --- Custom Functions ---
;; @desc Mint a new audit badge NFT.
;; @param audit-id: The ID of the audit.
;; @param metadata: The metadata for the token.
;; @param recipient: The principal to receive the new token.
;; @returns (response uint uint): The ID of the newly minted token, or an error code.
(define-public (mint
    (audit-id uint)
    (metadata (string-utf8 256))
    (recipient principal)
  )
  (let ((token-id (var-get next-token-id)))
    (asserts! (is-eq tx-sender .audit-registry) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? audit-to-token audit-id)) ERR_ALREADY_CLAIMED)

    (try! (nft-mint? audit-badge-nft token-id recipient))

    (map-set tokens token-id {
      audit-id: audit-id,
      metadata: metadata,
    })

    (map-set audit-to-token audit-id { token-id: token-id })

    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

;; @desc Get the token ID for a given audit ID.
;; @param audit-id: The ID of the audit.
;; @returns (response (optional uint) uint): The token ID, or none if not found.
(define-read-only (get-token-by-audit (audit-id uint))
  (match (map-get? audit-to-token audit-id)
    entry (ok (some (get token-id entry)))
    (ok none)
  )
)

;; @desc Get the audit ID for a given token ID.
;; @param token-id: The ID of the token.
;; @returns (response (optional uint) uint): The audit ID, or none if not found.
(define-read-only (get-audit-by-token (token-id uint))
  (match (map-get? tokens token-id)
    token (ok (some (get audit-id token)))
    (ok none)
  )
)

;; --- Admin Functions ---
;; @desc Set the base URI for the token metadata.
;; @param uri: The new base URI.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-base-token-uri (uri (string-utf8 256)))
  (begin
    (try! (check-is-owner))
    (var-set base-token-uri (some uri))
    (ok true)
  )
)

;; @desc Update the metadata for a token.
;; @param token-id: The ID of the token.
;; @param new-metadata: The new metadata.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (update-metadata
    (token-id uint)
    (new-metadata (string-utf8 256))
  )
  (let ((token (unwrap! (map-get? tokens token-id) ERR_NONEXISTENT_TOKEN)))
    (try! (check-is-owner))
    (map-set tokens token-id (merge token { metadata: new-metadata }))
    (ok true)
  )
)
