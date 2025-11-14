;; ===========================================
;; PAUSABLE TRAIT
;; ===========================================
;; @desc Interface for contracts that can be paused and unpaused.
;; This trait provides functions to pause and resume contract operations.
;;
;; @example
;; (use-trait pausable .pausable-trait.pausable-trait)
(define-trait pausable-trait
  (
    ;; @desc Check if the contract is currently paused.
    ;; @returns (response bool uint): True if the contract is paused, false otherwise, or an error code.
    (is-paused () (response bool uint))
    
    ;; @desc Pause contract operations (admin only).
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (pause () (response bool uint))
    
    ;; @desc Resume contract operations (admin only).
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (unpause () (response bool uint))
  )
)
