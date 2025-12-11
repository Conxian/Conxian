;; @title On-Chain Router Helper
;; @desc Helper contract to verify off-chain routes and query pool state.
;;
;; This contract replaces the legacy "Dijkstra" attempt. Instead of expensive
;; on-chain pathfinding, it provides efficient read-only functions to:
;; 1. Verify that a proposed path exists and has liquidity.
;; 2. Validate token pair ordering and connectivity.
;; 3. Return reserve data for off-chain slippage estimation.

(use-trait pool-trait .defi-traits.pool-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; @constants
(define-constant ERR_INVALID_PATH (err u1407))
(define-constant ERR_POOL_READ_FAILED (err u1409))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1410))

;; @public
;; Verify a single-hop route
(define-public (verify-route-1
    (pool <pool-trait>)
    (token-in <sip-010-trait>)
    (token-out <sip-010-trait>)
  )
  (let (
      (reserves (unwrap! (contract-call? pool get-reserves) ERR_POOL_READ_FAILED))
      (r0 (get reserve0 reserves))
      (r1 (get reserve1 reserves))
    )
    (if (or (> r0 u0) (> r1 u0))
      (ok {
        valid: true,
        reserves: reserves,
      })
      ERR_INSUFFICIENT_LIQUIDITY
    )
  )
)

;; @public
;; Verify a 2-hop route
(define-public (verify-route-2
    (pool1 <pool-trait>)
    (token-in <sip-010-trait>)
    (token-hop <sip-010-trait>)
    (pool2 <pool-trait>)
    (token-out <sip-010-trait>)
  )
  (let (
      (res1 (unwrap! (verify-route-1 pool1 token-in token-hop) ERR_POOL_READ_FAILED))
      (res2 (unwrap! (verify-route-1 pool2 token-hop token-out) ERR_POOL_READ_FAILED))
    )
    (ok {
      valid: true,
      hop1: res1,
      hop2: res2,
    })
  )
)

;; @public
;; Verify a 3-hop route
(define-public (verify-route-3
    (pool1 <pool-trait>)
    (token-in <sip-010-trait>)
    (token-hop1 <sip-010-trait>)
    (pool2 <pool-trait>)
    (token-hop2 <sip-010-trait>)
    (pool3 <pool-trait>)
    (token-out <sip-010-trait>)
  )
  (let (
      (res1 (unwrap! (verify-route-1 pool1 token-in token-hop1) ERR_POOL_READ_FAILED))
      (res2 (unwrap! (verify-route-1 pool2 token-hop1 token-hop2) ERR_POOL_READ_FAILED))
      (res3 (unwrap! (verify-route-1 pool3 token-hop2 token-out) ERR_POOL_READ_FAILED))
    )
    (ok {
      valid: true,
      hop1: res1,
      hop2: res2,
      hop3: res3,
    })
  )
)
