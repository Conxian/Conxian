;; SIP-010: Fungible Token Standard
;; Defines a standard interface for fungible tokens.

(define-trait sip-010-trait-ft-standard
  (
    ;; @desc Returns the total supply of the fungible token.
    ;; @returns A uint representing the total supply.
    (get-total-supply () (response uint uint))

    ;; @desc Returns the balance of the given principal.
    ;; @param owner The principal whose balance is to be returned.
    ;; @returns A uint representing the balance of the owner.
    (get-balance (owner principal) (response uint uint))

    ;; @desc Transfers tokens from the sender to a recipient.
    ;; @param amount The amount of tokens to transfer.
    ;; @param sender The principal sending the tokens.
    ;; @param recipient The principal receiving the tokens.
    ;; @param memo An optional memo to include with the transfer.
    ;; @returns A response indicating success or failure.
    (transfer (amount uint sender principal recipient principal (optional (buffer 34))) (response bool uint))

    ;; @desc Returns the name of the fungible token.
    ;; @returns A (response (string-ascii 32) uint) representing the token name.
    (get-name () (response (string-ascii 32) uint))

    ;; @desc Returns the symbol of the fungible token.
    ;; @returns A (response (string-ascii 12) uint) representing the token symbol.
    (get-symbol () (response (string-ascii 12) uint))

    ;; @desc Returns the number of decimals used to represent token quantities.
    ;; @returns A (response uint uint) representing the number of decimals.
    (get-decimals () (response uint uint))

    ;; @desc Returns the URI for the token metadata.
    ;; @returns A (response (optional (string-utf8 256)) uint) representing the token URI.
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
