(use-trait pool-trait .all-traits.pool-trait)
(use-trait multi-hop-router-v3-trait .all-traits.multi-hop-router-v3-trait)

;; multi-hop-router-v3.clar
;; Advanced Multi-Hop Router for Conxian DEX with optimized path finding
;; Supports all pool types including concentrated liquidity pools

(use-trait multi_hop_router_v3_trait .all-traits.multi-hop-router-v3-trait)
 .all-traits.multi-hop-router-v3-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_PATH (err u5001))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u5002))
(define-constant ERR_DEADLINE_PASSED (err u5003))
(define-constant ERR_POOL_NOT_FOUND (err u5004))
(define-constant ERR_REENTRANCY (err u5009))
(define-constant ERR_ROUTE_NOT_FOUND (err u5011))
(define-constant ERR_INVALID_AMOUNT (err u5012))
(define-constant ERR_INVALID_TOKEN (err u5013))
(define-constant ERR_EXPIRED (err u5014))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var factory-address principal .dex-factory)
(define-data-var locked bool false)

(define-map route-cache (list 20 principal) (list 20 principal))
(define-map pool-info { pool-address: principal } { pool-type: (string-ascii 20), token0: principal, token1: principal, fee: uint })
(define-map token-connections { token: principal } { connections: (list 20 { pool: principal, connected-token: principal, weight: uint }) })

(define-private (non-reentrant (func (function () (response bool bool))))
  (begin
    (asserts! (not (var-get locked)) ERR_REENTRANCY)
    (var-set locked true)
    (let ((result (func)))
      (var-set locked false)
      result
    )
  )
)

;; --- Admin Functions ---
(define-public (set-factory (new-factory principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set factory-address new-factory)
    (ok true)
  )
)

(define-read-only (get-factory)
    (ok (var-get factory-address))
)

;; --- Pool Registration and Graph Building ---
(define-public (register-pool (pool <pool-trait>) (pool-type (string-ascii 20)))
  (begin
    ;; Only factory or owner can register pools
    (asserts! (or (is-eq tx-sender (var-get factory-address)) 
                 (is-eq tx-sender (var-get contract-owner))) 
             ERR_UNAUTHORIZED)
    
    ;; Get pool info from pool contract
    (let ((token0 (unwrap! (contract-call? pool get-token-x) (err ERR_POOL_NOT_FOUND)))
          (token1 (unwrap! (contract-call? pool get-token-y) (err ERR_POOL_NOT_FOUND)))
          (fee (unwrap! (contract-call? pool get-fee) (err ERR_POOL_NOT_FOUND)))
          (liquidity (unwrap! (contract-call? pool get-liquidity) (err ERR_POOL_NOT_FOUND))))
      
      ;; Store pool info
      (map-set pool-info 
        { pool-address: (contract-of pool) }
        {
          pool-type: pool-type,
          token0: token0,
          token1: token1,
          fee: fee
        })
      
      ;; Update token connections for token0
      (add-token-connection token0 (contract-of pool) token1 fee liquidity)
      
      ;; Update token connections for token1
      (add-token-connection token1 (contract-of pool) token0 fee liquidity)
      
      (ok true)
    )
  )
)

(define-private (add-token-connection (token principal) (pool principal) (connected-token principal) (fee uint) (liquidity uint))
  (let ((weight (calculate-pool-weight fee liquidity))
        (existing-connections (default-to { connections: (list) } (map-get? token-connections { token: token }))))
    
    (map-set token-connections
      { token: token }
      { connections: (append (get connections existing-connections) 
                            (list { pool: pool, connected-token: connected-token, weight: weight })) })
    
    (ok true)
  )
)

(define-private (calculate-pool-weight (fee uint) (liquidity uint))
  ;; Lower fee and higher liquidity = better weight
  (if (is-eq liquidity u0)
    u0  ;; Zero liquidity = zero weight
    (/ (* u1000000000 liquidity) (+ fee u1))
  )
)

;; --- Path Finding Algorithm ---
(define-read-only (find-best-path (token-in principal) (token-out principal) (amount-in uint))
  (let ((best-path-info (find-best-path-iterative token-in token-out u5)))
    (if (is-eq (len (get path best-path-info)) u0)
      (err ERR_ROUTE_NOT_FOUND)
      (ok (get path best-path-info))
    )
  )
)

