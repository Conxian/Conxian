(define-trait automation-trait (
  (get-runnable-actions
    ()
    (response (list 16 uint) uint)
  )
  (execute-action
    (uint)
    (response bool uint)
  )
))
