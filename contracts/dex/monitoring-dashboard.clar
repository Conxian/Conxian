;; monitoring-dashboard.clar

;; This contract provides real-time monitoring and event logging.
(define-constant ERR_UNAUTHORIZED (err u9100))

(define-data-var contract-owner principal tx-sender)
(define-map events uint {
  component: (string-ascii 32),
  event-type: (string-ascii 32),
  severity: uint,
  message: (string-ascii 256),
  block-height: uint,
  data: (optional (buff 256))
})
(define-data-var event-counter uint u0)

(define-public (log-event
    (component (string-ascii 32))
    (event-type (string-ascii 32))
    (severity uint)
    (message (string-ascii 256))
    (data (optional (buff 256)))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((event-id (+ (var-get event-counter) u1)))
      (map-set events event-id {
        component: component,
        event-type: event-type,
        severity: severity,
        message: message,
        block-height: block-height,
        data: data
      })
      (var-set event-counter event-id)
      (ok event-id)
    )
  )
)

(define-read-only (get-event (event-id uint))
  (map-get? events event-id)
)

(define-read-only (get-events (limit uint) (offset uint))
  (let (
      (total (var-get event-counter))
      (start-id (if (> total offset) (- total offset) u0))
      (clamped-limit (if (> limit u100) u100 limit))
      (count (if (> clamped-limit start-id) start-id clamped-limit))
    )
    (if (is-eq count u0)
      (list)
      (let ((indices (range u0 count)))
        (map
          (lambda (index)
            (let ((event-id (- start-id index)))
              (map-get? events event-id)
            )
          )
          indices
        )
      )
    )
  )
)

(define-read-only (get-event-count)
  (ok (var-get event-counter))
)