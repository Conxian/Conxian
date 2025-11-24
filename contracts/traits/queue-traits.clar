;; Queue Contract Trait
;; Defines interface for queue operations in token transfers

(define-trait queue-contract
  (
    (on-transfer (principal principal uint) (response bool uint))
    (on-cxlp-transfer (principal principal uint) (response bool uint))
  )
)
