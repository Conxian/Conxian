;; insurance-fund.clar
;; Manages an insurance fund for covering potential losses within the dimensional system.

;; SIP-010: Fungible Token Standard
(use-trait ft-trait .all-traits.sip-010-ft-trait)

;; Constants
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u4000))
(define-constant ERR-INVALID-AMOUNT (err u4001))
(define-constant ERR-INSUFFICIENT-FUNDS (err u4002))
(define-constant ERR-FUND-NOT-ACTIVE (err u4003))

;; Data Maps
;; Stores the balance of each token in the insurance fund
(define-map fund-balances { token: principal } uint)

;; Data Variables
;; Contract owner
(define-data-var contract-owner principal tx-sender)
;; Governance address
(define-data-var governance-address principal tx-sender)
;; Emergency multisig address
(define-data-var emergency-multisig principal tx-sender)

;; Events
(define-event fund-deposited
  (tuple
    (event (string-ascii 16))
    (token principal)
    (amount uint)
    (sender principal)
    (block-height uint)
  )
)

(define-event fund-withdrawn
  (tuple
    (event (string-ascii 16))
    (token principal)
    (amount uint)
    (recipient principal)
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

;; @desc Checks if the caller is the emergency multisig.
;; @returns A response with ok if authorized, or an error.
(define-private (is-emergency-multisig)
  (ok (asserts! (is-eq tx-sender (var-get emergency-multisig)) ERR-NOT-AUTHORIZED))
)

;; Public Functions

;; @desc Deposits tokens into the insurance fund.
;; @param token The principal of the fungible token to deposit.
;; @param amount The amount of tokens to deposit.
;; @returns A response with ok on success, or an error.
(define-public (deposit-fund (token <ft-trait>) (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let
      ((current-balance (default-to u0 (map-get? fund-balances { token: (contract-of token) }))))
      (unwrap! (contract-call? token transfer amount tx-sender (as-contract tx-sender)) ERR-INVALID-AMOUNT)
      (map-set fund-balances { token: (contract-of token) } (+ current-balance amount))
      (print (merge-tuple { event: "fund-deposited", token: (contract-of token), amount: amount, sender: tx-sender, block-height: (get-block-info? block-height) }))
      (ok true)
    )
  )
)

;; @desc Withdraws tokens from the insurance fund (only callable by governance or emergency multisig).
;; @param token The principal of the fungible token to withdraw.
;; @param amount The amount of tokens to withdraw.
;; @param recipient The principal of the recipient.
;; @returns A response with ok on success, or an error.
(define-public (withdraw-fund (token <ft-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (or (is-governance) (is-emergency-multisig)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (let
      ((current-balance (default-to u0 (map-get? fund-balances { token: (contract-of token) }))))
      (asserts! (>= current-balance amount) ERR-INSUFFICIENT-FUNDS)
      (unwrap! (contract-call? token transfer amount (as-contract tx-sender) recipient) ERR-INVALID-AMOUNT)
      (map-set fund-balances { token: (contract-of token) } (- current-balance amount))
      (print (merge-tuple { event: "fund-withdrawn", token: (contract-of token), amount: amount, recipient: recipient, sender: tx-sender, block-height: (get-block-info? block-height) }))
      (ok true)
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

;; @desc Gets the balance of a specific token in the insurance fund.
;; @param token The principal of the fungible token.
;; @returns The balance of the token in the fund.
(define-read-only (get-fund-balance (token principal))
  (default-to u0 (map-get? fund-balances { token: token }))
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