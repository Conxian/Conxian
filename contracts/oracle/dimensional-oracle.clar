(use-trait oracle-trait .all-traits.oracle-trait)
;; Dimensional Oracle
;; Implements a robust price oracle with multiple data sources and deviation checks

(impl-trait oracle-trait)


(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PRICE (err u101))
(define-constant ERR_STALE_PRICE (err u102))
(define-constant ERR_DEVIATION_TOO_HIGH (err u103))
(define-constant ERR_FEED_EXISTS (err u104))
(define-constant ERR_FEED_NOT_FOUND (err u105))
(define-constant ERR_INVALID_INPUT (err u106))
(define-constant ERR_CONTRACT_PAUSED (err u107))

;; Data structures
(define-constant DEFAULT_HEARTBEAT u1440)  ;; ~1 day in blocks
(define-constant DEFAULT_MAX_DEVIATION u500)  ;; 5% in basis points
(define-constant MAX_FEEDS u10)  ;; Maximum number of feeds per token

(define-data-var admin principal tx-sender)
(define-data-var paused bool false)

(define-data-var heartbeat-interval uint DEFAULT_HEARTBEAT)
(define-data-var max-deviation uint DEFAULT_MAX_DEVIATION)

;; Price data structure
(define-map price-data
  { token: principal }
  {
    price: uint,
    last-updated: uint,
    deviation-threshold: uint
  }
)

;; Price feeds mapping (token -> list of feed addresses)
(define-map price-feeds
  { token: principal }
  (list 10 principal)  ;; Max 10 feeds per token
)

;; Feed data (feed address -> token -> price data)
(define-map feed-prices
  { feed: principal, token: principal }
  {
    price: uint,
    last-updated: uint
  }
)

;; Guards
(define-private (only-admin)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (ok true)))

(define-private (when-not-paused)
  (begin
    (asserts! (not (var-get paused)) ERR_CONTRACT_PAUSED)
    (ok true)))

(define-private (only-oracle-updater)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (ok true)))

;; ========== Admin Functions ==========

