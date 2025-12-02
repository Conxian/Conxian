;; Comparison Helper Utilities
;; SDK 3.9+ Compliant Comparison Functions
;; Provides wrapper functions for standard Clarity comparison operators

;; ===========================================
;; CONSTANTS
;; ===========================================
(define-constant ERR_INVALID_INPUT (err u600))

;; ===========================================
;; UINT COMPARISON FUNCTIONS
;; ===========================================

(define-read-only (lte (a uint) (b uint))
  (<= a b))

(define-read-only (gte (a uint) (b uint))
  (>= a b))

(define-read-only (gt (a uint) (b uint))
  (> a b))

(define-read-only (lt (a uint) (b uint))
  (< a b))

;; ===========================================
;; INT COMPARISON FUNCTIONS (for signed integers)
;; ===========================================

(define-read-only (lte-int (a int) (b int))
  (<= a b))

(define-read-only (gte-int (a int) (b int))
  (>= a b))

(define-read-only (gt-int (a int) (b int))
  (> a b))

(define-read-only (lt-int (a int) (b int))
  (< a b))

;; ===========================================
;; UTILITY FUNCTIONS
;; ===========================================

(define-read-only (min (a uint) (b uint))
  (if (< a b) a b))

(define-read-only (max (a uint) (b uint))
  (if (> a b) a b))

(define-read-only (min-int (a int) (b int))
  (if (< a b) a b))

(define-read-only (max-int (a int) (b int))
  (if (> a b) a b))

(define-read-only (abs-int (a int))
  (if (< a 0) (- 0 a) a))

(define-read-only (in-range (value uint) (min-val uint) (max-val uint))
  (and (>= value min-val) (<= value max-val)))
