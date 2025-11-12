;; ===========================================
;; SIP-010 FT MINTABLE TRAIT
;; ===========================================
;; Interface for a mintable SIP-010 Fungible Token.
;;
;; This trait extends the SIP-010 standard with minting and burning capabilities.
;;
;; Example usage:
;;   (use-trait ft-mintable .sip-010-ft-mintable-trait)
(define-trait sip-010-ft-mintable-trait
  (
    ;; Mint new tokens to a recipient.
    ;; @param recipient: principal to mint tokens to
    ;; @param amount: amount of tokens to mint
    ;; @return (response bool uint): success flag and error code
    (mint (principal uint) (response bool uint))

    ;; Burn tokens from a sender.
    ;; @param sender: principal to burn tokens from
    ;; @param amount: amount of tokens to burn
    ;; @return (response bool uint): success flag and error code
    (burn (principal uint) (response bool uint))
  )
)
