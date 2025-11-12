;; ===========================================
;; UTILS TRAIT
;; ===========================================
;; Interface for common utility functions
;;
;; This trait provides a collection of general-purpose utility functions
;; that can be used across various contracts.
;;
;; Example usage:
;;   (use-trait utils .utils-trait.utils-trait)
(define-trait utils-trait
  (
    ;; Check if a principal is a contract owner
    ;; @param p: principal to check
    ;; @return (response bool uint): true if owner, false otherwise
    (is-contract-owner (principal) (response bool uint))

    ;; Get the current block height
    ;; @return (response uint uint): current block height
    (get-block-height () (response uint uint))

    ;; Convert a uint to a string
    ;; @param u: uint to convert
    ;; @return (response (string-ascii 20) uint): string representation
    (uint-to-string (uint) (response (string-ascii 20) uint))

    ;; Convert a principal to a string
    ;; @param p: principal to convert
    ;; @return (response (string-ascii 41) uint): string representation
    (principal-to-string (principal) (response (string-ascii 41) uint))
  )
)
