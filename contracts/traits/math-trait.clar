;; ===========================================
;; MATH TRAIT
;; ===========================================
;; Interface for common mathematical operations
;;
;; This trait provides basic mathematical functions that can be used
;; across various contracts for consistent calculations.
;;
;; Example usage:
;;   (use-trait math .math-trait.math-trait)
(define-trait math-trait
  (
    ;; Add two unsigned integers
    ;; @param a: first number
    ;; @param b: second number
    ;; @return (response uint uint): sum and error code
    (add (uint uint) (response uint uint))

    ;; Subtract two unsigned integers
    ;; @param a: first number
    ;; @param b: second number
    ;; @return (response uint uint): difference and error code
    (sub (uint uint) (response uint uint))

    ;; Multiply two unsigned integers
    ;; @param a: first number
    ;; @param b: second number
    ;; @return (response uint uint): product and error code
    (mul (uint uint) (response uint uint))

    ;; Divide two unsigned integers
    ;; @param a: numerator
    ;; @param b: denominator
    ;; @return (response uint uint): quotient and error code
    (div (uint uint) (response uint uint))

    ;; Calculate percentage
    ;; @param amount: base amount
    ;; @param percentage: percentage to calculate
    ;; @return (response uint uint): calculated amount and error code
    (calculate-percentage (uint uint) (response uint uint))
  )
)
