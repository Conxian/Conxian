;; liquidity-provider.clar
;; Implements unified liquidity provisioning for the DEX integration layer.

;; SIP-010: Fungible Token Standard
(use-trait sip-010-ft-trait .dex-traits.sip-010-ft-trait)

;; Constants
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-ZERO-ADDRESS (err u1002))
(define-constant ERR-POOL-NOT-ACTIVE (err u1003))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u1004))

;; Data Maps
;; Stores pool configurations
;; { token-x: principal, token-y: principal, lp-token: principal, fee-bps: uint }
(define-map pool-configs { pool-id: uint } { token-x: principal, token-y: principal, lp-token: principal, fee-bps: uint })

;; Stores liquidity provider balances for LP tokens
(define-map lp-balances { pool-id: uint, owner: principal } uint)

;; Data Variables
;; Next available pool ID
(define-data-var next-pool-id uint u0)
;; Contract owner
(define-data-var contract-owner principal tx-sender)
;; Governance address
(define-data-var governance-address principal tx-sender)
;; Emergency multisig address
(define-data-var emergency-multisig principal tx-sender)

;; Events
(define-event pool-created
  (tuple
    (event (string-ascii 16))
    (pool-id uint)
    (token-x principal)
    (token-y principal)
    (lp-token principal)
    (fee-bps uint)
    (sender principal)
    (block-height uint)
  )
)

(define-event liquidity-added
  (tuple
    (event (string-ascii 16))
    (pool-id uint)
    (sender principal)
    (amount-x uint)
    (amount-y uint)
    (lp-tokens-minted uint)
    (block-height uint)
  )
)

(define-event liquidity-removed
  (tuple
    (event (string-ascii 16))
    (pool-id uint)
    (sender principal)
    (amount-x uint)
    (amount-y uint)
    (lp-tokens-burned uint)
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

;; @desc Checks if the caller is the emergency multisig.
;; @returns A response with ok if authorized, or an error.
(define-private (is-emergency-multisig)
  (ok (asserts! (is-eq tx-sender (var-get emergency-multisig)) ERR-NOT-AUTHORIZED))
)

;; Public Functions

;; @desc Creates a new liquidity pool.
;; @param token-x The principal of the first fungible token.
;; @param token-y The principal of the second fungible token.
;; @param lp-token The principal of the LP token for this pool.
;; @param fee-bps The fee in basis points (e.g., u100 for 1%).
;; @returns A response with the new pool ID on success, or an error.
(define-public (create-pool (token-x <sip-010-ft-trait>) (token-y <sip-010-ft-trait>) (lp-token <sip-010-ft-trait>) (fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq token-x token-y)) ERR-INVALID-AMOUNT) ;; Tokens must be different
    (asserts! (> fee-bps u0) ERR-INVALID-AMOUNT) ;; Fee must be greater than 0

    (let ((pool-id (var-get next-pool-id)))
      (map-set pool-configs { pool-id: pool-id } { token-x: (contract-of token-x), token-y: (contract-of token-y), lp-token: (contract-of lp-token), fee-bps: fee-bps })
      (var-set next-pool-id (+ pool-id u1))
      (print (merge-tuple (map-get? pool-configs { pool-id: pool-id }) { event: "pool-created", sender: tx-sender, block-height: (get-block-info? block-height) }))
      (ok pool-id)
    )
  )
)

;; @desc Adds liquidity to an existing pool.
;; @param pool-id The ID of the liquidity pool.
;; @param amount-x The amount of token-x to add.
;; @param amount-y The amount of token-y to add.
;; @returns A response with the amount of LP tokens minted on success, or an error.
(define-public (add-liquidity (pool-id uint) (amount-x uint) (amount-y uint))
  (begin
    (asserts! (and (> amount-x u0) (> amount-y u0)) ERR-INVALID-AMOUNT)
    (let
      ((pool-config (unwrap! (map-get? pool-configs { pool-id: pool-id }) ERR-POOL-NOT-ACTIVE)))
      (let
        ((token-x-contract (unwrap-panic (contract-of (as-contract (get token-x pool-config)))))
         (token-y-contract (unwrap-panic (contract-of (as-contract (get token-y pool-config)))))
         (lp-token-contract (unwrap-panic (contract-of (as-contract (get lp-token pool-config)))))
        )
        ;; Transfer tokens from sender to this contract
        (unwrap! (contract-call? token-x-contract transfer amount-x tx-sender (as-contract tx-sender)) ERR-INVALID-AMOUNT)
        (unwrap! (contract-call? token-y-contract transfer amount-y tx-sender (as-contract tx-sender)) ERR-INVALID-AMOUNT)

        ;; Calculate LP tokens to mint (simplified for now)
        ;; In a real scenario, this would involve complex math based on existing liquidity
        (let ((lp-tokens-minted (/ (+ amount-x amount-y) u2))) ;; Placeholder calculation
          (map-set lp-balances { pool-id: pool-id, owner: tx-sender } (+ (default-to u0 (map-get? lp-balances { pool-id: pool-id, owner: tx-sender })) lp-tokens-minted))
          (print (merge-tuple { event: "liquidity-added", pool-id: pool-id, sender: tx-sender, amount-x: amount-x, amount-y: amount-y, lp-tokens-minted: lp-tokens-minted, block-height: (get-block-info? block-height) }))
          (ok lp-tokens-minted)
        )
      )
    )
  )
)

