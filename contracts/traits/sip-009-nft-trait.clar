;; ===========================================
;; SIP-009 NFT TRAIT
;; ===========================================
;; Trait for SIP-009 Non-Fungible Token Standard.
;;
;; This trait defines the standard interface for non-fungible tokens, allowing for interoperability
;; between different NFT contracts.
;;
;; Example usage:
;;   (use-trait nft-trait .sip-009-nft-trait.sip-009-nft-trait)
(define-trait sip-009-nft-trait
  (
    ;; @desc Transfers an NFT from the sender to a recipient.
    ;; @param token-id The unique identifier of the NFT.
    ;; @param sender The principal sending the NFT.
    ;; @param recipient The principal receiving the NFT.
    ;; @returns (response bool uint) True if successful, or an error.
    (transfer (token-id uint) (sender principal) (recipient principal)) (response bool uint))

    ;; @desc Returns the last token ID that has been minted.
    ;; @returns (response uint uint) The last token ID.
    (get-last-token-id () (response uint uint))

    ;; @desc Returns the metadata URI for a token.
    ;; @param token-id The ID of the token.
    ;; @returns (response (optional (string-utf8 256)) uint) The URI if found, or none.
    (get-token-uri (token-id uint)) (response (optional (string-utf8 256)) uint))

    ;; @desc Returns the owner of a token.
    ;; @param token-id The ID of the token.
    ;; @returns (response (optional principal) uint) The owner principal if found, or none.
    (get-owner (token-id uint)) (response (optional principal) uint))
  )
)
