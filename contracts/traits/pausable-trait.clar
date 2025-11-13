;; ===========================================
;; PAUSABLE TRAIT
;; ===========================================
;; Interface for contracts that can be paused and unpaused
;;
;; This trait provides functions to pause and resume contract operations.
;;
;; Example usage:
;;   (use-trait pausable .pausable-trait.pausable-trait)
(define-trait pausable-trait
  (
    ;; Check if the contract is currently paused
    ;; @return bool: true if paused, false otherwise
    (is-paused () (response bool uint))
    
    ;; Pause contract operations (admin only)
    ;; @return (response bool uint): success flag and error code
    (pause () (response bool uint))
    
    ;; Resume contract operations (admin only)
    ;; @return (response bool uint): success flag and error code
    (unpause () (response bool uint))
  )
)
