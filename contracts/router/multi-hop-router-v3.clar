;; Multi-Hop Router V3
;; Production-grade routing engine with support for up to 4 hops.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait pool-trait .defi-traits.pool-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_PATH (err u1001))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u1002))
(define-constant ERR_SWAP_FAILED (err u1003))

;; --- Public Functions ---

;; @desc Swap 1 hop
;; @param amount-in Amount in
;; @param min-amount-out Minimum amount out
;; @param pool Pool trait
;; @param token-in Token in trait
;; @param token-out Token out trait
(define-public (swap-hop-1
    (amount-in uint)
    (min-amount-out uint)
    (pool <pool-trait>)
    (token-in <sip-010-trait>)
    (token-out <sip-010-trait>)
)
    (let (
        (swap-res (try! (contract-call? pool swap amount-in (contract-of token-in))))
    )
        (asserts! (>= swap-res min-amount-out) ERR_SLIPPAGE_EXCEEDED)
        (ok swap-res)
    )
)

;; @desc Swap 2 hops
(define-public (swap-hop-2
    (amount-in uint)
    (min-amount-out uint)
    (pool1 <pool-trait>)
    (token1 <sip-010-trait>)
    (pool2 <pool-trait>)
    (token2 <sip-010-trait>)
    (token3 <sip-010-trait>)
)
    (let (
        (amt1 (try! (contract-call? pool1 swap amount-in (contract-of token1))))
        (amt2 (try! (contract-call? pool2 swap amt1 (contract-of token2))))
    )
        (asserts! (>= amt2 min-amount-out) ERR_SLIPPAGE_EXCEEDED)
        (ok amt2)
    )
)

;; @desc Swap 3 hops
(define-public (swap-hop-3
    (amount-in uint)
    (min-amount-out uint)
    (pool1 <pool-trait>)
    (token1 <sip-010-trait>)
    (pool2 <pool-trait>)
    (token2 <sip-010-trait>)
    (pool3 <pool-trait>)
    (token3 <sip-010-trait>)
    (token4 <sip-010-trait>)
)
    (let (
        (amt1 (try! (contract-call? pool1 swap amount-in (contract-of token1))))
        (amt2 (try! (contract-call? pool2 swap amt1 (contract-of token2))))
        (amt3 (try! (contract-call? pool3 swap amt2 (contract-of token3))))
    )
        (asserts! (>= amt3 min-amount-out) ERR_SLIPPAGE_EXCEEDED)
        (ok amt3)
    )
)

;; @desc Swap 4 hops
(define-public (swap-hop-4
    (amount-in uint)
    (min-amount-out uint)
    (pool1 <pool-trait>)
    (token1 <sip-010-trait>)
    (pool2 <pool-trait>)
    (token2 <sip-010-trait>)
    (pool3 <pool-trait>)
    (token3 <sip-010-trait>)
    (pool4 <pool-trait>)
    (token4 <sip-010-trait>)
    (token5 <sip-010-trait>)
)
    (let (
        (amt1 (try! (contract-call? pool1 swap amount-in (contract-of token1))))
        (amt2 (try! (contract-call? pool2 swap amt1 (contract-of token2))))
        (amt3 (try! (contract-call? pool3 swap amt2 (contract-of token3))))
        (amt4 (try! (contract-call? pool4 swap amt3 (contract-of token4))))
    )
        (asserts! (>= amt4 min-amount-out) ERR_SLIPPAGE_EXCEEDED)
        (ok amt4)
    )
)
