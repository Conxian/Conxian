;; ===========================================
;; SIP-010 TRAIT
;; ===========================================
;; Standard interface for fungible tokens (SIP-010).
;;
;; This trait defines the basic functions for managing fungible tokens,
;; including transfers, balance queries, and metadata retrieval.
;;
;; Example usage:
;;   (use-trait ft-standard .sip-010-trait)
(define-trait sip-010-trait
  (
    ;; Transfer tokens from one principal to another.
    ;; @param amount: amount of tokens to transfer
    ;; @param sender: principal sending the tokens
    ;; @param recipient: principal receiving the tokens
    ;; @param memo: optional memo for the transaction
    ;; @return (response bool uint): success flag and error code
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get the name of the token.
    ;; @return (response (string-ascii 32) uint): token name and error code
    (get-name () (response (string-ascii 32) uint))

    ;; Get the symbol of the token.
    ;; @return (response (string-ascii 10) uint): token symbol and error code
    (get-symbol () (response (string-ascii 10) uint))

    ;; Get the number of decimals for the token.
    ;; @return (response uint uint): number of decimals and error code
    (get-decimals () (response uint uint))

    ;; Get the balance of a principal.
    ;; @param owner: principal to query balance for
    ;; @return (response uint uint): balance and error code
    (get-balance (principal) (response uint uint))

    ;; Get the total supply of the token.
    ;; @return (response uint uint): total supply and error code
    (get-total-supply () (response uint uint))
  )
)
