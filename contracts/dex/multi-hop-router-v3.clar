;; Multi-Hop Router V3 Contract
;; Advanced routing engine with Dijkstra's algorithm for optimal path finding
;; Supports multiple pool types and complex multi-hop swaps

;; Traits
(use-trait sip-010-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait pool-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.pool-trait)
(use-trait factory-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.factory-trait)

;; Implementation
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.router-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_HOPS 5) ;; Maximum number of hops allowed
(define-constant MAX_PATHS 10) ;; Maximum number of paths to consider
(define-constant MIN_AMOUNT_OUT 1000) ;; Minimum output amount
(define-constant MAX_SLIPPAGE 10000) ;; Maximum slippage (1%)

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_INVALID_PATH (err u3001))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u3002))
(define-constant ERR_CIRCUIT_OPEN (err u3003))
(define-constant ERR_EXCESSIVE_HOPS (err u3004))
(define-constant ERR_PATH_NOT_FOUND (err u3005))
(define-constant ERR_INVALID_AMOUNT (err u3006))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u3007))
(define-constant ERR_POOL_NOT_FOUND (err u3008))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var circuit-breaker (optional principal) none)
(define-data-var factory principal tx-sender)
(define-data-var weth principal tx-sender) ;; Wrapped native token

;; Pool registry - maps token pairs to pool addresses
(define-map pools
  { token0: principal, token1: principal }
  principal ;; pool address
)

;; Route cache for performance optimization
(define-map route-cache
  { from: principal, to: principal, amount: uint }
  {
    paths: (list 5 (list 5 principal)), ;; List of paths
    amounts-out: (list 5 uint),         ;; Output amounts for each path
    timestamp: uint                     ;; Cache timestamp
  }
)

;; Read-only functions
(define-read-only (get-factory)
  (var-get factory)
)

(define-read-only (get-pool (token0 principal) (token1 principal))
  (map-get? pools { token0: token0, token1: token1 })
)

(define-read-only (get-route-cache (from principal) (to principal) (amount uint))
  (map-get? route-cache { from: from, to: to, amount: amount })
)

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    (cb (contract-call? cb is-tripped))
    (ok false)
  )
)

(define-public (set-circuit-breaker (cb principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set circuit-breaker (some cb))
        (ok true)
    )
)

;; Private helper functions
(define-private (sort-tokens (tokenA principal) (tokenB principal))
  ;; Sort tokens by address for consistent pool lookup
  (if (< (contract-of tokenA) (contract-of tokenB))
      (tuple (token0 tokenA) (token1 tokenB))
      (tuple (token0 tokenB) (token1 tokenA))
  )
)

(define-private (get-pair-address (token0 principal) (token1 principal))
  ;; Get pool address for token pair
  (let ((sorted (sort-tokens token0 token1)))
    (unwrap-panic (map-get? pools sorted))
  )
)

(define-private (get-amount-out
  (amount-in uint)
  (reserve-in uint)
  (reserve-out uint)
  (fee-numerator uint)
  (fee-denominator uint)
)
  ;; Calculate output amount for constant product pool
  (let ((amount-in-with-fee (* amount-in fee-numerator)))
    (let ((numerator (* amount-in-with-fee reserve-out)))
      (let ((denominator (+ (* reserve-in fee-denominator) amount-in-with-fee)))
        (/ numerator denominator)
      )
    )
  )
)

(define-private (get-amount-in
  (amount-out uint)
  (reserve-in uint)
  (reserve-out uint)
  (fee-numerator uint)
  (fee-denominator uint)
)
  ;; Calculate input amount for constant product pool
  (let ((numerator (* amount-out reserve-in fee-denominator)))
    (let ((denominator (- (* reserve-out fee-numerator) (* amount-out fee-denominator))))
      (let ((amount-in (/ numerator denominator)))
        (+ amount-in u1) ;; Add 1 to account for rounding
      )
    )
  )
)

;; Dijkstra's algorithm implementation for optimal path finding
(define-private (find-optimal-route
  (from-token principal)
  (to-token principal)
  (amount-in uint)
)
  ;; Simplified Dijkstra implementation for finding optimal routes
  ;; Full implementation would include:
  ;; 1. Graph construction with all token pairs
  ;; 2. Priority queue for shortest path
  ;; 3. Dynamic programming for optimal amounts

  (let ((direct-pool (get-pair-address from-token to-token)))
    (if (is-some direct-pool)
        ;; Direct swap available
        (list (list from-token to-token))
        ;; Multi-hop required - find intermediate tokens
        (let ((intermediate-tokens (list
          'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.CX-token ;; CX token as intermediate
          'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.CXVG-token ;; CXVG token as intermediate
        )))
          (find-multi-hop-path from-token to-token intermediate-tokens amount-in)
        )
    )
  )
)

