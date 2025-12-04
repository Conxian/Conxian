;; @contract Pyth Oracle V2 Mock
;; @version 1.0.0
;; @desc Mock implementation of Pyth Oracle for testing and devnet.

(use-trait pyth-storage-trait .pyth-traits.pyth-storage-trait)

(define-public (read-price-feed (feed-id (buff 32)) (storage <pyth-storage-trait>))
    (if false
        (err u0)
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
)

;; (define-public (verify-and-update-price (vaa (buff 8192)) (storage <pyth-storage-trait>))
;;    (ok u0)
;;)
