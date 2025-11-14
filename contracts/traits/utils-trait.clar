;; ===========================================
;; UTILS TRAIT
;; ===========================================
;; @desc Interface for common utility functions.
;; This trait provides a collection of general-purpose utility functions
;; that can be used across various contracts.
;;
;; @example
;; (use-trait utils .utils-trait.utils-trait)
(define-trait utils-trait
  (
    ;; @desc Check if a principal is the contract owner.
    ;; @param p: The principal to check.
    ;; @returns (response bool uint): True if the principal is the contract owner, false otherwise.
    (is-contract-owner (principal) (response bool uint))

    ;; @desc Get the current block height.
    ;; @returns (response uint uint): The current block height.
    (get-block-height () (response uint uint))

    ;; @desc Convert a uint to a string.
    ;; @param u: The uint to convert.
    ;; @returns (response (string-ascii 20) uint): The string representation of the uint.
    (uint-to-string (uint) (response (string-ascii 20) uint))

    ;; @desc Convert a principal to a string.
    ;; @param p: The principal to convert.
    ;; @returns (response (string-ascii 41) uint): The string representation of the principal.
    (principal-to-string (principal) (response (string-ascii 41) uint))
  )
)
