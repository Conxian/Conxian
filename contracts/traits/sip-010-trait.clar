;; ===========================================
;; SIP-010 TRAIT
;; ===========================================
;; @desc Standard interface for fungible tokens (SIP-010).
;; This trait defines the basic functions for managing fungible tokens,
;; including transfers, balance queries, and metadata retrieval.
;;
;; @example
;; (use-trait ft-standard .sip-010-trait)
(define-trait sip-010-trait
  (
    ;; @desc Transfer tokens from one principal to another.
    ;; @param amount: The amount of tokens to transfer.
    ;; @param sender: The principal sending the tokens.
    ;; @param recipient: The principal receiving the tokens.
    ;; @param memo: An optional memo for the transaction.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; @desc Get the name of the token.
    ;; @returns (response (string-ascii 32) uint): The name of the token, or an error code.
    (get-name () (response (string-ascii 32) uint))

    ;; @desc Get the symbol of the token.
    ;; @returns (response (string-ascii 10) uint): The symbol of the token, or an error code.
    (get-symbol () (response (string-ascii 10) uint))

    ;; @desc Get the number of decimals for the token.
    ;; @returns (response uint uint): The number of decimals for the token, or an error code.
    (get-decimals () (response uint uint))

    ;; @desc Get the balance of a principal.
    ;; @param owner: The principal to query the balance for.
    ;; @returns (response uint uint): The balance of the principal, or an error code.
    (get-balance (principal) (response uint uint))

    ;; @desc Get the total supply of the token.
    ;; @returns (response uint uint): The total supply of the token, or an error code.
    (get-total-supply () (response uint uint))
  )
)
