;; signed-data-base.clar
;; Base implementation of SIP-018 Signed Structured Data standard
;; Provides reusable functionality for contracts needing signature verification

;; Centralized traits
(use-trait sip-018-trait .all-traits.sip-018-trait)
(impl-trait .all-traits.sip-018-trait)

;; Constants
(define-constant ERR_INVALID_SIGNATURE (err u6300))
(define-constant ERR_INVALID_SIGNER (err u6301))
(define-constant ERR_EXPIRED_SIGNATURE (err u6302))
(define-constant ERR_SIGNATURE_USED (err u6303))
(define-constant ERR_INVALID_STRUCTURED_DATA (err u6304))

;; Version constant
(define-constant STRUCTURED_DATA_VERSION "1")

;; Storage
(define-data-var admin principal tx-sender)
(define-data-var domain-separator (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)
(define-map used-signatures { signature: (buff 65) } { used: bool })

;; --- Domain Separator ---

(define-read-only (get-domain-separator)
    (ok (var-get domain-separator)))

(define-read-only (get-structured-data-version)
    (ok STRUCTURED_DATA_VERSION))

;; --- Signature Verification ---

(define-read-only (verify-signature (message (buff 1024)) (signature (buff 65)) (signer principal))
    (let 
        (
            (is-used (default-to { used: false } (map-get? used-signatures { signature: signature })))
        )
        (asserts! (not (get used is-used)) ERR_SIGNATURE_USED)
        
        ;; In production implementation:
        ;; 1. Verify the signature cryptographically
        ;; 2. Recover the signer address
        ;; 3. Compare with expected signer
        ;; For this example, we'll use a simplified check
        
        (map-set used-signatures { signature: signature } { used: true })
        (ok true)
    ))

(define-read-only (verify-structured-data (structured-data (buff 1024)) (signature (buff 65)) (signer principal))
    (begin
        ;; 1. Verify the structured data format
        (try! (validate-structured-data structured-data))
        
        ;; 2. Hash the structured data with domain separator
        (let 
            (
                (message (hash-structured-data structured-data))
            )
            ;; 3. Verify the signature
            (verify-signature message signature signer)
        )))

;; --- Private Helper Functions ---

(define-private (validate-structured-data (data (buff 1024)))
    ;; Validate the structured data format
    ;; In production: Implement proper EIP-712 style validation
    (ok true))

(define-private (hash-structured-data (data (buff 1024)))
    ;; Hash structured data following EIP-712 format
    ;; In production: Implement proper EIP-712 hashing
    data)

;; --- Admin Functions ---

(define-public (initialize-domain-separator (new-separator (buff 32)))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR_INVALID_SIGNER)
        (var-set domain-separator new-separator)
        (ok true)))

