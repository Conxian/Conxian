;; ===========================================
;; ERROR CODES TRAIT
;; ===========================================
;; Interface for standardized error codes
;;
;; This trait defines a set of common error codes used across the protocol
;; to ensure consistent error handling and reporting.
;;
;; Example usage:
;;   (use-trait err-codes .error-codes-trait.error-codes-trait)
(define-trait error-codes-trait
  (
    ;; Get error message for a given code
    ;; @param code: error code
    ;; @return (response (string-ascii 100) uint): error message and error code
    (get-error-message (uint) (response (string-ascii 100) uint))

    ;; Check if an error code is critical
    ;; @param code: error code
    ;; @return (response bool uint): true if critical, false otherwise, and error code
    (is-critical-error (uint) (response bool uint))
  )
)
