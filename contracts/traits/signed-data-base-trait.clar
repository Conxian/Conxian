;; ===========================================
;; SIGNED DATA BASE TRAIT
;; ===========================================
;; Interface for handling signed data
;;
;; This trait provides functions for verifying signatures and recovering
;; signers from signed messages, crucial for off-chain data integrity.
;;
;; Example usage:
;;   (use-trait signed-data-base .signed-data-base-trait.signed-data-base-trait)
(define-trait signed-data-base-trait
  (
    ;; Verify a signature against a message and a public key
    ;; @param message: message hash (buff 32)
    ;; @param signature: signature (buff 65)
    ;; @param public-key: public key (buff 33)
    ;; @return (response bool uint): true if signature is valid, false otherwise
    (verify-signature ((buff 32) (buff 65) (buff 33)) (response bool uint))

    ;; Recover the signer's principal from a signed message
    ;; @param message: message hash (buff 32)
    ;; @param signature: signature (buff 65)
    ;; @return (response principal uint): principal of the signer
    (recover-signer ((buff 32) (buff 65)) (response principal uint))
  )
)
