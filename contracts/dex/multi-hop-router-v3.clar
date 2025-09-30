;; Multi-Hop Router V3 Contract
;; Advanced routing engine with Dijkstra's algorithm for optimal path finding
;; Supports multiple pool types and complex multi-hop swaps

;; Traits
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait pool-trait .all-traits.pool-trait)
(use-trait factory-trait .all-traits.factory-trait)
(use-trait factory-v2-trait .all-traits.dex-factory-v2)

;; Implementation
(impl-trait .all-traits.router-trait)

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
(define-data-var factory principal .dex-factory-v2) ;; Updated to use dex-factory-v2
(define-data-var weth principal tx-sender) ;; Wrapped native token

;; Graph representation for pathfinding
(define-map token-graph
  { token: principal }
  { connections: (list 10 { connected-token: principal, pool: principal, weight: uint }) }
)

;; Route cache
(define-map route-cache
  { token-in: principal, token-out: principal, amount-in: uint }
  { path: (list 5 principal), amount-out: uint, price-impact: uint }
)

;; Error codes
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

(define-public (exact-input-multi-hop
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (min-amount-out uint)
  (path (list 5 { pool: principal, token-in: principal, token-out: principal }))
)
  (begin
    (asserts! (is-some (var-get factory)) ERR_FACTORY_NOT_SET)
    (asserts! (is-some (contract-of (var-get factory))) ERR_FACTORY_NOT_SET)

    (let (
      (current-amount amount-in)
      (current-token token-in)
      (final-amount u0)
      (actual-path (unwrap-panic (find-multi-hop-path token-in token-out amount-in)))
      (total-price-impact u0)
    )
      (map iter-path actual-path
        (let (
          (next-token (unwrap-panic (element-at iter-path u1)))
          (pool-contract (unwrap-panic (get-pool-address current-token next-token)))
        )
          (asserts! (is-some pool-contract) ERR_POOL_NOT_FOUND)
          (let (
            (swap-result (contract-call? pool-contract swap-exact-in current-amount current-token next-token))
            (reserves (contract-call? pool-contract get-reserves))
          )
            (asserts! (is-ok swap-result) (unwrap-err swap-result))
            (var-set total-price-impact (+ total-price-impact (calculate-price-impact
              current-amount
              (get amount-out (unwrap-panic swap-result))
              (get reserve-x reserves)
              (get reserve-y reserves)
            )))
            (var-set current-amount (get amount-out (unwrap-panic swap-result)))
            (var-set current-token next-token)
          )
        )
      )
      (var-set final-amount current-amount)
      (asserts! (>= final-amount min-amount-out) ERR_SLIPPAGE)
      (ok { amount-out: final-amount, price-impact: total-price-impact })
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
)
  (begin
    (asserts! (is-some (var-get factory)) ERR_FACTORY_NOT_SET)
    (asserts! (is-some (contract-of (var-get factory))) ERR_FACTORY_NOT_SET)

    (let (
      (current-amount amount-out)
      (current-token token-out)
      (final-amount u0)
      (actual-path (unwrap-panic (find-multi-hop-path token-in token-out amount-out)))
      (total-price-impact u0)
    )
      (map iter-path (reverse actual-path)
        (let (
          (prev-token (unwrap-panic (element-at iter-path u0)))
          (pool-contract (unwrap-panic (get-pool-address prev-token current-token)))
        )
          (asserts! (is-some pool-contract) ERR_POOL_NOT_FOUND)
          (let (
            (swap-result (contract-call? pool-contract swap-exact-out current-amount prev-token current-token))
            (reserves (contract-call? pool-contract get-reserves))
          )
            (asserts! (is-ok swap-result) (unwrap-err swap-result))
            (var-set total-price-impact (+ total-price-impact (calculate-price-impact
              (get amount-in (unwrap-panic swap-result))
              current-amount
              (get reserve-x reserves)
              (get reserve-y reserves)
            )))
            (var-set current-amount (get amount-in (unwrap-panic swap-result)))
            (var-set current-token prev-token)
          )
        )
      )
      (var-set final-amount current-amount)
      (asserts! (<= final-amount amount-in-max) ERR_SLIPPAGE)
      (ok { amount-in: final-amount, price-impact: total-price-impact })
    )
  )
)

;; Circuit breaker functions
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

(define-private (calculate-price-impact
  (amount-in uint)
  (amount-out uint)
  (reserve-in uint)
  (reserve-out uint)
)
  (let (
    (initial-price (/ (to-int reserve-out) (to-int reserve-in)))
    (new-reserve-in (+ reserve-in amount-in))
    (new-reserve-out (- reserve-out amount-out))
    (new-price (/ (to-int new-reserve-out) (to-int new-reserve-in)))
    (price-impact (/ (* (- initial-price new-price) u10000) initial-price))
  )
    price-impact
  )
)

(define-private (calculate-single-hop-amount
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
(define-public (set-factory (new-factory <dex-factory-v2-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set factory new-factory)
    (ok (build-token-graph))
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (contract-call? new-owner get-false) false) ERR_INVALID_PATH)
    (var-set contract-owner new-owner)
    (ok true)
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

(define-public (swap-exact-in (
  token-in <sip-010-trait>)
  (amount-in uint)
  (token-out <sip-010-trait>)
  (amount-out-min uint)
  (path (list 20 {pool-id uint, token-in principal, token-out principal}))
)
  (let (
    (current-amount amount-in)
    (last-token (contract-of token-in))
    (final-amount-out u0)
  )
    (asserts! (<= (len path) MAX_HOPS) ERR_EXCESSIVE_HOPS)

    (map iter-path path
      (match (get-pool-details (get pool-id iter-path))
        (some pool-data
          (let (
            (pool-contract (get pool-address pool-data))
            (input-token (get token-in iter-path))
            (output-token (get token-out iter-path))
          )
            (asserts! (is-eq last-token input-token) ERR_INVALID_PATH)

            ;; Transfer token-in to the pool
            (unwrap! (contract-call? input-token transfer current-amount tx-sender pool-contract) ERR_SWAP-FAILED)

            ;; Perform swap in the pool
            (let (
              (swap-result (contract-call? pool-contract swap input-token output-token current-amount))
            )
              (asserts! (is-ok swap-result) ERR_SWAP-FAILED)
              (let ((amount-received (unwrap-panic swap-result)))
                (asserts! (> amount-received u0) ERR_INSUFFICIENT_OUTPUT)
                (var-set current-amount amount-received)
                (var-set last-token output-token)
              )
            )
          )
        )
        (none (asserts! false ERR_POOL_NOT_FOUND))
      )
    )

    (var-set final-amount-out current-amount)
    (asserts! (is-eq last-token (contract-of token-out)) ERR_INVALID_PATH)
    (asserts! (>= final-amount-out amount-out-min) ERR_INSUFFICIENT_OUTPUT)

    ;; Transfer final token-out to tx-sender
    (unwrap! (contract-call? token-out transfer final-amount-out (contract-of token-out) tx-sender) ERR_SWAP-FAILED)

    (ok final-amount-out)
  )
)

(define-public (swap-exact-out (
  token-in <sip-010-trait>)
  (amount-in-max uint)
  (token-out <sip-010-trait>)
  (amount-out uint)
  (path (list 20 {pool-id uint, token-in principal, token-out principal}))
)
  (let (
    (current-amount-out amount-out)
    (last-token (contract-of token-out))
    (total-amount-in u0)
  )
    (asserts! (<= (len path) MAX_HOPS) ERR_EXCESSIVE_HOPS)

    ;; Iterate through the path in reverse for swap-exact-out
    (map iter-path (reverse path)
      (match (get-pool-details (get pool-id iter-path))
        (some pool-data
          (let (
            (pool-contract (get pool-address pool-data))
            (input-token (get token-in iter-path))
            (output-token (get token-out iter-path))
          )
            (asserts! (is-eq last-token output-token) ERR_INVALID_PATH)

            ;; Calculate amount-in required for current_amount_out
            (let (
              (swap-result (contract-call? pool-contract get-amount-in input-token output-token current-amount-out))
            )
              (asserts! (is-ok swap-result) ERR_SWAP-FAILED)
              (let ((amount-needed (unwrap-panic swap-result)))
                (asserts! (> amount-needed u0) ERR_INSUFFICIENT_OUTPUT)
                (var-set total-amount-in (+ total-amount-in amount-needed))
                (var-set current-amount-out amount-needed)
                (var-set last-token input-token)
              )
            )
          )
        )
        (none (asserts! false ERR_POOL_NOT_FOUND))
      )
    )

    (asserts! (is-eq last-token (contract-of token-in)) ERR_INVALID_PATH)
    (asserts! (<= total-amount-in amount-in-max) ERR_INSUFFICIENT_OUTPUT)

    ;; Transfer token-in from tx-sender to the first pool
    (unwrap! (contract-call? token-in transfer total-amount-in tx-sender (contract-of (element-at path u0))) ERR_SWAP-FAILED)

    ;; Execute the swaps
    (var-set current-amount-out amount-out)
    (var-set last-token (contract-of token-out))
    (map iter-path (reverse path)
      (match (get-pool-details (get pool-id iter-path))
        (some pool-data
          (let (
            (pool-contract (get pool-address pool-data))
            (input-token (get token-in iter-path))
            (output-token (get token-out iter-path))
          )
            (asserts! (is-eq last-token output-token) ERR_INVALID_PATH)

            ;; Perform swap in the pool
            (let (
              (swap-result (contract-call? pool-contract swap-exact-out input-token output-token current-amount-out))
            )
              (asserts! (is-ok swap-result) ERR_SWAP-FAILED)
              (let ((amount-received (unwrap-panic swap-result)))
                (asserts! (> amount-received u0) ERR_INSUFFICIENT_OUTPUT)
                (var-set current-amount-out amount-received)
                (var-set last-token input-token)
              )
            )
          )
        )
        (none (asserts! false ERR_POOL_NOT_FOUND))
      )
    )

    ;; Transfer final token-out to tx-sender
    (unwrap! (contract-call? token-out transfer amount-out (contract-of token-out) tx-sender) ERR_SWAP-FAILED)

    (ok total-amount-in)
  )
)

(define-private (find-multi-hop-path
  (from-token principal)
  (to-token principal)
  (amount-in uint)
)
  (begin
    ;; Check cache first
    (match (map-get? route-cache { token-in: from-token, token-out: to-token, amount-in: amount-in })
      cached-route
      (ok (get path cached-route))
      ;; If not in cache, compute and store
      (let (
        (distances (map { token: principal } { distance: uint, predecessor: (optional principal), pool: (optional principal) }))
        (unvisited (list 20 principal))
        (path (list 5 principal))
      )
        ;; Initialize distances
        (map-set distances { token: from-token } { distance: u0, predecessor: none, pool: none })
        (var-set unvisited (list from-token))

        ;; Dijkstra's algorithm
        (while (not (is-empty unvisited))
          (let (
            (current-token (unwrap-panic (element-at unvisited u0))) ;; Simple way to get next, not a true priority queue
            (min-distance u200000000000000000000000000000000000000) ;; Max uint
            (next-token-to-visit (err u0))
            (index-to-remove (some u0))
          )
            ;; Find token with smallest distance in unvisited set
            (map iter-token unvisited
              (let (
                (dist-info (map-get? distances { token: iter-token }))
                (current-index (index-of iter-token unvisited))
              )
                (if (and (is-some dist-info) (< (get distance (unwrap-panic dist-info)) min-distance))
                  (begin
                    (var-set min-distance (get distance (unwrap-panic dist-info)))
                    (var-set next-token-to-visit (ok iter-token))
                    (var-set index-to-remove current-index)
                  )
                  true
                )
              )
            )
            (asserts! (is-ok next-token-to-visit) ERR_ROUTE_NOT_FOUND)
            (var-set current-token (unwrap-panic next-token-to-visit))

            ;; Remove current-token from unvisited
            (var-set unvisited (list-replace-at unvisited (unwrap-panic index-to-remove) (unwrap-panic (element-at unvisited (- (len unvisited) u1)))))
            (var-set unvisited (list-take unvisited (- (len unvisited) u1)))

            (match (map-get? token-graph { token: current-token })
              connections-data
              (map iter-connection (get connections connections-data)
                (let (
                  (neighbor-token (get connected-token iter-connection))
                  (pool-address (get pool iter-connection))
                  (edge-weight (get weight iter-connection)) ;; This will be fee for now, later can be dynamic
                )
                  (let (
                    (current-dist (get distance (unwrap-panic (map-get? distances { token: current-token }))))
                    (neighbor-dist-info (map-get? distances { token: neighbor-token }))
                  )
                    (if (or (is-none neighbor-dist-info) (> current-dist (+ edge-weight (get distance (unwrap-panic neighbor-dist-info)))))
                      (begin
                        (map-set distances { token: neighbor-token } { distance: (+ current-dist edge-weight), predecessor: (some current-token), pool: (some pool-address) })
                        (if (is-none (find unvisited (lambda (t) (is-eq t neighbor-token))))
                          (var-set unvisited (append unvisited (list neighbor-token)))
                          true
                        )
                      )
                      true
                    )
                  )
                )
              )
              true
            )
          )
        )

        ;; Reconstruct path
        (let ((temp-path (list)))
          (var-set current-token to-token)
          (while (and (is-some (map-get? distances { token: current-token })) (not (is-eq current-token from-token)))
            (var-set temp-path (append (list current-token) temp-path))
            (var-set current-token (unwrap-panic (get predecessor (unwrap-panic (map-get? distances { token: current-token })))))
          )
          (var-set path (append (list from-token) temp-path))
        )

        ;; Store in cache before returning
        (map-set route-cache { token-in: from-token, token-out: to-token, amount-in: amount-in } { path: path, amount-out: u0, price-impact: u0 })
        (ok path)
      )
    )
  )
)

;; Circuit breaker functions
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

(define-private (calculate-price-impact
  (amount-in uint)
  (amount-out uint)
  (reserve-in uint)
  (reserve-out uint)
)
  (let (
    (initial-price (/ (to-int reserve-out) (to-int reserve-in)))
    (new-reserve-in (+ reserve-in amount-in))
    (new-reserve-out (- reserve-out amount-out))
    (new-price (/ (to-int new-reserve-out) (to-int new-reserve-in)))
    (price-impact (/ (* (- initial-price new-price) u10000) initial-price))
  )
    price-impact
  )
)

(define-private (calculate-single-hop-amount
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
(define-public (set-factory (new-factory <dex-factory-v2-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set factory new-factory)
    (ok (build-token-graph))
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (contract-call? new-owner get-false) false) ERR_INVALID_PATH)
    (var-set contract-owner new-owner)
    (ok true)
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

(define-public (swap-exact-in (
  token-in <sip-010-trait>)
  (amount-in uint)
  (token-out <sip-010-trait>)
  (amount-out-min uint)
  (path (list 20 {pool-id uint, token-in principal, token-out principal}))
)
  (let (
    (current-amount amount-in)
    (last-token (contract-of token-in))
    (final-amount-out u0)
  )
    (asserts! (<= (len path) MAX_HOPS) ERR_EXCESSIVE_HOPS)

    (map iter-path path
      (match (get-pool-details (get pool-id iter-path))
        (some pool-data
          (let (
            (pool-contract (get pool-address pool-data))
            (input-token (get token-in iter-path))
            (output-token (get token-out iter-path))
          )
            (asserts! (is-eq last-token input-token) ERR_INVALID_PATH)

            ;; Transfer token-in to the pool
            (unwrap! (contract-call? input-token transfer current-amount tx-sender pool-contract) ERR_SWAP-FAILED)

            ;; Perform swap in the pool
            (let (
              (swap-result (contract-call? pool-contract swap input-token output-token current-amount))
            )
              (asserts! (is-ok swap-result) ERR_SWAP-FAILED)
              (let ((amount-received (unwrap-panic swap-result)))
                (asserts! (> amount-received u0) ERR_INSUFFICIENT_OUTPUT)
                (var-set current-amount amount-received)
                (var-set last-token output-token)
              )
            )
          )
        )
        (none (asserts! false ERR_POOL_NOT_FOUND))
      )
    )

    (var-set final-amount-out current-amount)
    (asserts! (is-eq last-token (contract-of token-out)) ERR_INVALID_PATH)
    (asserts! (>= final-amount-out amount-out-min) ERR_INSUFFICIENT_OUTPUT)

    ;; Transfer final token-out to tx-sender
    (unwrap! (contract-call? token-out transfer final-amount-out (contract-of token-out) tx-sender) ERR_SWAP-FAILED)

    (ok final-amount-out)
  )
)

(define-public (swap-exact-out (
  token-in <sip-010-trait>)
  (amount-in-max uint)
  (token-out <sip-010-trait>)
  (amount-out uint)
  (path (list 20 {pool-id uint, token-in principal, token-out principal}))
)
  (let (
    (current-amount-out amount-out)
    (last-token (contract-of token-out))
    (total-amount-in u0)
  )
    (asserts! (<= (len path) MAX_HOPS) ERR_EXCESSIVE_HOPS)

    ;; Iterate through the path in reverse for swap-exact-out
    (map iter-path (reverse path)
      (match (get-pool-details (get pool-id iter-path))
        (some pool-data
          (let (
            (pool-contract (get pool-address pool-data))
            (input-token (get token-in iter-path))
            (output-token (get token-out iter-path))
          )
            (asserts! (is-eq last-token output-token) ERR_INVALID_PATH)

            ;; Calculate amount-in required for current_amount_out
            (let (
              (swap-result (contract-call? pool-contract get-amount-in input-token output-token current-amount-out))
            )
              (asserts! (is-ok swap-result) ERR_SWAP-FAILED)
              (let ((amount-needed (unwrap-panic swap-result)))
                (asserts! (> amount-needed u0) ERR_INSUFFICIENT_OUTPUT)
                (var-set total-amount-in (+ total-amount-in amount-needed))
                (var-set current-amount-out amount-needed)
                (var-set last-token input-token)
              )
            )
          )
        )
        (none (asserts! false ERR_POOL_NOT_FOUND))
      )
    )

    (asserts! (is-eq last-token (contract-of token-in)) ERR_INVALID_PATH)
    (asserts! (<= total-amount-in amount-in-max) ERR_INSUFFICIENT_OUTPUT)

    ;; Transfer token-in from tx-sender to the first pool
    (unwrap! (contract-call? token-in transfer total-amount-in tx-sender (contract-of (element-at path u0))) ERR_SWAP-FAILED)

    ;; Execute the swaps
    (var-set current-amount-out amount-out)
    (var-set last-token (contract-of token-out))
    (map iter-path (reverse path)
      (match (get-pool-details (get pool-id iter-path))
        (some pool-data
          (let (
            (pool-contract (get pool-address pool-data))
            (input-token (get token-in iter-path))
            (output-token (get token-out iter-path))
          )
            (asserts! (is-eq last-token output-token) ERR_INVALID_PATH)

            ;; Perform swap in the pool
            (let (
              (swap-result (contract-call? pool-contract swap-exact-out input-token output-token current-amount-out))
            )
              (asserts! (is-ok swap-result) ERR_SWAP-FAILED)
              (let ((amount-received (unwrap-panic swap-result)))
                (asserts! (> amount-received u0) ERR_INSUFFICIENT_OUTPUT)
                (var-set current-amount-out amount-received)
                (var-set last-token input-token)
              )
            )
          )
        )
        (none (asserts! false ERR_POOL_NOT_FOUND))
      )
    )

    ;; Transfer final token-out to tx-sender
    (unwrap! (contract-call? token-out transfer amount-out (contract-of token-out) tx-sender) ERR_SWAP-FAILED)

    (ok total-amount-in)
  )
)