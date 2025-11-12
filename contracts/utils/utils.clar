;; =============================================================================
;; Conxian Protocol - Utils Contract
;; Purpose: Provide utils-trait implementation using standard Clarity functions
;; Version: 1.0.0
;; Compatibility: Clarity 3.0+
;; =============================================================================

(use-trait utils-trait .utils-trait.utils-trait)

;; Implement the trait
(impl-trait .utils-trait.utils-trait)

(define-public (principal-to-buff (p principal))
  ;; Convert principal to buffer using standard Clarity functions
  ;; This implementation uses to-string conversion since principal serialization
  ;; to buffer directly is not available in standard Clarity 3.0
  (let ((principal-str (unwrap! (as-max-len? (to-string p) u42) (err u1001))))
    (ok (unwrap! (string-to-utf8 principal-str) (err u1002)))))

(define-public (buff-to-principal (b (buff 128)))
  ;; Convert buffer to principal
  ;; This is a placeholder implementation - actual conversion from buffer to principal
  ;; requires careful validation and is limited by Clarity 3.0 capabilities
  (err u1003)) ;; Not implemented - requires careful principal validation

(define-public (string-to-uint (s (string-ascii 32)))
  ;; Convert string to unsigned integer
  ;; Returns error code on invalid input instead of panicking
  (let ((buff-repr (unwrap! (string-to-utf8 s) (err u1004))))
    (match (buff-to-int-be buff-repr)
      x (ok (unwrap! (as-max-len? (to-uint x) u18446744073709551615) (err u1004)))
      (err u1004))))

(define-public (uint-to-string (n uint))
  ;; Convert unsigned integer to string
  ;; This implementation uses int-to-utf8 conversion
  (let ((buff-repr (int-to-utf8 n))
        (str (unwrap! (as-max-len? (to-string n) u32) (err u1005))))
    (ok str)))
