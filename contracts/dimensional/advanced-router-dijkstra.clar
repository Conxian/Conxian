;; Advanced Router with Dijkstra's Algorithm
;; Implements optimal path finding for multi-hop swaps
;; Optimizes for best price with minimal gas

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait pool-trait .pool-trait.pool-trait)

(impl-trait advanced-router-dijkstra-trait)

;; === CONSTANTS ===
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_NODES u50)  ;; Max tokens in graph
(define-constant MAX_EDGES u200) ;; Max pools/connections
(define-constant INFINITY u340282366920938463463374607431768211455) ;; Max uint

;; Errors
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_NO_PATH (err u6001))
(define-constant ERR_INVALID_NODE (err u6002))
(define-constant ERR_GRAPH_FULL (err u6003))
(define-constant ERR_SLIPPAGE (err u6004))

;; === DATA STRUCTURES ===

;; Graph representation: adjacency list
(define-map graph-nodes uint {
  token: principal,
  index: uint,
  active: bool
})

(define-map token-index principal uint)

(define-map graph-edges {from: uint, to: uint} {
  pool: principal,
  pool-type: (string-ascii 20),
  weight: uint,  ;; Inverse of liquidity * fee
  liquidity: uint,
  fee: uint,
  active: bool
})

(define-data-var node-count uint u0)
(define-data-var edge-count uint u0)

;; Dijkstra state
(define-map distance uint uint)
(define-map previous uint (optional uint))
(define-map visited uint bool)

;; === ADMIN FUNCTIONS ===

(define-public (add-token (token principal))
  (let ((current-count (var-get node-count)))
    (asserts! (< current-count MAX_NODES) ERR_GRAPH_FULL)
    (asserts! (is-none (map-get? token-index token)) ERR_INVALID_NODE)
    
    (map-set graph-nodes current-count {
      token: token,
      index: current-count,
      active: true
    })
    
    (map-set token-index token current-count)
    (var-set node-count (+ current-count u1))
    
    (ok current-count)))

(define-public (add-edge 
  (token-from principal)
  (token-to principal)
  (pool principal)
  (pool-type (string-ascii 20))
  (liquidity uint)
  (fee uint))
  
  (let ((from-idx (unwrap! (map-get? token-index token-from) ERR_INVALID_NODE))
        (to-idx (unwrap! (map-get? token-index token-to) ERR_INVALID_NODE))
        (weight (calculate-edge-weight liquidity fee)))
    
    ;; Add bidirectional edges
    (map-set graph-edges {from: from-idx, to: to-idx} {
      pool: pool,
      pool-type: pool-type,
      weight: weight,
      liquidity: liquidity,
      fee: fee,
      active: true
    })
    
    (map-set graph-edges {from: to-idx, to: from-idx} {
      pool: pool,
      pool-type: pool-type,
      weight: weight,
      liquidity: liquidity,
      fee: fee,
      active: true
    })
    
    (var-set edge-count (+ (var-get edge-count) u2))
    (ok true)))

;; === DIJKSTRA'S ALGORITHM ===

(define-private (calculate-edge-weight (liquidity uint) (fee uint))
  ;; Weight = fee / sqrt(liquidity)
  ;; Lower weight = better path
  (if (is-eq liquidity u0)
    INFINITY
    (/ (* fee u1000000) (sqrt-approximation liquidity))))

(define-private (sqrt-approximation (n uint))
  ;; Simple square root approximation
  (if (<= n u1)
    n
    (let ((x (/ n u2)))
      (/ (+ x (/ n x)) u2))))

