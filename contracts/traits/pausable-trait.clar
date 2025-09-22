;; Pausable Trait
;; Defines the standard interface for pausable contracts

(define-trait pausable-trait
  (
    ;; Pause the contract (only callable by pauser role)
    (pause () (response bool uint))
    
    ;; Unpause the contract (only callable by pauser role)
    (unpause () (response bool uint))
    
    ;; Check if the contract is paused
    (is-paused () (response bool uint))
    
    ;; Require that the contract is not paused
    (when-not-paused () (response bool uint))
    
    ;; Require that the contract is paused
    (when-paused () (response bool uint))
  )
)

;; Error Codes
(define-constant ERR_PAUSED (err u200))
(define-constant ERR_NOT_PAUSED (err u201))
