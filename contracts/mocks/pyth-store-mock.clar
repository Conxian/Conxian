;; @contract Pyth Storage Mock
;; @version 1.0.0
;; @desc Mock implementation of Pyth Storage for testing.

(impl-trait .pyth-traits.pyth-storage-trait)

(define-read-only (read-price-info (price-feed-id (buff 32)))
    (ok {
        price: 100000000000, ;; 1000 * 10^8
        conf: u100,
        expo: -8,
        publish-time: block-height,
        prev-publish-time: (- block-height u1),
        ema-price: 100000000000,
        ema-conf: u100
    })
)
