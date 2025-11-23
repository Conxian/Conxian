;; Validation Library
;; Standard validation functions for input parameters.

;; ===== Type Validation =====

;; Check if a principal is valid (not none and not empty)
(define-read-only (is-valid-principal (p principal))
  true
)

;; Check if a uint is valid (within bounds)
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
(define-read-only (is-valid-string (s (string-utf8 256)) (max-len uint))
  (and
    (> (len s) u0)
    (<= (len s) max-len)
  )
)

;; Check if a boolean is valid (not none)
(define-read-only (is-valid-bool (b bool))
  true
)

;; Check if a buffer is valid (not empty and within size limits)
(define-read-only (is-valid-buffer (b (buff 1024)) (max-size uint))
  (and
    (> (len b) u0)
    (<= (len b) max-size)
  )
)

;; ===== Common Validations =====

;; Validate an amount (positive uint)
(define-read-only (validate-amount (amount uint) (min-val uint) (max-val uint))
  (begin
    (asserts! (>= amount min-val) (err u1001))
    (asserts! (<= amount max-val) (err u1002))
    (ok true)
  )
)

;; Validate an address (principal)
(define-read-only (validate-address (addr principal))
  (begin
    (asserts! (is-valid-principal addr) (err u1002))
    (ok true)
  )
)

;; Validate a string length
(define-read-only (validate-string (s (string-utf8 256)) (max-len uint))
  (begin
    (asserts! (is-valid-string s max-len) (err u1003))
    (ok true)
  )
)

;; Validate a buffer
(define-read-only (validate-buffer (b (buff 1024)) (max-size uint))
  (begin
    (asserts! (is-valid-buffer b max-size) (err u1004))
    (ok true)
  )
)
