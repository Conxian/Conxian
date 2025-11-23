;; ===========================================
;; FT MINTABLE TRAIT
;; ===========================================
;; @desc Extension trait for fungible tokens that can be minted and burned.
;; This trait should be implemented alongside sip-010-ft-trait for tokens
;; that require the ability to create and destroy tokens programmatically.
;;
;; @example
;; (use-trait mintable-trait .ft-mintable-trait.ft-mintable-trait)
(define-trait ft-mintable-trait
  (
    ;; @desc Mints new tokens and assigns them to a principal.
    ;; @param recipient: The principal to receive the minted tokens.
    ;; @param amount: The number of tokens to mint.
    ;; @returns (response bool uint): True if successful, otherwise an error.
    (mint (recipient principal) (amount uint)) (response bool uint)

    ;; @desc Burns tokens from a principal's balance.
    ;; @param owner: The principal whose tokens will be burned.
    ;; @param amount: The number of tokens to burn.
    ;; @returns (response bool uint): True if successful, otherwise an error.
    (burn (owner principal) (amount uint)) (response bool uint)
  )
)
