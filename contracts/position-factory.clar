;; position-factory.clar
;; Factory contract for creating and managing position NFTs.

;; SIP-010: Fungible Token Standard
(use-trait ft-trait .requirements.sip-010-trait-ft-standard.ft-trait)
;; SIP-011: Non-Fungible Token Standard
(use-trait nft-trait .requirements.sip-011-trait-nft-standard.nft-trait)

;; Constants
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u3000))
(define-constant ERR-INVALID-INPUT (err u3001))
(define-constant ERR-POSITION-NOT-FOUND (err u3002))

;; Data Maps
;; Stores metadata for each position NFT
;; { position-id: uint } { owner: principal, collateral-token: principal, collateral-amount: uint, debt-token: principal, debt-amount: uint, created-at: uint }
(define-map position-metadata { position-id: uint } { owner: principal, collateral-token: principal, collateral-amount: uint, debt-token: principal, debt-amount: uint, created-at: uint })

;; Data Variables
;; Next available position ID
(define-data-var next-position-id uint u0)
;; Contract owner
(define-data-var contract-owner principal tx-sender)
;; Governance address
(define-data-var governance-address principal tx-sender)

;; Events
(define-event position-created
  (tuple
    (event (string-ascii 16))
    (position-id uint)
    (owner principal)
    (collateral-token principal)
    (collateral-amount uint)
    (debt-token principal)
    (debt-amount uint)
    (sender principal)
    (block-height uint)
  )
)

;; Private Helper Functions

;; @desc Checks if the caller is the contract owner.
;; @returns A response with ok if authorized, or an error.
(define-private (is-contract-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED))
)

;; @desc Checks if the caller is the governance address.
;; @returns A response with ok if authorized, or an error.
(define-private (is-governance)
  (ok (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED))
)

;; Public Functions

;; @desc Creates a new position NFT.
;; @param collateral-token The principal of the collateral fungible token.
;; @param collateral-amount The amount of collateral provided.
;; @param debt-token The principal of the debt fungible token.
;; @param debt-amount The amount of debt incurred.
;; @returns A response with the new position ID on success, or an error.
(define-public (create-position (collateral-token <ft-trait>) (collateral-amount uint) (debt-token <ft-trait>) (debt-amount uint))
  (begin
    (asserts! (> collateral-amount u0) ERR-INVALID-INPUT)
    (asserts! (> debt-amount u0) ERR-INVALID-INPUT)

    (let ((position-id (var-get next-position-id)))
      ;; Mint the NFT (assuming a separate NFT contract handles the actual minting)
      ;; For now, we'll just increment the position ID and store metadata.
      (map-set position-metadata
        { position-id: position-id }
        { owner: tx-sender
          , collateral-token: (contract-of collateral-token)
          , collateral-amount: collateral-amount
          , debt-token: (contract-of debt-token)
          , debt-amount: debt-amount
          , created-at: (get-block-info? block-height)
        }
      )
      (var-set next-position-id (+ position-id u1))
      (print (merge-tuple (map-get? position-metadata { position-id: position-id }) { event: "position-created", sender: tx-sender, block-height: (get-block-info? block-height) }))
      (ok position-id)
    )
  )
)

;; @desc Sets the contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns A response with ok on success, or an error.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Sets the governance address.
;; @param new-governance The principal of the new governance address.
;; @returns A response with ok on success, or an error.
(define-public (set-governance-address (new-governance principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set governance-address new-governance)
    (ok true)
  )
)

;; Read-only Functions

;; @desc Gets the metadata for a given position ID.
;; @param position-id The ID of the position NFT.
;; @returns An optional tuple containing the position metadata.
(define-read-only (get-position-metadata (position-id uint))
  (map-get? position-metadata { position-id: position-id })
)

;; @desc Gets the current contract owner.
;; @returns The principal of the contract owner.
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; @desc Gets the current governance address.
;; @returns The principal of the governance address.
(define-read-only (get-governance-address)
  (ok (var-get governance-address))
)