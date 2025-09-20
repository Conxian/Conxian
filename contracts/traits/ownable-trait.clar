;; ownable-trait.clar
;; This file is deprecated. Please use all-traits.clar instead.
;; The ownable-trait is now defined in all-traits.clar

;; Ownable Trait - Ownership management interface
;; Provides basic ownership and access control functionality

(define-trait ownable-trait
  (
    ;; Ownership management
    (get-owner () (response principal uint))
    (transfer-ownership (principal) (response bool uint))
    (renounce-ownership () (response bool uint))
    
    ;; Access control
    (is-owner (principal) (response bool uint))
    (only-owner-guard () (response bool uint))
    
    ;; Enhanced features
    (set-pending-owner (principal) (response bool uint))
    (accept-ownership () (response bool uint))
    (get-pending-owner () (response (optional principal) uint))
  )
)