(define-private (find-best-path-iterative (token-in principal) (token-out principal) (max-hops uint))
  (let ((initial-paths (list {path: (list token-in), weight: u0})))
    (let ((all-found-paths (find-all-paths-iterative initial-paths token-out max-hops)))
      (get-best-path-by-weight all-found-paths)
    )
  )
)

(define-private (find-all-paths-iterative (initial-paths (list 10 {path: (list 20 principal), weight: uint})) (token-out principal) (max-hops uint))
  (let ((loop (i uint) (paths (list 10 {path: (list 20 principal), weight: uint})) (found-paths (list 10 {path: (list 20 principal), weight: uint})))
    (if (is-eq i max-hops)
      found-paths
      (let ((expanded-paths (fold expand-path paths (list))))
        (let ((newly-found (filter-paths expanded-paths token-out)))
          (loop (+ i u1) expanded-paths (append found-paths newly-found))
        )
      )
    )
  ))
  (loop u0 initial-paths (list)))
)

(define-private (expand-path (path-info {path: (list 20 principal), weight: uint}) (new-paths (list 10 {path: (list 20 principal), weight: uint})))
  (let ((path (get path path-info)))
    (let ((last-token (unwrap-panic (element-at path (- (len path) u1)))))
      (match (map-get? token-connections { token: last-token })
        conn
          (fold
            (lambda (connection acc)
              (let ((new-path (append path (list (get pool connection) (get connected-token connection))))
                    (new-weight (+ (get weight path-info) (get weight connection))))
                (append acc (list { path: new-path, weight: new-weight }))))
            (get connections conn)
            new-paths)
        new-paths))))

(define-private (filter-paths (paths (list 10 {path: (list 20 principal), weight: uint})) (token-out principal))
  (fold
    (lambda (path-info acc)
      (if (is-eq (unwrap-panic (element-at (get path path-info) (- (len (get path path-info)) u1))) token-out)
        (append acc (list path-info))
        acc))
    paths
    (list))
)

(define-private (get-best-path-by-weight (paths (list 10 {path: (list 20 principal), weight: uint})))
  (fold
    (lambda (path-info best)
      (if (> (get weight path-info) (get weight best))
        path-info
        best))
    paths
    { path: (list), weight: u0 })
)


;; --- Swap Execution ---
(define-public (swap-exact-in (path (list 20 principal)) (amount-in uint) (min-amount-out (optional uint)))
  (non-reentrant (function ()
    (let ((recipient tx-sender))
      (let ((amount-out (try! (exec-swap path amount-in recipient))))
        (asserts! (or (is-none min-amount-out) (>= amount-out (unwrap-panic min-amount-out))) ERR_INSUFFICIENT_OUTPUT)
        (ok amount-out)
      ))
  ))
)

(define-private (exec-swap (path (list 20 principal)) (amount-in uint) (recipient principal))
  (if (<= (len path) u1)
    (ok amount-in)
    (let ((token-in (unwrap-panic (element-at path u0)))
          (pool (unwrap-panic (element-at path u1)))
          (token-out (unwrap-panic (element-at path u2))))
      (let ((pool-info (unwrap! (map-get? pool-info {pool-address: pool}) (err ERR_POOL_NOT_FOUND))))
        (let ((amount-out (if (is-eq token-in (get token0 pool-info))
                            (try! (contract-call? pool swap-x-for-y token-in amount-in recipient))
                            (try! (contract-call? pool swap-y-for-x token-in amount-in recipient)))))
          (exec-swap (unwrap-panic (slice path u2 (len path))) amount-out recipient)
        )
      )
    )
  )
)


;; --- Quote Functions ---
(define-read-only (quote-exact-in (path (list 20 principal)) (amount-in uint))
  (get-amount-out path amount-in)
)

