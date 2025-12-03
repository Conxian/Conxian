;; @trait Pyth Storage Trait
;; @desc Trait for Pyth storage contract interaction

(define-trait pyth-storage-trait
  (
    (read-price-info ((buff 32)) (response {
        price: int,
        conf: uint,
        expo: int,
        publish-time: uint,
        prev-publish-time: uint,
        ema-price: int,
        ema-conf: uint
    } uint))
  )
)

;; @trait Pyth Decoder Trait
(define-trait pyth-decoder-trait
  (
    (decode-price-feed ((buff 8192)) (response {
        price-identifier: (buff 32),
        price: int,
        conf: uint,
        expo: int,
        publish-time: uint,
        prev-publish-time: uint,
        ema-price: int,
        ema-conf: uint
    } uint))
  )
)
