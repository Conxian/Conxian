;; sip-018-trait.clar
;; SIP-018 Signed Structured Data Trait
;; Provides standard interface for message signing and verification in Clarity

(define-trait sip-018-trait
  (
    ;; Verify a signed message
    ;; @param message: The original message that was signed
    ;; @param signature: The signature to verify
    ;; @param signer: The expected signer's principal
    ;; @returns: (ok true) if valid, (err u...) if invalid
    (verify-signature 
        (message (buff 1024))
        (signature (buff 65))
        (signer principal)
    ) (response bool uint)

    ;; Get the domain separator for this contract
    ;; Used to prevent signature replay across different contracts
    ;; @returns: The domain separator as a buffer
    (get-domain-separator) (response (buff 32) uint)

    ;; Get the structured data version
    ;; @returns: The version string
    (get-structured-data-version) (response (string-ascii 32) uint)

    ;; Verify a typed structured data signature
    ;; @param structured-data: The typed structured data that was signed
    ;; @param signature: The signature to verify
    ;; @param signer: The expected signer's principal
    ;; @returns: (ok true) if valid, (err u...) if invalid
    (verify-structured-data
        (structured-data (buff 1024))
        (signature (buff 65))
        (signer principal)
    ) (response bool uint)
  )
)