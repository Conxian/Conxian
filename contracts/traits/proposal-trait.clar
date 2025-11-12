;; ===========================================
;; PROPOSAL TRAIT
;; ===========================================
;; Interface for a generic proposal.
;;
;; This trait provides a single function to execute a proposal.
;;
;; Example usage:
;;   (use-trait proposal .proposal-trait)
(define-trait proposal-trait
  (
    ;; Execute the proposal.
    ;; @return (response bool uint): success flag and error code
    (execute () (response bool uint))
  )
)
