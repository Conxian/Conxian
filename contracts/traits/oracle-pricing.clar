;; Oracle & Pricing Traits - Price Feeds and TWAP

;; ===========================================
;; ORACLE TRAIT (Single Price Source)
;; ===========================================
(define-trait oracle-trait (
  (get-price
    (principal)
    (response uint uint)
  )
  (update-price
    (principal uint)
    (response bool uint)
  )
  (get-price-with-timestamp
    (principal)
    (
      response       {
      price: uint,
      timestamp: uint,
    }
      uint
    )
  )
))

;; ===========================================
;; ORACLE AGGREGATOR V2 TRAIT (Multi-Source)
;; ===========================================
(define-trait oracle-aggregator-v2-trait (
  (get-real-time-price
    (principal)
    (response uint uint)
  )
  (get-twap
    (principal uint)
    (response uint uint)
  )
  (add-oracle-source
    (principal principal)
    (response bool uint)
  )
  (remove-oracle-source
    (principal principal)
    (response bool uint)
  )
))

;; ===========================================
;; PRICE INITIALIZER TRAIT
;; ===========================================
(define-trait price-initializer-trait (
  (initialize-price
    (principal uint)
    (response bool uint)
  )
  (get-initial-price
    (principal)
    (response uint uint)
  )
))

;; ===========================================
;; DIMENSIONAL ORACLE TRAIT (Multi-Dimensional Prices)
;; ===========================================
(define-trait dimensional-oracle-trait (
  (get-dimensional-price
    (principal (string-ascii 32))
    (response uint uint)
  )
  (update-dimensional-metrics
    (principal (string-ascii 32) uint)
    (response bool uint)
  )
))
