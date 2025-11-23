;; ============================================================
;; CONXIAN PROTOCOL - ERROR HANDLING UTILITIES (v3.9.0+)
;; ============================================================
;; Standardized error handling utilities for the Conxian protocol

;; ============================================================
;; ERROR CONSTANTS
;; ============================================================

(define-constant ERR_NOT_OWNER (err u1001))
(define-constant ERR_CONTRACT_PAUSED (err u1005))
(define-constant ERR_ZERO_AMOUNT (err u1006))
(define-constant ERR_INVALID_LEVERAGE (err u1007))
(define-constant ERR_INVALID_ADDRESS (err u1008))
(define-constant ERR_INVALID_INPUT (err u1009))

;; ============================================================
;; DATA VARIABLES
;; ============================================================

(define-data-var owner principal tx-sender)
(define-data-var is-paused bool false)

;; ============================================================
;; ERROR VALIDATION HELPERS
;; ============================================================

;; Check if caller is contract owner
(define-read-only (check-owner (caller principal))
  (if (is-eq caller (var-get owner))
    (ok true)
    ERR_NOT_OWNER
  )
)

;; Check if contract is not paused
(define-read-only (check-not-paused)
  (if (var-get is-paused)
    ERR_CONTRACT_PAUSED
    (ok true)
  )
)

;; Validate input amount is positive
(define-read-only (validate-positive-amount (amount uint))
  (if (<= amount u0)
    ERR_ZERO_AMOUNT
    (ok true)
  )
)

;; Validate address is not zero address
(define-read-only (validate-address (addr principal))
  (if (is-eq addr tx-sender)
    (ok true)
    ERR_INVALID_ADDRESS
  )
)

;; ============================================================
;; ADMIN FUNCTIONS
;; ============================================================

;; Set contract pause state
(define-public (set-paused (paused bool))
  (begin
    (try! (check-owner tx-sender))
    (var-set is-paused paused)
    (ok true)
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-owner tx-sender))
    (try! (validate-address new-owner))
    (var-set owner new-owner)
    (ok true)
  )
)

;; ============================================================
;; READ-ONLY FUNCTIONS
;; ============================================================

(define-read-only (get-owner)
  (var-get owner)
)

(define-read-only (get-paused)
  (var-get is-paused)
)
