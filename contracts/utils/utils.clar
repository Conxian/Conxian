(use-trait utils-trait .all-traits.utils-trait)

;; utils.clar
;; Utility contract implementing `utils-trait` to provide a placeholder
;; principal-to-buff serialization for SDK 3.7.0 compatibility.
;;
;; NOTE: Clarity 3.0 does not provide a native principal->buff conversion.
;; This implementation returns a constant 32-byte buffer as a placeholder to
;; unblock compilation and allow downstream contracts to be type-correct.
;;
;; WARNING: Do NOT rely on this for production ordering or hashing logic.
;; Replace call sites with a deterministic and supported approach, or
;; migrate to an approved serialization scheme once available.

(impl-trait utils-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))

;; Data Variables
(define-data-var contract-enabled bool false)

;; Public Functions
(define-public (enable-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (ok (var-set contract-enabled true))))

;; Read-Only Functions
(define-read-only (is-enabled)
  (var-get contract-enabled))
