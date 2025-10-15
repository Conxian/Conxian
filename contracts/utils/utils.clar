(use-trait utils .all-traits.utils-trait)
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

(use-trait utils-trait .all-traits.utils-trait)
(use-trait utils_trait .all-traits.utils-trait)
 .all-traits.utils-trait)

(define-public (principal-to-buff (p principal))
  (ok 0x0000000000000000000000000000000000000000000000000000000000000000)
)