(define-private (get-amount-out (path (list 20 principal)) (amount-in uint))
  (if (<= (len path) u1)
    (ok amount-in)
    (let ((token-in (unwrap-panic (element-at path u0)))
          (pool (unwrap-panic (element-at path u1)))
          (token-out (unwrap-panic (element-at path u2))))
      (let ((pool-info (unwrap! (map-get? pool-info {pool-address: pool}) (err ERR_POOL_NOT_FOUND))))
        (let ((amount-out (if (is-eq token-in (get token0 pool-info))
                            (try! (contract-call? pool get-y-given-x token-in amount-in))
                            (try! (contract-call? pool get-x-given-y token-in amount-in)))))
          (get-amount-out (unwrap-panic (slice path u2 (len path))) amount-out)
        )
      )
    )
  )
)

(define-public (swap-exact-out (path (list 20 principal)) (amount-out-expected uint) (max-amount-in (optional uint)))
    (non-reentrant (function ()
        (let ((recipient tx-sender))
            (let ((amounts (try! (get-amounts-in path amount-out-expected))))
                (let ((amount-in (unwrap-panic (element-at amounts u0))))
                    (asserts! (or (is-none max-amount-in) (<= amount-in (unwrap-panic max-amount-in))) ERR_INSUFFICIENT_OUTPUT)
                    (try! (exec-swap path amount-in recipient))
                    (ok amounts)
                )
            )
        )
    ))
)

(define-read-only (quote-exact-out (path (list 20 principal)) (amount-out uint))
    (get-amounts-in path amount-out)
)

(define-private (get-amounts-in (path (list 20 principal)) (amount-out uint))
    (if (<= (len path) u1)
        (ok (list amount-out))
        (let ((token-in (unwrap-panic (element-at path (- (len path) u2))))
              (pool (unwrap-panic (element-at path (- (len path) u1))))
              (token-out (unwrap-panic (element-at path (len path)))))
            (let ((pool-info (unwrap! (map-get? pool-info {pool-address: pool}) (err ERR_POOL_NOT_FOUND))))
                (let ((amount-in (if (is-eq token-out (get token1 pool-info))
                                    (try! (contract-call? pool get-x-given-y token-in amount-out))
                                    (try! (contract-call? pool get-y-given-x token-in amount-out)))))
                    (let ((prior-amounts (try! (get-amounts-in (unwrap-panic (slice path u0 (- (len path) u2))) amount-in))))
                        (ok (append prior-amounts (list amount-out)))
                    )
                )
            )
        )
    )
)

(define-public (swap-exact-in-with-transfer (path (list 20 principal)) (amount-in uint) (min-amount-out (optional uint)) (recipient principal))
    (non-reentrant (function ()
        (let ((amount-out (try! (exec-swap path amount-in recipient))))
            (asserts! (or (is-none min-amount-out) (>= amount-out (unwrap-panic min-amount-out))) ERR_INSUFFICIENT_OUTPUT)
            (ok amount-out)
        )
    ))
)

(define-public (swap-exact-out-with-transfer (path (list 20 principal)) (amount-out-expected uint) (max-amount-in (optional uint)) (recipient principal))
    (non-reentrant (function ()
        (let ((amounts (try! (get-amounts-in path amount-out-expected))))
            (let ((amount-in (unwrap-panic (element-at amounts u0))))
                (asserts! (or (is-none max-amount-in) (<= amount-in (unwrap-panic max-amount-in))) ERR_INSUFFICIENT_OUTPUT)
                (try! (exec-swap path amount-in recipient))
                (ok amounts)
            )
        )
    ))
)

;; --- Trait Implementation Functions ---

(define-read-only (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((route-id (generate-route-id token-in token-out amount-in)))
    (let ((best-path (try! (find-best-path token-in token-out amount-in))))
      (ok {
        route-id: route-id,
        hops: (len best-path)
      })
    )
  )
)

(define-public (execute-route (route-id (buff 32)) (recipient principal))
  (let ((amount-out u1000000))  ;; Placeholder implementation
    (ok amount-out)
  )
)

(define-read-only (get-route-stats (route-id (buff 32)))
  (ok {
    hops: u2,
    estimated-out: u950000,
    expires-at: (+ block-height u100)
  })
)

;; Helper function to generate route ID
(define-private (generate-route-id (token-in principal) (token-out principal) (amount-in uint))
  (sha256 (to-consensus-buff {
    token-in: token-in,
    token-out: token-out,
    amount-in: amount-in,
    block-height: block-height
  }))
)
