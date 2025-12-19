;;
;; @title Multi-Hop Router v3 (Execution Facade)
;; @author Conxian Protocol
;; @desc This contract is the central execution facade for the DEX module. It
;; provides a unified and gas-efficient interface for performing swaps across
;; one or more liquidity pools (1-hop, 2-hop, and 3-hop). The contract is
;; responsible for executing the swap logic but relies on off-chain clients to
;; discover the optimal trading route before execution.
;;

(use-trait pool-trait .defi-traits.pool-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait protocol-support-trait .core-traits.protocol-support-trait)

;; ---------------------------------------------------------
;; Constants
;; ---------------------------------------------------------;; --- Constants ---
(define-constant ERR_NO_PATH (err u4001))
(define-constant ERR_SLIPPAGE (err u4002))
(define-constant ERR_INVALID_HOP (err u4003))
(define-constant ERR_UNAUTHORIZED (err u4005))
(define-constant ERR_APPEND_FAILED (err u4004))
(define-constant ERR_PROTOCOL_PAUSED (err u5001))

;; Data Variables
;; ---------------------------------------------------------
;; @desc Stores a list of common base tokens (e.g., STX, xBTC, USDA) used for
;; constructing multi-hop routes. Managed by the contract owner.
(define-data-var base-tokens (list 10 principal) (list))
(define-data-var contract-owner principal tx-sender)
(define-data-var protocol-coordinator principal tx-sender)

(define-private (is-protocol-paused)
  (contract-call? .conxian-protocol is-protocol-paused)
)

;; ---------------------------------------------------------
;; Public Functions
;; ---------------------------------------------------------

;; @desc Register a base token for multi-hop routing (Admin only)
(define-public (add-base-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set base-tokens
      (unwrap! (as-max-len? (append (var-get base-tokens) token) u10)
        ERR_APPEND_FAILED
      ))
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
(define-data-var swap-manager principal tx-sender)

(define-public (set-swap-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set swap-manager manager)
    (ok true)
  )
)

(define-public (swap-direct
    (amount-in uint)
    (min-amount-out uint)
    (pool <pool-trait>)
    (token-in <sip-010-trait>)
    (token-out <sip-010-trait>)
  )
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? .swap-manager swap-direct amount-in min-amount-out pool
      token-in token-out
    )
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
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? .swap-manager swap-2-hop amount-in min-amount-out pool1
      token-in token-base pool2 token-out
    )
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
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? .swap-manager swap-3-hop amount-in min-amount-out pool1
      token-in token-base1 pool2 token-base2 pool3 token-out
    )
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

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-contract-owner) (err u1000))
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)
