;; @desc Advanced routing engine for optimal path finding across multiple DEX pools.
;; This contract acts as a facade, delegating calls to the dijkstra-pathfinder and route-manager contracts.

;; Temporarily remove traits until available
;; (use-trait dijkstra-pathfinder-trait .dijkstra-pathfinder-trait.dijkstra-pathfinder-trait)
;; (use-trait route-manager-trait .route-manager-trait.route-manager-trait)
;; (use-trait rbac-trait .core-protocol.rbac-trait)


;; @data-vars
(define-data-var dijkstra-pathfinder principal .dijkstra-pathfinder)
(define-data-var route-manager principal .route-manager)

;; --- Public Functions ---
(define-public (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (contract-call? .dimensional-advanced-router-dijkstra compute-best-route token-in
    token-out amount-in
  )
)

(define-public (propose-route (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (route-timeout uint))
  ;; Temporarily disabled until route-manager contract exists
(ok u0)
)

(define-public (execute-route (route-id uint) (min-amount-out uint) (recipient principal))
  ;; Temporarily disabled until route-manager contract exists
(ok true)
)

(define-read-only (get-route-stats (route-id uint))
  ;; Temporarily disabled until route-manager contract exists
(ok {
    total-routes: u0,
    success-rate: u0,
  })
)

;; --- Admin Functions ---
(define-public (set-dijkstra-pathfinder (pathfinder principal))
  (begin
    (asserts! (is-ok (contract-call? .roles has-role "contract-owner" tx-sender))
      (err u1001)
    )
    (var-set dijkstra-pathfinder pathfinder)
    (ok true)
  )
)

(define-public (set-route-manager (manager principal))
  (begin
    (asserts! (is-ok (contract-call? .roles has-role "contract-owner" tx-sender))
      (err u1001)
    )
    (var-set route-manager manager)
    (ok true)
  )
)
