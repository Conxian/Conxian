;; SIP-011: Non-Fungible Token Standard
;; Defines a standard interface for non-fungible tokens.

(define-trait sip-011-trait-nft-standard
  (
    ;; @desc Returns the last token ID.
    ;; @returns A uint representing the last token ID.
    (get-last-token-id () (response uint uint))

    ;; @desc Returns the owner of the given token ID.
    ;; @param token-id The ID of the token.
    ;; @returns A (response (optional principal) uint) representing the owner of the token.
    (get-owner (token-id uint) (response (optional principal) uint))

    ;; @desc Transfers a token from the sender to a recipient.
    ;; @param token-id The ID of the token to transfer.
    ;; @param sender The principal sending the token.
    ;; @param recipient The principal receiving the token.
    ;; @returns A response indicating success or failure.
    (transfer (token-id uint sender principal recipient principal) (response bool uint))

    ;; @desc Returns the token URI for the given token ID.
    ;; @param token-id The ID of the token.
    ;; @returns A (response (optional (string-utf8 256)) uint) representing the token URI.
    (get-token-uri (token-id uint) (response (optional (string-utf8 256)) uint))
  )
)
