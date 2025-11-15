;; ===========================================
;; SIGNED DATA BASE TRAIT
;; ===========================================
;; @desc Interface for handling signed data.
;; This trait provides functions for verifying signatures and recovering
;; signers from signed messages, crucial for off-chain data integrity.
;;
;; @example
;; (use-trait signed-data-base .signed-data-base-trait.signed-data-base-trait)
(define-trait signed-data-base-trait
  (
    ;; @desc Verify a signature against a message and a public key.
    ;; @param message: The hash of the message (buff 32).
    ;; @param signature: The signature (buff 65).
    ;; @param public-key: The public key (buff 33).
    ;; @returns (response bool uint): True if the signature is valid, false otherwise.
    (verify-signature ((buff 32) (buff 65) (buff 33)) (response bool uint))

    ;; @desc Recover the signer's principal from a signed message.
    ;; @param message: The hash of the message (buff 32).
    ;; @param signature: The signature (buff 65).
    ;; @returns (response principal uint): The principal of the signer.
    (recover-signer ((buff 32) (buff 65)) (response principal uint))
  )
)
