;; @desc This contract is responsible for managing routes,
;; including proposing, executing, and getting statistics for routes.

(use-trait route-manager-trait .route-manager-trait.route-manager-trait)
(use-trait dijkstra-pathfinder-trait .dijkstra-pathfinder-trait.dijkstra-pathfinder-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

;; @constants
(define-constant ERR_INVALID_ROUTE (err u1400))
(define-constant ERR_ROUTE_NOT_FOUND (err u1401))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u1402))
(define-constant ERR_HOP_LIMIT_EXCEEDED (err u1403))
(define-constant ERR_ROUTE_EXPIRED (err u1405))

;; @data-vars
(define-data-var route-counter uint u0)
(define-data-var max-hops uint u5)
(define-data-var route-timeout uint u100)
(define-map routes {route-id: uint} {
  token-in: principal,
  token-out: principal,
  amount-in: uint,
  min-amount-out: uint,
  hops: (list 10 {pool: principal, token-in: principal, token-out: principal}),
  created-at: uint,
  expires-at: uint
})

;; --- Public Functions ---
(define-public (propose-route (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (route-timeout-param uint))
  (let (
    (current-route-id (var-get route-counter))
    (best-route-result (try! (contract-call? .dijkstra-pathfinder-trait compute-best-route token-in token-out amount-in)))
    (final-amount-out (get amount-out best-route-result))
    (path (get path best-route-result))
    (hops-count (len path))
  )
    (asserts! (> final-amount-out u0) ERR_ROUTE_NOT_FOUND)
    (asserts! (<= hops-count (var-get max-hops)) ERR_HOP_LIMIT_EXCEEDED)
    (asserts! (>= final-amount-out min-amount-out) ERR_INSUFFICIENT_OUTPUT)

    (map-set routes {route-id: current-route-id} {
      token-in: token-in,
      token-out: token-out,
      amount-in: amount-in,
      min-amount-out: min-amount-out,
      hops: path,
      created-at: block-height,
      expires-at: (+ block-height route-timeout-param)
    })
    (var-set route-counter (+ current-route-id u1))
    (ok current-route-id)
  )
)

(define-public (execute-route (route-id uint) (min-amount-out uint) (recipient principal))
  (let ((route (unwrap! (map-get? routes {route-id: route-id}) ERR_ROUTE_NOT_FOUND)))
    (asserts! (< block-height (get expires-at route)) ERR_ROUTE_EXPIRED)
    (let ((actual-amount-out (try! (execute-multi-hop-swap (get hops route) (get amount-in route) recipient))))
      (asserts! (>= actual-amount-out min-amount-out) ERR_INSUFFICIENT_OUTPUT)
      (map-delete routes {route-id: route-id})
      (ok actual-amount-out)
    )
  ))

(define-read-only (get-route-stats (route-id uint))
  (match (map-get? routes {route-id: route-id})
    route (ok {
      hops: (len (get hops route)),
      estimated-out: (get min-amount-out route),
      expires-at: (get expires-at route)
    })
    (err ERR_INVALID_ROUTE)
  )
)

;; --- Private Functions ---
(define-private (execute-multi-hop-swap (hops (list 10 {pool: principal, token-in: principal, token-out: principal})) (amount-in uint) (recipient principal))
  (fold (lambda (hop result)
    (match result
      (ok current-amount)
      (let (
        (current-pool (get pool hop))
        (next-recipient (if (is-eq hop (last hops)) recipient current-pool))
      )
        (contract-call? current-pool swap (get token-in hop) (get token-out hop) current-amount u0 next-recipient)
      )
      err-result
      err-result
    )
  ) hops (ok amount-in))
)
