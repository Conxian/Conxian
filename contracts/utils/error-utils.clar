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
  (err code)
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
;; For Phase 0 we only expose simple constants above and a basic logging helper.

;; ======================
;; ERROR LOGGING
;; ======================

;; For Phase 0 we only expose simple constants above and a basic logging helper.

;; ======================
;; ERROR LOGGING
;; ======================

      message: message
    })
    (err code)
  )
)
