(define-trait cxlp-migration-queue-trait
  (
    (enqueue-migration (user principal) (amount uint) (response uint (err uint)))
    (process-migration (queue-id uint) (response bool (err uint)))
    (get-queue-position (queue-id uint) (response uint (err uint)))
    (cancel-migration (queue-id uint) (response bool (err uint)))
  )
)
