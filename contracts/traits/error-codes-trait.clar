;; ===========================================
;; ERROR CODES TRAIT
;; ===========================================
;; @desc Interface for standardized error codes.
;; This trait defines a set of common error codes used across the protocol
;; to ensure consistent error handling and reporting.
;;
;; @example
;; (use-trait err-codes .error-codes-trait.error-codes-trait)
(define-trait error-codes-trait
  (
    ;; @desc Get the error message for a given code.
    ;; @param code: The error code.
    ;; @returns (response (string-ascii 100) uint): The error message, or an error code.
    (get-error-message (uint) (response (string-ascii 100) uint))

    ;; @desc Check if an error code is critical.
    ;; @param code: The error code.
    ;; @returns (response bool uint): True if the error is critical, false otherwise, or an error code.
    (is-critical-error (uint) (response bool uint))
  )
)
