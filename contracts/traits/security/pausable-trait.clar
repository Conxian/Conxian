(define-trait pausable-trait
  (
    ;; Pause the contract (only callable by pauser role)
    (pause () (response bool (err uint)))

    ;; Unpause the contract (only callable by pauser role)
    (unpause () (response bool (err uint)))

    ;; Check if the contract is paused
    (is-paused () (response bool (err uint)))

    ;; Require that the contract is not paused
    (when-not-paused () (response bool (err uint)))

    ;; Require that the contract is paused
    (when-paused () (response bool (err uint)))
  )
)