;; @desc Removes liquidity from an existing pool.
;; @param pool-id The ID of the liquidity pool.
;; @param lp-tokens-burned The amount of LP tokens to burn.
;; @returns A response with the amounts of token-x and token-y returned on success, or an error.
(define-public (remove-liquidity (pool-id uint) (lp-tokens-burned uint))
  (begin
    (asserts! (> lp-tokens-burned u0) ERR-INVALID-AMOUNT)
    (let
      ((pool-config (unwrap! (map-get? pool-configs { pool-id: pool-id }) ERR-POOL-NOT-ACTIVE)))
      (let
        ((current-lp-balance (default-to u0 (map-get? lp-balances { pool-id: pool-id, owner: tx-sender }))))
        (asserts! (>= current-lp-balance lp-tokens-burned) ERR-INSUFFICIENT-LIQUIDITY)

        ;; Calculate tokens to return (simplified for now)
        ;; In a real scenario, this would involve complex math based on existing liquidity
        (let
          ((amount-x-returned (/ lp-tokens-burned u2)) ;; Placeholder calculation
           (amount-y-returned (/ lp-tokens-burned u2)) ;; Placeholder calculation
          )
          (map-set lp-balances { pool-id: pool-id, owner: tx-sender } (- current-lp-balance lp-tokens-burned))

          (let
            ((token-x-contract (unwrap-panic (contract-of (as-contract (get token-x pool-config)))))
             (token-y-contract (unwrap-panic (contract-of (as-contract (get token-y pool-config)))))
            )
            ;; Transfer tokens from this contract to sender
            (unwrap! (contract-call? token-x-contract transfer amount-x-returned (as-contract tx-sender) tx-sender) ERR-INVALID-AMOUNT)
            (unwrap! (contract-call? token-y-contract transfer amount-y-returned (as-contract tx-sender) tx-sender) ERR-INVALID-AMOUNT)

            (print (merge-tuple { event: "liquidity-removed", pool-id: pool-id, sender: tx-sender, amount-x: amount-x-returned, amount-y: amount-y-returned, lp-tokens-burned: lp-tokens-burned, block-height: (get-block-info? block-height) }))
            (ok (tuple (amount-x amount-x-returned) (amount-y amount-y-returned)))
          )
        )
      )
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

;; @desc Sets the emergency multisig address.
;; @param new-multisig The principal of the new emergency multisig address.
;; @returns A response with ok on success, or an error.
(define-public (set-emergency-multisig (new-multisig principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set emergency-multisig new-multisig)
    (ok true)
  )
)

;; Read-only Functions

;; @desc Gets the pool configuration for a given pool ID.
;; @param pool-id The ID of the liquidity pool.
;; @returns An optional tuple containing the pool configuration.
(define-read-only (get-pool-config (pool-id uint))
  (map-get? pool-configs { pool-id: pool-id })
)

;; @desc Gets the LP token balance for a given owner and pool ID.
;; @param pool-id The ID of the liquidity pool.
;; @param owner The principal of the liquidity provider.
;; @returns The LP token balance.
(define-read-only (get-lp-balance (pool-id uint) (owner principal))
  (default-to u0 (map-get? lp-balances { pool-id: pool-id, owner: owner }))
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

;; @desc Gets the current emergency multisig address.
;; @returns The principal of the emergency multisig address.
(define-read-only (get-emergency-multisig)
  (ok (var-get emergency-multisig))
)
