;; ===========================================
;; FIXED POINT MATH TRAIT
;; ===========================================
;; Interface for fixed-point arithmetic operations
;;
;; This trait provides functions for precise mathematical calculations
;; using fixed-point numbers, avoiding floating-point inaccuracies.
;;
;; Example usage:
;;   (use-trait fixed-point-math .fixed-point-math-trait.fixed-point-math-trait)
(define-trait fixed-point-math-trait
  (
    ;; Add two fixed-point numbers
    ;; @param a: first number
    ;; @param b: second number
    ;; @return (response int uint): sum and error code
    (add (int int) (response int uint))

    ;; Subtract two fixed-point numbers
    ;; @param a: first number
    ;; @param b: second number
    ;; @return (response int uint): difference and error code
    (sub (int int) (response int uint))

    ;; Multiply two fixed-point numbers
    ;; @param a: first number
    ;; @param b: second number
    ;; @return (response int uint): product and error code
    (mul (int int) (response int uint))

    ;; Divide two fixed-point numbers
    ;; @param a: numerator
    ;; @param b: denominator
    ;; @return (response int uint): quotient and error code
    (div (int int) (response int uint))

    ;; Exponentiate a fixed-point number
    ;; @param base: base number
    ;; @param exp: exponent
    ;; @return (response int uint): result and error code
    (pow (int uint) (response int uint))

    ;; Square root of a fixed-point number
    ;; @param a: number
    ;; @return (response int uint): square root and error code
    (sqrt (int) (response int uint))
  )
)
