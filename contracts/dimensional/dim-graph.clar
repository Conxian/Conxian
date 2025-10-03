;; dim-graph.clar
;; Dimensional Graph Module
;; Responsibilities:
;; - Store adjacency lists and flow metrics between dimensions
;;
;; This contract allows for the analysis of risk contagion and net exposure.

(define-constant ERR_UNAUTHORIZED u101)

(define-data-var contract-owner principal tx-sender)
(define-data-var writer-principal principal tx-sender)

(define-map edge {from-dim: uint, to-dim: uint} {flow: uint})

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-writer-principal (new-writer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set writer-principal new-writer)
    (ok true)))

(define-read-only (get-edge-flow (f uint) (t uint))
  (map-get? edge {from-dim: f, to-dim: t}))

;; @desc Sets the flow amount for an edge between two dimensions.
;; @param f: The from dimension ID.
;; @param t: The to dimension ID.
;; @param flow-amt: The flow amount.
;; @returns (response (tuple (from uint) (to uint) (flow uint)) uint)
(define-public (set-edge (f uint) (t uint) (flow-amt uint))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) (err ERR_UNAUTHORIZED))
    (map-set edge {from-dim: f, to-dim: t} {flow: flow-amt})
    (ok (tuple (from f) (to t) (flow flow-amt)))))






