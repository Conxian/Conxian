;; ============================================================
;; CONXIAN PROTOCOL - ERROR HANDLING UTILITIES (v3.9.0+)
;; ============================================================
;; Standardized error handling utilities for the Conxian protocol

(use-trait errors .all-traits.errors)

;; Helper function to create error responses with consistent format
(define-private (err-with-context (code uint) (context (optional (string-utf8 256))))
  (let (
    (base-err (err code))
  )
    (match context
      some-context (err (concat "[" (unwrap-panic (unwrap! (to-utf8 code) (err u0))) "] " context))
      none base-err
    )
  )
)

;; ======================
;; ERROR VALIDATION HELPERS
;; ======================

;; Check if caller is contract owner
(define-private (check-owner (caller principal))
  (if (is-eq caller (var-get owner))
    (ok true)
    (err ERR_NOT_OWNER)
  )
)

;; Check if contract is not paused
(define-private (check-not-paused)
  (if (var-get is-paused)
    (err ERR_CONTRACT_PAUSED)
    (ok true)
  )
)

;; Validate input amount is positive
(define-private (validate-positive-amount (amount uint))
  (if (<= amount u0)
    (err ERR_ZERO_AMOUNT)
    (ok true)
  )
)

;; Validate leverage amount is within bounds
(define-private (validate-leverage (leverage uint) (max-leverage uint))
  (if (or (< leverage u100) (> leverage max-leverage))
    (err ERR_INVALID_LEVERAGE)
    (ok true)
  )
)

;; Validate principal is not zero
(define-private (validate-address (addr principal))
  (if (is-eq addr 'ST000000000000000000002AMW42H)
    (err ERR_INVALID_ADDRESS)
    (ok true)
  )
)

;; ======================
;; COMMON ERROR RESPONSES
;; ======================

(define-constant ERR_OWNER_ONLY (err-with-context ERR_NOT_OWNER (some (as-max-len? u"Caller is not the owner" u100)))
(define-constant ERR_PAUSED (err-with-context ERR_CONTRACT_PAUSED (some (as-max-len? u"Contract is paused" u100)))
(define-constant ERR_ZERO_AMOUNT (err-with-context ERR_ZERO_AMOUNT (some (as-max-len? u"Amount must be greater than zero" u100)))
(define-constant ERR_INVALID_INPUT (err-with-context ERR_INVALID_INPUT (some (as-max-len? u"Invalid input parameters" u100)))

;; ======================
;; ERROR HANDLING MACROS
;; ======================

;; Macro for requiring a condition to be true with a custom error
(define-syntax require! 
  (syntax-rules ()
    ((require! condition error) 
      (if condition (ok true) error)
    )
  )
)

;; Macro for requiring a condition with a standard error code
(define-syntax require-ok!
  (syntax-rules ()
    ((require-ok! condition code) 
      (if condition (ok true) (err code))
    )
  )
)

;; Macro for unwrapping a response with a custom error
(define-syntax unwrap!-or-err
  (syntax-rules ()
    ((unwrap!-or-err response error)
      (match response
        (ok value) (ok value)
        (err _) (err error)
      )
    )
  )
)

;; ======================
;; ERROR LOGGING
;; ======================

;; Log an error event (emits an event that can be indexed)
(define-event error-event 
  ((code uint) 
   (caller principal)
   (message (optional (string-utf8 256))))
)

;; Log an error with context
(define-private (log-error (code uint) (message (optional (string-utf8 256))))
  (emit-error-event code tx-sender message)
  (err code)
)

;; ======================
;; ERROR RECOVERY HELPERS
;; ======================

;; Execute a function with error recovery
(define-private (with-error-recovery (fn (function () (response AnyType uint))))
  (try! (fn))
  (try! (check-continue (err u0)))
)

;; Check if operation should continue after error
(define-private (check-continue (result (response AnyType uint)))
  (match result
    (ok value) (ok value)
    (err code) 
      (if (>= code u4000)  ;; Critical errors (4000+)
        (err code)
        (ok (some code))   ;; Non-critical, can continue
      )
  )
)
