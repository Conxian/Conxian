;; ===========================================
;; SIP-010 FT MINTABLE TRAIT
;; ===========================================
;; @desc Interface for a mintable SIP-010 Fungible Token.
;; This trait extends the SIP-010 standard with minting and burning capabilities.
;;
;; @example
;; (use-trait ft-mintable .sip-010-ft-mintable-trait)
(define-trait sip-010-ft-mintable-trait
  (
    ;; @desc Mint new tokens to a recipient.
    ;; @param recipient: The principal to mint tokens to.
    ;; @param amount: The amount of tokens to mint.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (mint (principal uint) (response bool uint))

    ;; @desc Burn tokens from a sender.
    ;; @param sender: The principal to burn tokens from.
    ;; @param amount: The amount of tokens to burn.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (burn (principal uint) (response bool uint))
  )
)
