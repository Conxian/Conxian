;; @contract Conxian Voting Token (CXVG)
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc This contract implements the Conxian Voting Token (CXVG), a SIP-010 compliant fungible token.
;; CXVG is used for governance voting within the Conxian ecosystem, allowing token holders to
;; participate in protocol decisions.

;; --- Traits ---
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

;; --- Constants ---

;; @var ERR-NOT-AUTHORIZED The caller is not authorized to perform the action.
(define-constant ERR-NOT-AUTHORIZED u1001)
;; @var ERR-INVALID-AMOUNT The provided amount is invalid.
(define-constant ERR-INVALID-AMOUNT u8001)

;; --- Data Variables and Maps ---

;; @var token-name The name of the token.
(define-data-var token-name (string-ascii 32) "Conxian Voting Token")
;; @var token-symbol The symbol of the token.
(define-data-var token-symbol (string-ascii 10) "CXVG")
;; @var token-decimals The number of decimals for the token.
(define-data-var token-decimals uint u6)
;; @var token-uri The URI for the token's metadata.
(define-data-var token-uri (optional (string-utf8 256)) none)
;; @var contract-owner The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)

(define-fungible-token cxvg-token)

;; --- SIP-010 Interface ---

;; @desc Get the name of the token.
;; @returns The name of the token.
(define-read-only (get-name)
  (ok (var-get token-name))
)

;; @desc Get the symbol of the token.
;; @returns The symbol of the token.
(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

;; @desc Get the number of decimals for the token.
;; @returns The number of decimals for the token.
(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

;; @desc Get the total supply of the token.
;; @returns The total supply of the token.
(define-read-only (get-total-supply)
  (ok (ft-get-supply cxvg-token))
)

;; @desc Get the token URI.
;; @returns The token URI.
(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; @desc Get the balance of a principal.
;; @param owner The principal to check the balance of.
;; @returns The balance of the principal.
(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance cxvg-token owner))
)

;; @desc Transfer tokens from one principal to another.
;; @param amount The amount of tokens to transfer.
;; @param sender The sender of the tokens.
;; @param recipient The recipient of the tokens.
;; @param memo An optional memo for the transfer.
;; @returns A response indicating success or failure.
(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (ft-transfer? cxvg-token amount sender recipient)
  )
)

;; --- Mint/Burn Functions ---

;; @desc Mint new tokens.
;; @param amount The amount of tokens to mint.
;; @param recipient The recipient of the new tokens.
;; @returns A response indicating success or failure.
(define-public (mint
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ft-mint? cxvg-token amount recipient)
  )
)

;; @desc Burn tokens.
;; @param amount The amount of tokens to burn.
;; @param sender The sender of the tokens to burn.
;; @returns A response indicating success or failure.
(define-public (burn
    (amount uint)
    (sender principal)
  )
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (ft-burn? cxvg-token amount sender)
  )
)

;; --- Admin Functions ---

;; @desc Set the token URI.
;; @param new-uri The new token URI.
;; @returns A response indicating success or failure.
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set token-uri new-uri)
    (ok true)
  )
)

;; @desc Transfer contract ownership.
;; @param new-owner The address of the new owner.
;; @returns A response indicating success or failure.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Get the contract owner.
;; @returns The principal of the contract owner.
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)
