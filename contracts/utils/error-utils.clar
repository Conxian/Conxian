;; ============================================================
;; CONXIAN PROTOCOL - ERROR HANDLING UTILITIES (v3.9.0+)
;; ============================================================
;; Standardized error handling utilities for the Conxian protocol

;; Error constants
(define-constant ERR_NOT_OWNER (err u1001))
(define-constant ERR_CONTRACT_PAUSED (err u1005))
(define-constant ERR_ZERO_AMOUNT (err u1006))
(define-constant ERR_INVALID_LEVERAGE (err u1007))
(define-constant ERR_INVALID_ADDRESS (err u1008))
(define-constant ERR_INVALID_INPUT (err u1009))

;; Data variables
(define-data-var owner principal tx-sender)
(define-data-var is-paused bool false)

;; Helper function to create error responses with consistent format
(define-private (err-with-context
    (code uint)
    (context (optional (string-utf8 256)))
  )
  (let ((base-err (err code)))
    (match context
      some-context (err (concat "[ERR] " some-context))
      none
      base-err
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

;; ======================
;; COMMON ERROR RESPONSES
;; ======================

(define-constant ERR_OWNER_ONLY (err-with-context ERR_NOT_OWNER
  (some (as-max-len? u"Caller is not the owner" u100))
))
(define-constant ERR_PAUSED (err-with-context ERR_CONTRACT_PAUSED
  (some (as-max-len? u"Contract is paused" u100))
))
(define-constant ERR_ZERO_AMOUNT (err-with-context ERR_ZERO_AMOUNT
  (some (as-max-len? u"Amount must be greater than zero" u100))
))
(define-constant ERR_INVALID_INPUT (err-with-context ERR_INVALID_INPUT
  (some (as-max-len? u"Invalid input parameters" u100))
))

;; ======================
;; ERROR LOGGING
;; ======================

;; Log an error event (emits an event that can be indexed)

;; Log an error with context
(define-private (log-error
    (code uint)
    (message (optional (string-utf8 256)))
  )
  (print {
    code: code,
    caller: tx-sender,
    message: message,
  })
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
    (ok value)
    (ok value)
    (err code)
    (if (>= code u4000) ;; Critical errors (4000+)
      (err code)
      (ok (some code)) ;; Non-critical, can continue
    )
  )
)