(define-public (set-admin (new-admin principal))
  (begin
    (try! (only-admin))
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (emergency-price-override (token principal) (price uint))
  (begin
    (try! (only-admin))
    
    (let ((current-block block-height))
      ;; Update the price directly
      (map-set price-data 
        {token: token}
        {
          price: price,
          last-updated: current-block,
          deviation-threshold: u1000  ;; 10% deviation for emergency overrides
        }
      )
      
      ;; Log the emergency override
      (try! (contract-call? .system-monitor
        log-event
        "oracle"
        "emergency-override"
        u3
        "Emergency price override executed"
        (some { token: token, price: price, block: current-block, caller: tx-sender })))
      
      (ok true)
    )
  )
)

(define-public (set-heartbeat (token principal) (interval uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (var-set heartbeat-interval interval)
    (ok true)
  )
)

(define-public (set-max-deviation (deviation uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (<= deviation u10000) ERR_INVALID_INPUT)  ;; Max 100% deviation
    (var-set max-deviation deviation)
    (ok true)
  )
)

;; ========== Price Feed Management ==========

(define-public (add-price-feed (token principal) (feed principal))
  (let (
      (current-feeds (default-to (list) (map-get? price-feeds {token: token})))
    )
    (try! (only-admin))
    (asserts! (< (len current-feeds) MAX_FEEDS) (err u108))  ;; Max feeds reached
    
    ;; Check if feed already exists
    (asserts! (not (any (lambda ((f principal)) (is-eq f feed)) current-feeds)) ERR_FEED_EXISTS)
      
    (map-set price-feeds {token: token} (append current-feeds (list feed)))
    
    ;; Log the feed addition
    (try! (contract-call? .system-monitor 
      log-event 
      "oracle"
      "feed-added"
      u1  ;; INFO level
      "Price feed added"
      none))
      
    (ok true)
  )
)

(define-public (remove-price-feed (token principal) (feed principal))
  (let (
      (current-feeds (default-to (list) (map-get? price-feeds {token: token})))
    )
    (try! (only-admin))
    (let ((new-feeds (filter (lambda ((f principal)) (not (is-eq f feed))) current-feeds)))
      (asserts! (> (len new-feeds) u0) (err u109))  ;; At least one feed required
      (map-set price-feeds {token: token} new-feeds)
      ;; Log the feed removal
      (try! (contract-call? .system-monitor
        log-event
        "oracle"
        "feed-removed"
        u2
        "Oracle feed removed"
        (some { feed: feed, token: token })))
      (ok true)
    )
  )
)

;; ========== Price Updates ==========

(define-public (update-price (token principal) (price uint))
  (begin
    (try! (when-not-paused))
    (try! (only-oracle-updater))
    (let ((current-block block-height)
          (feeds (default-to (list) (map-get? price-feeds {token: token}))))
      (asserts! (any (lambda ((f principal)) (is-eq tx-sender f)) feeds) ERR_NOT_AUTHORIZED)
      (map-set feed-prices {feed: tx-sender, token: token} { price: price, last-updated: current-block })
      (try! (update-aggregate-price token))
      (ok true)
    )
  )
)
(define-private (update-aggregate-price (token principal))
  (let ((feeds (default-to (list) (map-get? price-feeds {token: token})))
        (current-block block-height)
        (heartbeat (var-get heartbeat-interval)))
    (let ((valid-prices (fold (lambda ((feed principal) (acc (list 10 uint)))
                                (let ((fd (map-get? feed-prices {feed: feed, token: token})))
                                  (if (and fd (>= current-block (- (get last-updated (unwrap-panic fd)) heartbeat)))
                                      (append acc (list (get price (unwrap-panic fd))))
                                      acc)))
                              feeds
                              (list))))
      (asserts! (> (len valid-prices) u0) ERR_STALE_PRICE)
      (let ((median-price (get-median valid-prices)))
        (match (map-get? price-data {token: token})
          existing-data (let ((current-price (get price existing-data)))
                          (asserts! (is-price-deviation-valid? current-price median-price) ERR_DEVIATION_TOO_HIGH)
                          (ok true))
          (ok true))
        (map-set price-data {token: token}
          { price: median-price, last-updated: current-block, deviation-threshold: (var-get max-deviation) })
        (ok true)
      )
    )
  )
)

(define-private (get-median (values (list 10 uint)))
  (let ((sorted (sort < values)))
    (let ((len (len sorted)))
      (if (is-eq (mod len u2) u1)
        ;; Odd length: return middle element
        (element-at sorted (/ (- len u1) u2))
        ;; Even length: average of two middle elements
        (/ (+ (element-at sorted (/ len u2))
              (element-at sorted (- (/ len u2) u1)))
           u2)
      )
    )
  )
)

(define-private (is-price-deviation-valid? (old-price uint) (new-price uint))
  (let ((deviation 
    (* (/ (abs (- old-price new-price)) old-price) u10000)  ;; In basis points
  ))
    (<= deviation (var-get max-deviation))
  )
)

;; ========== Public Getters ==========

(define-read-only (get-price (token principal))
  (match (map-get? price-data {token: token})
    data (ok (get price data))
    (err ERR_INVALID_PRICE)
  )
)

(define-read-only (get-last-updated (token principal))
  (match (map-get? price-data {token: token})
    data (ok (get last-updated data))
    (err ERR_INVALID_PRICE)
  )
)

(define-read-only (get-deviation-threshold (token principal))
  (match (map-get? price-data {token: token})
    data (ok (get deviation-threshold data))
    (ok (var-get max-deviation))
  )
)

(define-read-only (is-price-stale (token principal))
  (match (map-get? price-data {token: token})
    data
    (begin
      (let ((last-updated (get last-updated data))
            (current-block block-height))
        (ok (> (- current-block last-updated) (var-get heartbeat-interval)))
      )
    )
    (ok true)  ;; If no price data, consider it stale
  )
)

(define-read-only (get-feed-count (token principal))
  (ok (len (default-to (list) (map-get? price-feeds {token: token}))))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)