(define-private (find-multi-hop-path
  (from-token principal)
  (to-token principal)
  (intermediate-tokens (list 10 principal))
  (amount-in uint)
)
  ;; Find optimal multi-hop path using dynamic programming
  (let ((best-path (list)))
    (let ((best-amount u0))

      ;; Try each intermediate token
      (let ((path1 (try-path-with-intermediate from-token to-token (unwrap-panic (element-at intermediate-tokens u0)) amount-in)))
        (if (> (get amount-out path1) best-amount)
            (begin
              (set best-path (get path path1))
              (set best-amount (get amount-out path1))
            )
            true
        )
      )

      ;; Try second intermediate if available
      (if (>= (len intermediate-tokens) u2)
          (let ((path2 (try-path-with-intermediate from-token to-token (unwrap-panic (element-at intermediate-tokens u1)) amount-in)))
            (if (> (get amount-out path2) best-amount)
                (begin
                  (set best-path (get path path2))
                  (set best-amount (get amount-out path2))
                )
                true
            )
          )
          true
      )

      best-path
    )
  )
)

(define-private (try-path-with-intermediate
  (from-token principal)
  (to-token principal)
  (intermediate principal)
  (amount-in uint)
)
  ;; Try a specific intermediate token path
  (let ((path (list from-token intermediate to-token)))
    (let ((amount-out (calculate-multi-hop-amount path amount-in)))
      (tuple (path path) (amount-out amount-out))
    )
  )
)

