;; ===========================================
;; MATH TRAIT
;; ===========================================
;; @desc Interface for common mathematical operations.
;; This trait provides basic mathematical functions that can be used
;; across various contracts for consistent calculations.
;;
;; @example
;; (use-trait math .math-trait.math-trait)
(define-trait math-trait
  (
    ;; @desc Add two unsigned integers.
    ;; @param a: The first number.
    ;; @param b: The second number.
    ;; @returns (response uint uint): The sum of the two numbers, or an error code.
    (add (uint uint) (response uint uint))

    ;; @desc Subtract two unsigned integers.
    ;; @param a: The first number.
    ;; @param b: The second number.
    ;; @returns (response uint uint): The difference of the two numbers, or an error code.
    (sub (uint uint) (response uint uint))

    ;; @desc Multiply two unsigned integers.
    ;; @param a: The first number.
    ;; @param b: The second number.
    ;; @returns (response uint uint): The product of the two numbers, or an error code.
    (mul (uint uint) (response uint uint))

    ;; @desc Divide two unsigned integers.
    ;; @param a: The numerator.
    ;; @param b: The denominator.
    ;; @returns (response uint uint): The quotient of the two numbers, or an error code.
    (div (uint uint) (response uint uint))

    ;; @desc Calculate a percentage of an amount.
    ;; @param amount: The base amount.
    ;; @param percentage: The percentage to calculate.
    ;; @returns (response uint uint): The calculated amount, or an error code.
    (calculate-percentage (uint uint) (response uint uint))
  )
)
