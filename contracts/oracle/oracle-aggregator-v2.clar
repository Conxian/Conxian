;; Oracle Aggregator V2
;; This contract aggregates prices from multiple oracle sources, calculates TWAP, and detects manipulation.

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_INVALID_SOURCE (err u6001))
(define-constant ERR_NO_SOURCES (err u6002))
(define-constant ERR_INVALID_PRICE (err u6003))
(define-constant ERR_DEVIATION_TOO_HIGH (err u6004))
(define-constant ERR_CIRCUIT_OPEN (err u5000))
(define-constant ERR_PRICE_MANIPULATION (err u6005))
(define-constant ONE_HOUR_IN_BLOCKS u6)
(define-constant MANIPULATION_DEVIATION_THRESHOLD u1000) ;; 10%
(define-constant MAX_PRICE_AGE_BLOCKS u10)
(define-constant TWAP_ALPHA u2000) ;; 20% weight for new price in EMA

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var circuit-breaker principal tx-sender)
(define-data-var oracle-sources (list 20 principal) (list))
(define-data-var aggregation-enabled bool true)
(define-map prices { token-a: principal, token-b: principal } { price: uint, last-updated: uint })
(define-map twap { token-a: principal, token-b: principal } { price: uint, last-updated: uint })
(define-map price-history { token-a: principal, token-b: principal } (list 100 uint))

;; --- Utils ---

(define-private (list-contains-principal? (needle principal) (haystack (list 20 principal)))
  (is-some (index-of haystack needle)))

(define-private (append-capped-uint (xs (list 100 uint)) (x uint) (cap uint))
  (let ((n (len xs)))
    (if (< n cap)
        (unwrap-panic (as-max-len? (append xs x) cap))
        (let ((tail (unwrap-panic (slice? xs u1 n)))
              (trimmed (unwrap-panic (as-max-len? tail cap))))
          (unwrap-panic (as-max-len? (append trimmed x) cap))))))

(define-private (insert-sorted (x uint) (sorted (list 20 uint)))
  (let ((n (len sorted)))
    (if (is-eq n u0)
        (list x)
        (let ((head (unwrap-panic (element-at? sorted u0)))
              (rest (unwrap-panic (slice? sorted u1 n))))
          (if (<= x head)
              (unwrap-panic (as-max-len? (concat (list x) sorted) u20))
              (unwrap-panic (as-max-len? (concat (list head) (insert-sorted x rest)) u20)))))))

(define-private (sort-uint-asc (xs (list 20 uint)))
  (fold insert-sorted xs (list)))

(define-private (median-uint (xs (list 20 uint)))
  (let ((sorted (sort-uint-asc xs))
        (n (len sorted)))
    (asserts! (> n u0) ERR_INVALID_PRICE)
    (if (is-eq (mod n u2) u1)
        (ok (unwrap-panic (element-at? sorted (/ (- n u1) u2))))
        (ok (/ (+ (unwrap-panic (element-at? sorted (/ n u2)))
                  (unwrap-panic (element-at? sorted (- (/ n u2) u1))))
               u2)))))

;; --- Circuit Breaker ---
(define-private (check-circuit-breaker)
  (contract-call? (var-get circuit-breaker) is-circuit-open))

;; --- Sources IO ---

(define-private (get-prices-from-sources (sources (list 20 principal)) (token-a principal) (token-b principal))
  (let ((collected (fold
          (lambda (source acc)
            (match (contract-call? source get-price token-a token-b)
              price (unwrap-panic (as-max-len? (append acc price) u20))
              (err u0)))
          sources
          (list))))
    (asserts! (> (len collected) u0) ERR_NO_SOURCES)
    (ok collected)))

;; --- Public Admin ---

(define-public (add-oracle-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((sources (var-get oracle-sources)))
      (asserts! (not (list-contains-principal? source sources)) (ok true))
      (var-set oracle-sources (unwrap-panic (as-max-len? (append sources source) u20)))
      (ok true))))

(define-public (remove-oracle-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set oracle-sources (filter (lambda (s) (not (is-eq s source))) (var-get oracle-sources)))
    (ok true)))

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)))

(define-public (toggle-aggregation (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set aggregation-enabled enabled)
    (ok true)))

;; --- Core ---

(define-public (update-price (token-a principal) (token-b principal))
  (let ((sources (var-get oracle-sources)))
    (asserts! (var-get aggregation-enabled) ERR_CIRCUIT_OPEN)
    (asserts! (> (len sources) u0) ERR_NO_SOURCES)
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((prices-list (try! (get-prices-from-sources sources token-a token-b)))
          (median-price (try! (median-uint prices-list))))
      (try! (check-deviation median-price token-a token-b))
      (try! (check-manipulation median-price token-a token-b))
      (map-set prices { token-a: token-a, token-b: token-b } { price: median-price, last-updated: block-height })
      (let ((hist (default-to (list) (map-get? price-history { token-a: token-a, token-b: token-b })))
            (new-hist (append-capped-uint hist median-price u100)))
        (map-set price-history { token-a: token-a, token-b: token-b } new-hist))
      (try! (update-twap median-price token-a token-b))
      (ok median-price))))

(define-read-only (get-price (token-a principal) (token-b principal))
  (ok (get price (unwrap! (map-get? prices { token-a: token-a, token-b: token-b }) ERR_INVALID_PRICE))))

(define-read-only (get-twap (token-a principal) (token-b principal))
  (ok (get price (unwrap! (map-get? twap { token-a: token-a, token-b: token-b }) ERR_INVALID_PRICE))))

(define-read-only (is-price-stale (token-a principal) (token-b principal))
  (match (map-get? prices { token-a: token-a, token-b: token-b })
    price-data (ok (> (- block-height (get last-updated price-data)) MAX_PRICE_AGE_BLOCKS))
    (ok true)))

;; --- Risk Checks ---

(define-private (check-deviation (new-price uint) (token-a principal) (token-b principal))
  (match (map-get? prices { token-a: token-a, token-b: token-b })
    old-price-data
    (let ((old-price (get price old-price-data))
          (deviation (if (> new-price old-price)
                        (- new-price old-price)
                        (- old-price new-price)))
          (threshold (/ (* old-price u500) u10000)))
      (asserts! (<= deviation threshold) ERR_DEVIATION_TOO_HIGH)
      (ok true))
    (ok true)))

(define-private (check-manipulation (new-price uint) (token-a principal) (token-b principal))
  (let ((history (default-to (list) (map-get? price-history { token-a: token-a, token-b: token-b }))))
    (if (>= (len history) u5)
        (let ((sum (fold + history u0))
              (average (/ sum (len history)))
              (deviation (if (> new-price average)
                            (- new-price average)
                            (- average new-price)))
              (threshold (/ (* average MANIPULATION_DEVIATION_THRESHOLD) u10000)))
          (asserts! (<= deviation threshold) ERR_PRICE_MANIPULATION)
          (ok true))
        (ok true))))

;; --- TWAP ---

(define-private (update-twap (new-price uint) (token-a principal) (token-b principal))
  (match (map-get? twap { token-a: token-a, token-b: token-b })
    old-twap-data
    (let ((old-twap (get price old-twap-data))
          (ema-price (/ (+ (* new-price TWAP_ALPHA) (* old-twap (- u10000 TWAP_ALPHA))) u10000)))
      (map-set twap { token-a: token-a, token-b: token-b } { price: ema-price, last-updated: block-height })
      (ok true))
    (begin
      (map-set twap { token-a: token-a, token-b: token-b } { price: new-price, last-updated: block-height })
      (ok true))))