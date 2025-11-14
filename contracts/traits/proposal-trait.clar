;; ===========================================
;; PROPOSAL TRAIT
;; ===========================================
;; @desc Interface for a generic proposal.
;; This trait provides a single function to execute a proposal.
;;
;; @example
;; (use-trait proposal .proposal-trait)
(define-trait proposal-trait
  (
    ;; @desc Execute the proposal.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (execute () (response bool uint))
  )
)
