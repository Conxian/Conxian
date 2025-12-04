;;
;; @title Multi-Hop Router v3
;; @author Conxian Protocol
;; @desc Provides a robust and gas-efficient routing engine for executing
;; multi-hop swaps across various liquidity pools. This contract supports 1-hop,
;; 2-hop, and 3-hop swaps, allowing users to find the best possible exchange
;; rates by routing trades through intermediate base tokens. The design relies on
;; off-chain route discovery to minimize on-chain computation costs.
;;

(use-trait pool-trait .defi-traits.pool-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; @constants
(define-constant ERR_NO_PATH (err u4001))
(define-constant ERR_SLIPPAGE (err u4002))
(define-constant ERR_INVALID_HOP (err u4003))
(define-constant ERR_UNAUTHORIZED (err u4005))

;; @data-vars
;; Register of common base tokens for intermediate hops (e.g., STX, xBTC, USDA)
(define-data-var base-tokens (list 10 principal) (list))
(define-data-var contract-owner principal tx-sender)

;; @public-functions

;; @desc Register a base token for multi-hop routing (Admin only)
(define-public (add-base-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set base-tokens (unwrap! (as-max-len? (append (var-get base-tokens) token) u10) (err u4004)))
    (ok true)
  )
)

;; @desc Execute a direct swap (1-hop)
(define-public (swap-direct 
    (amount-in uint)
    (min-amount-out uint)
    (pool <pool-trait>)
    (token-in <sip-010-trait>)
    (token-out <sip-010-trait>)
  )
  (let ((amount-out (try! (contract-call? pool swap amount-in token-in token-out))))
    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE)
    (ok amount-out)
  )
)

;; @desc Execute a 2-hop swap (Token A -> Base -> Token B)
(define-public (swap-2-hop
    (amount-in uint)
    (min-amount-out uint)
    (pool1 <pool-trait>)
    (token-in <sip-010-trait>)
    (token-base <sip-010-trait>)
    (pool2 <pool-trait>)
    (token-out <sip-010-trait>)
  )
  (let (
    (amt1 (try! (contract-call? pool1 swap amount-in token-in token-base)))
    (amt2 (try! (contract-call? pool2 swap amt1 token-base token-out)))
  )
    (asserts! (>= amt2 min-amount-out) ERR_SLIPPAGE)
    (ok amt2)
  )
)

;; @desc Execute a 3-hop swap (Token A -> Base1 -> Base2 -> Token B)
(define-public (swap-3-hop
    (amount-in uint)
    (min-amount-out uint)
    (pool1 <pool-trait>)
    (token-in <sip-010-trait>)
    (token-base1 <sip-010-trait>)
    (pool2 <pool-trait>)
    (token-base2 <sip-010-trait>)
    (pool3 <pool-trait>)
    (token-out <sip-010-trait>)
  )
  (let (
    (amt1 (try! (contract-call? pool1 swap amount-in token-in token-base1)))
    (amt2 (try! (contract-call? pool2 swap amt1 token-base1 token-base2)))
    (amt3 (try! (contract-call? pool3 swap amt2 token-base2 token-out)))
  )
    (asserts! (>= amt3 min-amount-out) ERR_SLIPPAGE)
    (ok amt3)
  )
)

;; @desc Find the best route (Off-chain helper or limited on-chain discovery)
;; Since on-chain discovery of all pools is expensive, this function relies on
;; the caller (UI/SDK) to provide the pools, OR it iterates through a known registry.
;; For "Advanced" behavior, we can simulate checking 1-hop vs 2-hop if we have a factory reference.
;; Here we provide the execution primitives which was the core missing piece.

