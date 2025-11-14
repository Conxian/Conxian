;; ===========================================
;; FIXED POINT MATH TRAIT
;; ===========================================
;; @desc Interface for fixed-point arithmetic operations.
;; This trait provides functions for precise mathematical calculations
;; using fixed-point numbers, avoiding floating-point inaccuracies.
;;
;; @example
;; (use-trait fixed-point-math .fixed-point-math-trait.fixed-point-math-trait)
(define-trait fixed-point-math-trait
  (
    ;; @desc Add two fixed-point numbers.
    ;; @param a: The first number.
    ;; @param b: The second number.
    ;; @returns (response int uint): The sum of the two numbers, or an error code.
    (add (int int) (response int uint))

    ;; @desc Subtract two fixed-point numbers.
    ;; @param a: The first number.
    ;; @param b: The second number.
    ;; @returns (response int uint): The difference of the two numbers, or an error code.
    (sub (int int) (response int uint))

    ;; @desc Multiply two fixed-point numbers.
    ;; @param a: The first number.
    ;; @param b: The second number.
    ;; @returns (response int uint): The product of the two numbers, or an error code.
    (mul (int int) (response int uint))

    ;; @desc Divide two fixed-point numbers.
    ;; @param a: The numerator.
    ;; @param b: The denominator.
    ;; @returns (response int uint): The quotient of the two numbers, or an error code.
    (div (int int) (response int uint))

    ;; @desc Exponentiate a fixed-point number.
    ;; @param base: The base number.
    ;; @param exp: The exponent.
    ;; @returns (response int uint): The result of the exponentiation, or an error code.
    (pow (int uint) (response int uint))

    ;; @desc Calculate the square root of a fixed-point number.
    ;; @param a: The number to calculate the square root of.
    ;; @returns (response int uint): The square root of the number, or an error code.
    (sqrt (int) (response int uint))
  )
)