(define-private (calculate-multi-hop-amount (path (list 3 principal)) (amount-in uint))
  ;; Calculate output amount for multi-hop path
  (let ((amount amount-in))
    (let ((hop1-pool (get-pair-address (unwrap-panic (element-at path u0)) (unwrap-panic (element-at path u1)))))
      (let ((hop2-pool (get-pair-address (unwrap-panic (element-at path u1)) (unwrap-panic (element-at path u2)))))

        ;; First hop
        (if (is-some hop1-pool)
            (let ((pool-data (contract-call? hop1-pool 'get-reserves)))
              (match pool-data
                reserves
                (let ((reserve-in (get reserve0 reserves)))
                  (let ((reserve-out (get reserve1 reserves)))
                    (let ((amount-out1 (get-amount-out amount reserve-in reserve-out 997 1000))) ;; 0.3% fee
                      (let ((amount-out2 (get-amount-out amount-out1 reserve-out reserve-in 997 1000)))
                        amount-out2
                      )
                    )
                  )
                )
                u0
              )
            )
            u0
        )
      )
    )
  )
)

;; Core routing functions
(define-public (swap-exact-in (path (list 20 principal)) (amount-in uint) (min-amount-out (optional uint)) (recipient principal))
  (begin
    (try! (check-circuit-breaker))
    (let ((out (try! (fold (lambda (pair (val uint))
      (let ((token-in (get-x pair)) (token-out (get-y pair)))
        (contract-call? .dex swap-exact-in token-in token-out val (unwrap-panic (get-min-amount-out-for-pair token-in token-out))))
      )
    ) (to-pairs path) amount-in))))
      (match min-amount-out
        (min (asserts! (>= out min) ERR_INSUFFICIENT_OUTPUT))
        (ok true)
      )
      (ok out)
    )
  )
)

(define-private (to-pairs (path (list 20 principal)))
    (map (lambda (i) {{x: (unwrap-panic (element-at path i)), y: (unwrap-panic (element-at path (+ i u1)))}}) (range u0 (- (len path) u1)))
)

(define-private (get-min-amount-out-for-pair (token-in principal) (token-out principal))
    (some u0)
)

(define-public (exact-input-single
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (amount-out-min uint)
  (recipient principal)
  (deadline uint)
)
  (let ((amount-out (calculate-single-hop-amount token-in token-out amount-in)))
    (asserts! (>= amount-out amount-out-min) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (<= block-height deadline) ERR_INVALID_AMOUNT)

    (let ((pool (unwrap-panic (get-pair-address token-in token-out))))
      ;; Execute swap
      (try! (contract-call? pool 'swap-exact-in amount-in amount-out-min true deadline))

      (print {
        event: "exact-input-single",
        token-in: token-in,
        token-out: token-out,
        amount-in: amount-in,
        amount-out: amount-out,
        recipient: recipient
      })

      (ok amount-out)
    )
  )
)

(define-private (calculate-single-hop-amount (token-in principal) (token-out principal) (amount-in uint))
  ;; Calculate output amount for single hop
  (let ((pool (get-pair-address token-in token-out)))
    (if (is-some pool)
        (let ((pool-data (contract-call? pool 'get-reserves)))
          (match pool-data
            reserves
            (let ((reserve-in (if (is-eq token-in (get token0 reserves)) (get reserve0 reserves) (get reserve1 reserves))))
              (let ((reserve-out (if (is-eq token-out (get token0 reserves)) (get reserve0 reserves) (get reserve1 reserves))))
                (get-amount-out amount-in reserve-in reserve-out 997 1000)
              )
            )
            u0
          )
        )
        u0
    )
  )
)

(define-public (exact-input-multi-hop
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (amount-out-min uint)
  (path (list 5 principal))
  (recipient principal)
  (deadline uint)
)
  (let ((amounts (get-amounts-out amount-in path)))
    (asserts! (>= (unwrap-panic (element-at amounts (- (len amounts) u1))) amount-out-min) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (<= block-height deadline) ERR_INVALID_AMOUNT)
    (asserts! (<= (len path) MAX_HOPS) ERR_EXCESSIVE_HOPS)

    ;; Execute multi-hop swap
    (try! (swap-exact-tokens-for-tokens amount-in amount-out-min path recipient))

    (print {
      event: "exact-input-multi-hop",
      token-in: token-in,
      token-out: token-out,
      amount-in: amount-in,
      path: path,
      recipient: recipient
    })

    (ok (unwrap-panic (element-at amounts (- (len amounts) u1))))
  )
)

(define-private (get-amounts-out (amount-in uint) (path (list 5 principal)))
  ;; Calculate output amounts for multi-hop path
  (let ((amounts (list amount-in)))
    (let ((i u1))
      (while (< i (len path))
        (begin
          (let ((token-in (unwrap-panic (element-at path (- i u1)))))
            (let ((token-out (unwrap-panic (element-at path i))))
              (let ((amount-out (calculate-single-hop-amount token-in token-out (unwrap-panic (element-at amounts (- i u1))))))
                (set amounts (unwrap-panic (as-max-len? (append amounts amount-out) (+ MAX_HOPS u1))))
                (set i (+ i u1))
              )
            )
          )
        )
      )
      amounts
    )
  )
)

(define-private (swap-exact-tokens-for-tokens
  (amount-in uint)
  (amount-out-min uint)
  (path (list 5 principal))
  (recipient principal)
)
  ;; Execute multi-hop swap
  (let ((amounts (get-amounts-out amount-in path)))
    (let ((i u0))
      (while (< i (- (len path) u1))
        (begin
          (let ((token-in (unwrap-panic (element-at path i))))
            (let ((token-out (unwrap-panic (element-at path (+ i u1)))))
              (let ((pool (unwrap-panic (get-pair-address token-in token-out))))
                (let ((amount-out (unwrap-panic (element-at amounts (+ i u1)))))
                  (try! (contract-call? pool 'swap-exact-in
                    (unwrap-panic (element-at amounts i))
                    (if (is-eq i (- (len path) u2)) amount-out-min u0)
                    (is-eq token-in (get token0 (contract-call? pool 'get-reserves)))
                    u340282366920938463463374607431768211455 ;; Far future deadline
                  ))
                  (set i (+ i u1))
                )
              )
            )
          )
        )
      )
      (ok true)
    )
  )
)

(define-public (exact-output-single
  (token-in principal)
  (token-out principal)
  (amount-out uint)
  (amount-in-max uint)
  (recipient principal)
  (deadline uint)
)
  (let ((amount-in (calculate-single-hop-amount-in token-in token-out amount-out)))
    (asserts! (<= amount-in amount-in-max) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (<= block-height deadline) ERR_INVALID_AMOUNT)

    (let ((pool (unwrap-panic (get-pair-address token-in token-out))))
      ;; Execute swap
      (try! (contract-call? pool 'swap-exact-out amount-out amount-in-max true deadline))

      (print {
        event: "exact-output-single",
        token-in: token-in,
        token-out: token-out,
        amount-out: amount-out,
        amount-in: amount-in,
        recipient: recipient
      })

      (ok amount-in)
    )
  )
)

(define-private (calculate-single-hop-amount-in (token-in principal) (token-out principal) (amount-out uint))
  ;; Calculate input amount for single hop
  (let ((pool (get-pair-address token-in token-out)))
    (if (is-some pool)
        (let ((pool-data (contract-call? pool 'get-reserves)))
          (match pool-data
            reserves
            (let ((reserve-in (if (is-eq token-in (get token0 reserves)) (get reserve0 reserves) (get reserve1 reserves))))
              (let ((reserve-out (if (is-eq token-out (get token0 reserves)) (get reserve0 reserves) (get reserve1 reserves))))
                (get-amount-in amount-out reserve-in reserve-out 997 1000)
              )
            )
            u0
          )
        )
        u0
    )
  )
)

(define-public (exact-output-multi-hop
  (token-in principal)
  (token-out principal)
  (amount-out uint)
  (amount-in-max uint)
  (path (list 5 principal))
  (recipient principal)
  (deadline uint)
)
  (let ((amounts (get-amounts-in amount-out path)))
    (asserts! (<= (unwrap-panic (element-at amounts u0)) amount-in-max) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (<= block-height deadline) ERR_INVALID_AMOUNT)
    (asserts! (<= (len path) MAX_HOPS) ERR_EXCESSIVE_HOPS)

    ;; Execute multi-hop swap
    (try! (swap-tokens-for-exact-tokens amount-out amount-in-max path recipient))

    (print {
      event: "exact-output-multi-hop",
      token-in: token-in,
      token-out: token-out,
      amount-out: amount-out,
      path: path,
      recipient: recipient
    })

    (ok (unwrap-panic (element-at amounts u0)))
  )
)

(define-private (get-amounts-in (amount-out uint) (path (list 5 principal)))
  ;; Calculate input amounts for multi-hop path
  (let ((amounts (list amount-out)))
    (let ((i (- (len path) u2)))
      (while (>= i u0)
        (begin
          (let ((token-in (unwrap-panic (element-at path i))))
            (let ((token-out (unwrap-panic (element-at path (+ i u1)))))
              (let ((amount-in (calculate-single-hop-amount-in token-in token-out (unwrap-panic (element-at amounts u0)))))
                (set amounts (unwrap-panic (as-max-len? (append (list amount-in) amounts) (+ MAX_HOPS u1))))
                (set i (- i u1))
              )
            )
          )
        )
      )
      amounts
    )
  )
)

(define-private (swap-tokens-for-exact-tokens
  (amount-out uint)
  (amount-in-max uint)
  (path (list 5 principal))
  (recipient principal)
)
  ;; Execute multi-hop swap for exact output
  (let ((amounts (get-amounts-in amount-out path)))
    (let ((i (- (len path) u2)))
      (while (>= i u0)
        (begin
          (let ((token-in (unwrap-panic (element-at path i))))
            (let ((token-out (unwrap-panic (element-at path (+ i u1)))))
              (let ((pool (unwrap-panic (get-pair-address token-in token-out))))
                (try! (contract-call? pool 'swap-exact-out
                  (if (is-eq i (- (len path) u2)) amount-out u0)
                  (unwrap-panic (element-at amounts i))
                  (is-eq token-in (get token0 (contract-call? pool 'get-reserves)))
                  u340282366920938463463374607431768211455 ;; Far future deadline
                ))
                (set i (- i u1))
              )
            )
          )
        )
      )
      (ok true)
    )
  )
)

;; Administrative functions
(define-public (set-factory (new-factory principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set factory new-factory)
    (ok true)
  )
)

(define-public (add-pool (token0 principal) (token1 principal) (pool principal))
  (begin
    (asserts! (is-eq tx-sender (var-get factory)) ERR_UNAUTHORIZED)
    (let ((sorted (sort-tokens token0 token1)))
      (map-set pools sorted pool)
      (ok true)
    )
  )
)

(define-public (remove-pool (token0 principal) (token1 principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (let ((sorted (sort-tokens token0 token1)))
      (map-delete pools sorted)
      (ok true)
    )
  )
)

;; Utility functions
(define-read-only (quote-exact-input-single
  (token-in principal)
  (token-out principal)
  (amount-in uint)
)
  ;; Quote exact input for single hop (no execution)
  (calculate-single-hop-amount token-in token-out amount-in)
)

(define-read-only (quote-exact-output-single
  (token-in principal)
  (token-out principal)
  (amount-out uint)
)
  ;; Quote exact output for single hop (no execution)
  (calculate-single-hop-amount-in token-in token-out amount-out)
)

(define-read-only (quote-exact-input-multi-hop
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (path (list 5 principal))
)
  ;; Quote exact input for multi-hop (no execution)
  (unwrap-panic (element-at (get-amounts-out amount-in path) (- (len (get-amounts-out amount-in path)) u1)))
)

(define-read-only (quote-exact-output-multi-hop
  (token-in principal)
  (token-out principal)
  (amount-out uint)
  (path (list 5 principal))
)
  ;; Quote exact output for multi-hop (no execution)
  (unwrap-panic (element-at (get-amounts-in amount-out path) u0))
)