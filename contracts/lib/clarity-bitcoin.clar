;; clarity-bitcoin.clar
;; Mock implementation for local testing

(define-constant ERR-INVALID-INPUT (err u100))

(define-read-only (get-txid (tx (buff 1024)))
  (sha256 tx)
)

(define-read-only (was-tx-mined?
    (block-header (buff 80))
    (tx (buff 1024))
    (proof {
      tx-index: uint,
      hashes: (list 12 (buff 32)),
      tree-depth: uint,
    })
  )
  true
)

(define-read-only (get-reversed-txid (tx (buff 1024)))
  (sha256 tx)
)

;; Mock parsing function - simply returns a hardcoded value or a value based on first byte
(define-read-only (get-out-value (tx (buff 1024)))
  u100000000
  ;; Mock 1 BTC
)

(define-read-only (get-height (header (buff 80)))
  (ok u100)
)

(define-read-only (get-block-hash (header (buff 80)))
  (ok 0x0000000000000000000000000000000000000000000000000000000000000000)
)
