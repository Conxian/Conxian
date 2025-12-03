;; @contract RedStone Oracle Mock
;; @version 1.0.0
;; @desc Mock implementation of RedStone Oracle.

(define-read-only (get-price-data (feed-id (buff 32)))
    (if false
        (err u0)
        (ok {
            price: u100000000000,
            timestamp: block-height
        })
    )
)
