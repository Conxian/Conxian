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

;; ---------------------------------------------------------
;; Constants
;; ---------------------------------------------------------;; --- Constants ---
(define-constant ERR_NO_PATH (err u4001))
(define-constant ERR_SLIPPAGE (err u4002))
(define-constant ERR_INVALID_HOP (err u4003))
(define-constant ERR_UNAUTHORIZED (err u4005))
(define-constant ERR_APPEND_FAILED (err u4004)) 

;; Data Variables
;; ---------------------------------------------------------
;; @desc Stores a list of common base tokens (e.g., STX, xBTC, USDA) used for
;; constructing multi-hop routes. Managed by the contract owner.
(define-data-var base-tokens (list 10 principal) (list))
(define-data-var contract-owner principal tx-sender)

;; ---------------------------------------------------------
;; Public Functions
;; ---------------------------------------------------------

;; @desc Register a base token for multi-hop routing (Admin only)
(define-public (add-base-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set base-tokens (unwrap! (as-max-len? (append (var-get base-tokens) token) u10) ERR_APPEND_FAILED))
    (ok true)
  )
)

;;
;; @desc Executes a direct swap (1-hop) through a specified liquidity pool.
;; @param amount-in The amount of the input token to be swapped.
;; @param min-amount-out The minimum amount of the output token to be received,
;; protecting against slippage.
;; @param pool A principal implementing the pool-trait.
;; @param token-in A principal implementing the sip-010-trait for the input token.
;; @param token-out A principal implementing the sip-010-trait for the output token.
;; @returns The amount of the output token received.
;;
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

;;
;; @desc Executes a 2-hop swap from an input token to an output token via a
;; single intermediate base token.
;; @param amount-in The amount of the input token.
;; @param min-amount-out The minimum amount of the output token to be received.
;; @param pool1 The liquidity pool for the first hop.
;; @param token-in The input token.
;; @param token-base The intermediate base token.
;; @param pool2 The liquidity pool for the second hop.
;; @param token-out The final output token.
;; @returns The final amount of the output token received.
;;
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

;;
;; @desc Executes a 3-hop swap from an input token to an output token via two
;; intermediate base tokens.
;; @param amount-in The amount of the input token.
;; @param min-amount-out The minimum amount of the output token to be received.
;; @param pool1 The liquidity pool for the first hop.
;; @param token-in The input token.
;; @param token-base1 The first intermediate base token.
;; @param pool2 The liquidity pool for the second hop.
;; @param token-base2 The second intermediate base token.
;; @param pool3 The liquidity pool for the third hop.
;; @param token-out The final output token.
;; @returns The final amount of the output token received.
;;
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

;;
;; @desc Note on Route Discovery: The design of this contract intentionally
;; delegates the route discovery process to off-chain clients (e.g., UI, SDK).
;; On-chain route discovery is computationally expensive and would significantly
;; increase gas costs. By providing efficient execution primitives for 1, 2, and
;; 3-hop swaps, this contract allows clients to find the optimal route off-chain
;; and submit the transaction for execution, ensuring both optimal pricing and
;; low transaction fees.
;;

