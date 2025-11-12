;; dim-graph.clar
;; Dimensional Graph Module
;; Responsibilities:
;; - Store adjacency lists and flow metrics between dimensions
;; - This contract allows for the analysis of risk contagion and net exposure.

;; ===== Constants =====
;; Standardized Conxian error codes (800-range for dimensional modules)
(define-constant ERR_UNAUTHORIZED u800)
(define-constant ERR_INVALID_DIMENSION u819)
(define-constant ERR_DIMENSION_DISABLED u807)
(define-constant ERR_SELF_EDGE u820)

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var writer-principal principal tx-sender)

;; ===== Data Maps =====
;; Stores flow metrics between dimensions
(define-map edge 
  {from-dim: uint, to-dim: uint} 
  {flow: uint, last-updated: uint}
)

;; Track enabled dimensions
(define-map dimension-enabled 
  {dim-id: uint} 
  {enabled: bool}
)

;; ===== Owner Functions =====
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-writer-principal (new-writer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set writer-principal new-writer)
    (ok true)
  )
)

(define-public (enable-dimension (dim-id uint) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set dimension-enabled
      {dim-id: dim-id}
      {enabled: enabled}
    )
    (ok true)
  )
)

;; ===== Writer Functions =====
;; @desc Sets the flow amount for an edge between two dimensions.
;; @param f: The from dimension ID.
;; @param t: The to dimension ID.
;; @param flow-amt: The flow amount.
;; @returns (response bool uint)
(define-public (set-edge (f uint) (t uint) (flow-amt uint))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) (err ERR_UNAUTHORIZED))
    (asserts! (not (is-eq f t)) (err ERR_SELF_EDGE))
    (asserts! (is-dimension-enabled f) (err ERR_DIMENSION_DISABLED))
    (asserts! (is-dimension-enabled t) (err ERR_DIMENSION_DISABLED))
    
    (map-set edge 
      {from-dim: f, to-dim: t} 
      {flow: flow-amt, last-updated: block-height}
    )
    (ok true)
  )
)

;; Batch update multiple edges
(define-public (set-edges (updates (list 20 {from-dim: uint, to-dim: uint, flow: uint})))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) (err ERR_UNAUTHORIZED))
    (fold set-edge-iter updates (ok true))
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-edge-flow (f uint) (t uint))
  (map-get? edge {from-dim: f, to-dim: t})
)

(define-read-only (is-dimension-enabled (dim-id uint))
  (default-to true (get enabled (map-get? dimension-enabled {dim-id: dim-id})))
)

;; ===== Private Functions =====
(define-private (set-edge-iter 
  (update {from-dim: uint, to-dim: uint, flow: uint}) 
  (prev-result (response bool uint))
)
  (begin
    (try! prev-result)
    (asserts! (not (is-eq (get from-dim update) (get to-dim update))) (err ERR_SELF_EDGE))
    (asserts! (is-dimension-enabled (get from-dim update)) (err ERR_DIMENSION_DISABLED))
    (asserts! (is-dimension-enabled (get to-dim update)) (err ERR_DIMENSION_DISABLED))
    
    (map-set edge
      {from-dim: (get from-dim update), to-dim: (get to-dim update)}
      {flow: (get flow update), last-updated: block-height}
    )
    (ok true)
  )
)
