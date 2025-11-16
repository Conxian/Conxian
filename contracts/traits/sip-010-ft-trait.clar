;; ===========================================
;; SIP-010 FT TRAIT
;; ===========================================
;; @desc Trait for SIP-010 Fungible Token Standard.
;; This trait defines the standard interface for fungible tokens, allowing for interoperability
;; between different token contracts.
;;
;; @example
;; (use-trait ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(define-trait sip-010-ft-trait
  (
    ;; @desc Returns the total supply of the fungible token.
    ;; @returns (response uint uint): The total supply of the token.
    (get-total-supply () (response uint uint))

    ;; @desc Returns the balance of a principal.
    ;; @param owner: The principal to query the balance for.
    ;; @returns (response uint uint): The balance of the principal.
    (get-balance (principal) (response uint uint))

    ;; @desc Transfers tokens from the sender to a recipient.
    ;; @param amount: The amount of tokens to transfer.
    ;; @param sender: The principal sending the tokens.
    ;; @param recipient: The principal receiving the tokens.
    ;; @param memo: An optional memo to include with the transfer.
    ;; @returns (response bool uint): True if successful, otherwise an error.
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
  )
)
