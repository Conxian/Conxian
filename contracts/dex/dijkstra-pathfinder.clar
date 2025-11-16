;; @desc This contract encapsulates all the logic for the Dijkstra's algorithm,
;; including initializing the data structures, finding the shortest path, and reconstructing the path.

(use-trait dijkstra-pathfinder-trait .dijkstra-pathfinder-trait.dijkstra-pathfinder-trait)
(use-trait dim-registry-trait .dim-registry-trait.dim-registry-trait)
(use-trait pool-trait .dex-traits.pool-trait)

(impl-trait .dijkstra-pathfinder-trait.dijkstra-pathfinder-trait)

;; @constants
(define-constant ERR_NO_PATH_FOUND (err u1407))
(define-constant ERR_DIJKSTRA_INIT_FAILED (err u1408))
(define-constant ERR_POOL_NOT_FOUND (err u1409))
(define-constant ERR_GET_AMOUNT_IN_FAILED (err u1410))
(define-constant UINT_MAX u340282366920938463463374607431768211455)

;; @data-vars
(define-data-var dim-registry principal tx-sender)
(define-map distances {token: principal} {cost: uint, amount-in: uint})
(define-map predecessors {token: principal} {prev-token: principal, pool: principal})

;; --- Public Functions ---
(define-read-only (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((all-tokens (try! (get-all-known-tokens))))
    (try! (initialize-dijkstra-data token-in all-tokens))
    (try! (dijkstra-loop (list) all-tokens))

    (let ((path (try! (reconstruct-path token-in token-out))))
      (let ((final-amount-out (try! (calculate-path-amount-out path amount-in))))
        (ok {path: path, amount-out: final-amount-out})
      )
    )
  )
)

;; --- Private Functions ---
(define-private (get-all-known-tokens)
  (contract-call? .dim-registry-trait get-all-tokens)
)

(define-private (initialize-dijkstra-data (start-token principal) (all-tokens (list 20 principal)))
  (begin
    (map-set distances {token: start-token} {cost: u0, amount-in: u0})
    (fold (lambda (token) (if (not (is-eq token start-token)) (map-set distances {token: token} {cost: UINT_MAX, amount-in: u0}) true)) all-tokens)
    (ok true)
  )
)

(define-private (dijkstra-loop (visited-tokens (list 20 principal)) (all-tokens (list 20 principal)))
  (let ((current-node-option (get-unvisited-min-distance-node visited-tokens all-tokens)))
    (if (is-none current-node-option)
      (ok true)
      (let ((current-node (unwrap-panic current-node-option)))
        (let ((neighbors (try! (get-neighbors current-node))))
          (fold (lambda (neighbor-info) (update-distance current-node neighbor-info)) neighbors)
        )
        (dijkstra-loop (append visited-tokens current-node) all-tokens)
      )
    )
  )
)

(define-private (get-unvisited-min-distance-node (visited (list 20 principal)) (all-tokens (list 20 principal)))
  (fold (lambda (token current-min-node)
    (if (not (is-some (index-of visited token)))
      (let ((current-distance (get cost (unwrap-panic (map-get? distances {token: token})))))
        (if (is-none current-min-node)
          (some token)
          (let ((min-node-distance (get cost (unwrap-panic (map-get? distances {token: (unwrap-panic current-min-node)})))))
            (if (< current-distance min-node-distance)
              (some token)
              current-min-node
            )
          )
        )
      )
      current-min-node
    )
  ) all-tokens)
)

(define-private (get-neighbors (current-token principal))
  (contract-call? .dim-registry-trait get-neighbors current-token)
)

(define-private (update-distance (current-node principal) (neighbor-info {token: principal, pool: principal}))
  (let (
    (neighbor-token (get token neighbor-info))
    (pool-contract (get pool neighbor-info))
    (current-distance-entry (unwrap-panic (map-get? distances {token: current-node})))
    (current-amount (get amount-in current-distance-entry))
  )
    (match (contract-call? .pool-trait get-amount-in (get token-in neighbor-info) neighbor-token current-amount)
      (ok traversal-cost)
      (let ((new-distance (+ (get cost current-distance-entry) traversal-cost)))
        (if (< new-distance (get cost (unwrap-panic (map-get? distances {token: neighbor-token}))))
          (begin
            (map-set distances {token: neighbor-token} {cost: new-distance, amount-in: current-amount})
            (map-set predecessors {token: neighbor-token} {prev-token: current-node, pool: pool-contract})
          )
          true
        )
      )
      (err e) true
    )
  )
)

(define-private (reconstruct-path (token-in principal) (token-out principal))
  (let ((path (list)))
    (let ((current-token token-out))
      (while (and (not (is-eq current-token token-in)) (is-some (map-get? predecessors {token: current-token})))
        (let ((prev-info (unwrap-panic (map-get? predecessors {token: current-token}))))
          (var-set path (cons {pool: (get pool prev-info), token-in: (get prev-token prev-info), token-out: current-token} path))
          (var-set current-token (get prev-token prev-info))
        )
      )
      (if (is-eq current-token token-in)
        (ok path)
        (err ERR_NO_PATH_FOUND)
      )
    )
  )
)

(define-private (calculate-path-amount-out (path (list 10 {pool: principal, token-in: principal, token-out: principal})) (amount-in uint))
  (fold (lambda (hop current-input-amount)
    (unwrap-panic (contract-call? (get pool hop) get-amount-out (get token-in hop) (get token-out hop) current-input-amount))
  ) path amount-in)
)
