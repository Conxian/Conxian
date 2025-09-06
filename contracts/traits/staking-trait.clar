;; staking-trait.clar
;; Minimal staking interface used by monitors and distributors

(define-trait staking-trait
  (
    ;; Returns key staking protocol statistics in a single call
    ;; Tuple keys chosen to align with existing consumers in the codebase
    (get-protocol-info () (response (tuple (total-supply uint)
                                          (total-staked-cxd uint)
                                          (total-revenue-distributed uint)
                                          (current-epoch uint)) uint))
  )
)
