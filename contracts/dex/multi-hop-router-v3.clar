;; @desc Advanced routing engine for optimal path finding across multiple DEX pools.
;; This contract acts as a facade, delegating calls to the dijkstra-pathfinder and route-manager contracts.

(use-trait dijkstra-pathfinder-trait .dijkstra-pathfinder-trait.dijkstra-pathfinder-trait)
(use-trait route-manager-trait .route-manager-trait.route-manager-trait)
(use-trait rbac-trait .base-traits.rbac-trait)

;; @data-vars
(define-data-var dijkstra-pathfinder principal .dijkstra-pathfinder)
(define-data-var route-manager principal .route-manager)

;; --- Public Functions ---
(define-public (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (contract-call? .dijkstra-pathfinder-trait compute-best-route token-in token-out amount-in)
)

(define-public (propose-route (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (route-timeout uint))
  (contract-call? .route-manager-trait propose-route token-in token-out amount-in min-amount-out route-timeout)
)

(define-public (execute-route (route-id uint) (min-amount-out uint) (recipient principal))
  (contract-call? .route-manager-trait execute-route route-id min-amount-out recipient)
)

(define-read-only (get-route-stats (route-id uint))
  (contract-call? .route-manager-trait get-route-stats route-id)
)

;; --- Admin Functions ---
(define-public (set-dijkstra-pathfinder (pathfinder principal))
  (begin
    (asserts! (is-ok (contract-call? .rbac-trait has-role "contract-owner")) (err u1001))
    (var-set dijkstra-pathfinder pathfinder)
    (ok true)
  )
)

(define-public (set-route-manager (manager principal))
  (begin
    (asserts! (is-ok (contract-call? .rbac-trait has-role "contract-owner")) (err u1001))
    (var-set route-manager manager)
    (ok true)
  )
)
