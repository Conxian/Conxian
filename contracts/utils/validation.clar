;; Validation Library
;; Standard validation functions for input parameters.

;; ===== Type Validation =====

;; Check if a principal is valid (not none and not empty)
(define-read-only (is-valid-principal (p principal))
    (is-some p)
)

;; Check if a uint is valid (not none and within bounds)
(define-read-only (is-valid-uint (value uint) (min-val uint) (max-val uint))
    (and
        (>= value min-val)
        (<= value max-val)
    )
)

;; Check if an int is valid (within bounds)
(define-read-only (is-valid-int (value int) (min-val int) (max-val int))
    (and
        (>= value min-val)
        (<= value max-val)
    )
)

;; Check if a string is valid (not empty and within length limits)
(define-read-only (is-valid-string (s string-utf8) (max-len uint))
    (and
        (> (len s) 0)
        (<= (len s) max-len)
    )
)

;; Check if a boolean is valid (not none)
(define-read-only (is-valid-bool (b bool))
    (is-some b)
)

;; Check if a buffer is valid (not empty and within size limits)
(define-read-only (is-valid-buffer (b (buff 1024)) (max-size uint))
    (and
        (> (len b) 0)
        (<= (len b) max-size)
    )
)

;; ===== Common Validations =====

;; Validate an amount (positive uint)
(define-read-only (validate-amount (amount uint))
    (asserts! (is-valid-uint amount u1 u115792089237316195423570985008687907853269984665640564039457584007913129639935) (err u1001))  ;; Invalid amount
    (ok true)
)
;; Validate an address (principal)
(define-read-only (validate-address (addr principal))
    (asserts! (is-valid-principal addr) (err u1002))  ;; Invalid address
    (ok true)
)

;; Validate a string length
(define-read-only (validate-string (s string-utf8) (max-len uint))
    (asserts! (is-valid-string s max-len) (err u1003))  ;; Invalid string
    (ok true)
)

;; Validate a buffer
(define-read-only (validate-buffer (b (buff 1024)) (max-size uint))
    (asserts! (is-valid-buffer b max-size) (err u1004))  ;; Invalid buffer
    (ok true)
)
