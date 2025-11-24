;; performance-optimizer.clar
;; Optimizes performance for the Conxian DEX.

(define-constant ERR_UNAUTHORIZED (err u13000))

(define-map gas-usage { function: (string-ascii 32) } {
  total-gas: uint,
  call-count: uint
})

(define-public (track-gas-usage (function (string-ascii 32)) (gas-used uint))
  (begin
    (asserts! (is-eq tx-sender .monitored-contract) ERR_UNAUTHORIZED)
    (let ((gas-data (default-to { total-gas: u0, call-count: u0 } (map-get? gas-usage { function: function }))))
      (map-set gas-usage { function: function } {
        total-gas: (+ (get total-gas gas-data) gas-used),
        call-count: (+ (get call-count gas-data) u1)
      })
    )
    (ok true)
  )
)

(define-read-only (get-average-gas-usage (function (string-ascii 32)))
  (let ((gas-data (unwrap! (map-get? gas-usage { function: function }) (err u0))))
    (if (is-eq (get call-count gas-data) u0)
      (ok u0)
      (ok (/ (get total-gas gas-data) (get call-count gas-data)))
    )
  )
)