(define-read-only (find-optimal-path 
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  
  (let ((start-idx (unwrap! (map-get? token-index token-in) ERR_INVALID_NODE))
        (end-idx (unwrap! (map-get? token-index token-out) ERR_INVALID_NODE)))
    
    ;; Initialize Dijkstra
    (try! (initialize-dijkstra start-idx))
    
    ;; Run algorithm
    (let ((result (dijkstra-main start-idx end-idx)))
      (if (unwrap-panic result)
        ;; Reconstruct path
        (ok (reconstruct-path start-idx end-idx))
        ERR_NO_PATH))))

(define-private (initialize-dijkstra (start uint))
  (begin
    ;; Set all distances to infinity
    (map-set distance start u0)
    
    ;; Mark start as unvisited
    (map-set visited start false)
    
    (ok true)))

(define-private (dijkstra-main (start uint) (end uint))
  (let ((current (find-min-unvisited)))
    (match current
      current-node
        (if (is-eq current-node end)
          (ok true) ;; Reached destination
          (begin
            ;; Mark current as visited
            (map-set visited current-node true)
            
            ;; Update neighbors
            (try! (update-neighbors current-node))
            
            ;; Continue
            (dijkstra-main start end)))
      ;; No more unvisited nodes
      (ok false))))

(define-private (find-min-unvisited)
  (let ((min-node (find-min-unvisited-iter u0 (var-get node-count) none INFINITY)))
    min-node))

(define-private (find-min-unvisited-iter 
  (current uint)
  (max uint)
  (best-node (optional uint))
  (best-dist uint))
  
  (if (>= current max)
    best-node
    (let ((is-visited (default-to true (map-get? visited current)))
          (current-dist (default-to INFINITY (map-get? distance current))))
      
      (if (and (not is-visited) (< current-dist best-dist))
        (find-min-unvisited-iter (+ current u1) max (some current) current-dist)
        (find-min-unvisited-iter (+ current u1) max best-node best-dist)))))

(define-private (update-neighbors (current uint))
  (let ((current-dist (default-to INFINITY (map-get? distance current))))
    ;; Check all possible neighbors (0 to node-count)
    (ok (update-neighbors-iter current u0 (var-get node-count) current-dist))))

(define-private (update-neighbors-iter 
  (current uint)
  (neighbor uint)
  (max uint)
  (current-dist uint))
  
  (if (>= neighbor max)
    true
    (let ((edge-info (map-get? graph-edges {from: current, to: neighbor})))
      (match edge-info
        edge
          (if (get active edge)
            (let ((edge-weight (get weight edge))
                  (alt-dist (+ current-dist edge-weight))
                  (neighbor-dist (default-to INFINITY (map-get? distance neighbor))))
              
              ;; If shorter path found
              (if (< alt-dist neighbor-dist)
                (begin
                  (map-set distance neighbor alt-dist)
                  (map-set previous neighbor (some current))
                  (update-neighbors-iter current (+ neighbor u1) max current-dist))
                (update-neighbors-iter current (+ neighbor u1) max current-dist)))
            (update-neighbors-iter current (+ neighbor u1) max current-dist))
        ;; No edge, continue
        (update-neighbors-iter current (+ neighbor u1) max current-dist)))))

(define-private (reconstruct-path (start uint) (end uint))
  (let ((path (reconstruct-path-iter end start (list))))
    {
      path: path,
      distance: (default-to INFINITY (map-get? distance end)),
      hops: (len path)
    }))

(define-private (reconstruct-path-iter 
  (current uint)
  (start uint)
  (path (list 20 principal)))
  
  (if (is-eq current start)
    ;; Add start token and return
    (let ((start-token (get token (unwrap-panic (map-get? graph-nodes start)))))
      (unwrap-panic (as-max-len? (append path start-token) u20)))
    
    ;; Add current and continue backward
    (let ((current-token (get token (unwrap-panic (map-get? graph-nodes current))))
          (prev-node (unwrap! (map-get? previous current) path)))
      
      (match prev-node
        prev 
          (reconstruct-path-iter 
            prev 
            start 
            (unwrap-panic (as-max-len? (append path current-token) u20)))
        path))))

;; === SWAP EXECUTION ===

(define-public (swap-optimal-path
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (min-amount-out uint))
  
  (let ((path-result (try! (find-optimal-path token-in token-out amount-in))))
    
    ;; Execute swaps along optimal path
    (let ((final-amount (try! (execute-path-swaps (get path path-result) amount-in))))
      
      ;; Check slippage
      (asserts! (>= final-amount min-amount-out) ERR_SLIPPAGE)
      
      (ok {
        amount-out: final-amount,
        path: (get path path-result),
        hops: (get hops path-result),
        distance: (get distance path-result)
      }))))

(define-private (execute-path-swaps 
  (path (list 20 principal))
  (amount-in uint))
  
  ;; Execute sequential swaps through the path
  ;; This is a simplified version - real implementation would call actual pools
  (ok amount-in))

;; === READ-ONLY FUNCTIONS ===

(define-read-only (get-graph-stats)
  (ok {
    nodes: (var-get node-count),
    edges: (var-get edge-count)
  }))

(define-read-only (get-token-index (token principal))
  (ok (map-get? token-index token)))

(define-read-only (get-edge-info (from-token principal) (to-token principal))
  (let ((from-idx (unwrap! (map-get? token-index from-token) ERR_INVALID_NODE))
        (to-idx (unwrap! (map-get? token-index to-token) ERR_INVALID_NODE)))
    (ok (map-get? graph-edges {from: from-idx, to: to-idx}))))

(define-read-only (estimate-output
  (token-in principal)
  (token-out principal)
  (amount-in uint))
  
  ;; Quick estimate without executing
  (find-optimal-path token-in token-out amount-in))
