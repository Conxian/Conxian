;;
;; @title Multi-Hop Router v3 (Facade)
;; @author Conxian Protocol
;; @desc This contract is the primary user-facing entry point for all swaps
;; within the Conxian Protocol. It is designed as a stateless facade that
;; delegates all swap logic to a specialized `swap-manager` contract.
;;
;; This design separates the user-facing API from the core business logic,
;; improving security and maintainability. For optimal swaps, it is
;; recommended to discover the best route (1-hop, 2-hop, or 3-hop) off-chain
;; before calling the appropriate function.
;;

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait pool-trait .defi-traits.pool-trait)

;; Constants
(define-constant ERR-UNAUTHORIZED (err u4005))
(define-constant ERR-PROTOCOL-PAUSED (err u5001))

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var swap-manager principal tx-sender)
(define-data-var protocol-coordinator principal tx-sender)

;; @desc Checks if the protocol is paused.
;; @returns A boolean indicating if the protocol is paused.
(define-private (is-protocol-paused)
  (unwrap! (contract-call? .conxian-protocol is-protocol-paused) true)
)

;; @desc Sets the contract owner.
;; @param new-owner The principal of the new owner.
;; @returns Ok true on success, Err if not authorized.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Sets the swap manager contract.
;; @param new-manager The principal of the swap manager contract.
;; @returns Ok true on success, Err if not authorized.
(define-public (set-swap-manager (new-manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set swap-manager new-manager)
    (ok true)
  )
)

;; @desc Sets the protocol coordinator contract.
;; @param new-coordinator The principal of the protocol coordinator contract.
;; @returns Ok true on success, Err if not authorized.
(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)

;; @desc Executes a direct swap by delegating the call to the Swap Manager.
;; @param amount-in The amount of the input token.
;; @param min-amount-out The minimum amount of the output token expected.
;; @param pool The pool to swap through.
;; @param token-in The input token.
;; @param token-out The output token.
;; @returns Ok with the amount out on success, Err otherwise.
(define-public (swap-direct
    (amount-in uint)
    (min-amount-out uint)
    (pool <pool-trait>)
    (token-in <sip-010-trait>)
    (token-out <sip-010-trait>)
  )
  (begin
    (asserts! (not (is-protocol-paused)) ERR-PROTOCOL-PAUSED)
    (contract-call? .swap-manager swap-direct amount-in min-amount-out pool
      token-in token-out
    )
  )
)

;; @desc Executes a 2-hop swap by delegating the call to the Swap Manager.
;; @param amount-in The amount of the input token.
;; @param min-amount-out The minimum amount of the output token expected.
;; @param pool1 The first pool to swap through.
;; @param token-in The input token.
;; @param token-base The intermediate token.
;; @param pool2 The second pool to swap through.
;; @param token-out The output token.
;; @returns Ok with the amount out on success, Err otherwise.
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
    (asserts! (not (is-protocol-paused)) ERR-PROTOCOL-PAUSED)
    (contract-call? .swap-manager swap-2-hop amount-in min-amount-out pool1
      token-in token-base pool2 token-out
    )
  )
)

;; @desc Executes a 3-hop swap by delegating the call to the Swap Manager.
;; @param amount-in The amount of the input token.
;; @param min-amount-out The minimum amount of the output token expected.
;; @param pool1 The first pool to swap through.
;; @param token-in The input token.
;; @param token-base1 The first intermediate token.
;; @param pool2 The second pool to swap through.
;; @param token-base2 The second intermediate token.
;; @param pool3 The third pool to swap through.
;; @param token-out The output token.
;; @returns Ok with the amount out on success, Err otherwise.
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
    (asserts! (not (is-protocol-paused)) ERR-PROTOCOL-PAUSED)
    (contract-call? .swap-manager swap-3-hop amount-in min-amount-out pool1
      token-in token-base1 pool2 token-base2 pool3 token-out
    )
  )
)
