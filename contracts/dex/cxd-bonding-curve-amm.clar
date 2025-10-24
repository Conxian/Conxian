;; cxd-bonding-curve-amm.clar
;; Implements a bonding curve AMM for CXD token with price stability mechanisms

(use-trait token-trait .all-traits.sip-010-ft-trait)
(use-trait governance-trait .all-traits.governance-token-trait)
(use-trait price-initializer-trait .all-traits.price-initializer-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1002)
(define-constant ERR_SLIPPAGE_EXCEEDED (err u1003))
(define-constant ERR_PAUSED (err u1004))
(define-constant ERR_INVALID_TOKEN (err u1005))
(define-constant ERR_NOT_INITIALIZED (err u1006))

;; Price precision (6 decimals)
(define-constant PRECISION u1000000)
(define-constant MAX_UINT u340282366920938463463374607431768211455)

;; Contract state
(define-data-var is-initialized bool false)
(define-data-var is-paused bool false)
(define-data-var cxd-token (optional principal) none)
(define-data-var stx-token (optional principal) none)
(define-data-var price-initializer (optional principal) none)
(define-data-var fee-rate uint u3000)  ;; 0.3% (0.003 * 1_000_000)
(define-data-var protocol-fee-receiver (optional principal) none)

;; Reserve tracking
(define-map reserves { token: principal } { amount: uint })

;; Events
    (define-event Swap (sender: principal, token-in: principal, amount-in: uint, token-out: principal, amount-out: uint, fee: uint))
    (define-event AddLiquidity (provider: principal, token: principal, amount: uint, shares: uint))
    (define-event RemoveLiquidity (provider: principal, token: principal, amount: uint, shares: uint))
    (define-event FeeCollected (amount: uint, token: principal))

;; ===== Initialization =====

(define-public (initialize 
    (cxd-token-principal principal)
    (stx-token-principal principal)
    (price-initializer-principal principal)
    (protocol-fee-receiver-principal principal)
)
    (let ((caller tx-sender))
        (asserts! (is-eq caller (contract-call? .all-traits.ownable-trait get-owner)) ERR_UNAUTHORIZED)
        (asserts! (not (var-get is-initialized)) ERR_ALREADY_INITIALIZED)
        
        (var-set cxd-token (some cxd-token-principal))
        (var-set stx-token (some stx-token-principal))
        (var-set price-initializer (some price-initializer-principal))
        (var-set protocol-fee-receiver (some protocol-fee-receiver-principal))
        (var-set is-initialized true)
        
        (ok true)
    )
)

;; ===== Core AMM Functions =====

;; Get current price from initializer
(define-read-only (get-price)
    (let ((initializer (unwrap-panic (var-get price-initializer))))
        (contract-call? initializer get-price-with-minimum)
    )
)

;; Calculate amount out given amount in
(define-read-only (get-amount-out (amount-in uint) (reserve-in uint) (reserve-out uint))
    (let (
        (amount-in-with-fee (* amount-in (- PRECISION (var-get fee-rate))))
        (numerator (* amount-in-with-fee reserve-out))
        (denominator (+ (* reserve-in PRECISION) amount-in-with-fee))
    )
        (ok (/ numerator denominator))
    )
)

;; Calculate amount in given amount out
(define-read-only (get-amount-in (amount-out uint) (reserve-in uint) (reserve-out uint)
    (let (
        (numerator (* amount-out reserve-in PRECISION))
        (denominator (* (- reserve-out amount-out) (- PRECISION (var-get fee-rate))))
    )
        (ok (+ 1 (/ numerator denominator)))  ; +1 to account for rounding
    )
)

;; Swap tokens
(define-public (swap (token-in principal) (amount-in uint) (min-amount-out uint))
    (let (
        (caller tx-sender)
        (initialized (var-get is-initialized))
        (paused (var-get is-paused))
        (cxd (unwrap-panic (var-get cxd-token)))
        (stx (unwrap-panic (var-get stx-token)))
        (initializer (unwrap-panic (var-get price-initializer)))
        (fee-receiver (unwrap-panic (var-get protocol-fee-receiver)))
    )
        (asserts! initialized ERR_NOT_INITIALIZED)
        (asserts! (not paused) ERR_PAUSED)
        (asserts! (or (is-eq token-in cxd) (is-eq token-in stx)) ERR_INVALID_TOKEN)
        (asserts! (> amount-in 0) ERR_INVALID_AMOUNT)
        
        (let* (
            (token-out (if (is-eq token-in cxd) stx cxd))
            (reserve-in (get-amount reserves { token: token-in }.amount))
            (reserve-out (get-amount reserves { token: token-out }.amount))
            (amount-out (unwrap-panic (get-amount-out amount-in reserve-in reserve-out)))
            (fee-amount (/ (* amount-in (var-get fee-rate)) PRECISION))
        )
            (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_EXCEEDED)
            
            ;; Transfer tokens from user
            (try! (contract-call? token-in transfer-from caller (as-contract tx-sender) amount-in))
            
            ;; Take protocol fee if any
            (if (> fee-amount 0)
                (try! (contract-call? token-in transfer fee-receiver fee-amount))
            )
            
            ;; Transfer output tokens to user
            (try! (contract-call? token-out transfer caller amount-out))
            
            ;; Update reserves
            (map-set reserves { token: token-in } { amount: (+ reserve-in (- amount-in fee-amount)) })
            (map-set reserves { token: token-out } { amount: (- reserve-out amount-out) })
            
            (print (Swap {
                sender: caller,
                token-in: token-in,
                amount-in: amount-in,
                token-out: token-out,
                amount-out: amount-out,
                fee: fee-amount
            }))
            
            (ok amount-out)
        )
    )
)

;; ===== Liquidity Provision =====

;; Add liquidity to the pool
(define-public (add-liquidity (token-amount uint) (stx-amount uint) (min-liquidity uint))
    (let (
        (caller tx-sender)
        (initialized (var-get is-initialized))
        (cxd (unwrap-panic (var-get cxd-token)))
        (stx (unwrap-panic (var-get stx-token)))
        (price-data (unwrap-panic (contract-call? (unwrap-panic (var-get price-initializer)) get-price-with-minimum)))
        (current-price (get price-data 'price))
        (min-price (get price-data 'min-price))
    )
        (asserts! initialized ERR_NOT_INITIALIZED
        (asserts! (> token-amount 0) ERR_INVALID_AMOUNT)
        (asserts! (> stx-amount 0) ERR_INVALID_AMOUNT
        
        ;; Calculate expected price and check slippage
        (let* (
            (total-supply (try! (contract-call? cxd get-total-supply)))
            (reserve-cxd (get-amount reserves { token: cxd }.amount))
            (reserve-stx (get-amount reserves { token: stx }.amount))
            (liquidity uint)
        )
            (if (and (is-eq reserve-cxd 0) (is-eq reserve-stx 0))
                ;; Initial liquidity
                (let ((liquidity (sqrt (* token-amount stx-amount))))
                    (asserts! (>= liquidity min-liquidity) ERR_SLIPPAGE_EXCEEDED)
                    (try! (contract-call? cxd transfer-from caller (as-contract tx-sender) token-amount))
                    (try! (contract-call? stx transfer caller (as-contract tx-sender) stx-amount))
                    
                    (map-set reserves { token: cxd } { amount: token-amount })
                    (map-set reserves { token: stx } { amount: stx-amount })
                    
                    (print (AddLiquidity {
                        provider: caller,
                        token: cxd,
                        amount: token-amount,
                        shares: liquidity
                    }))
                    
                    (print (AddLiquidity {
                        provider: caller,
                        token: stx,
                        amount: stx-amount,
                        shares: liquidity
                    }))
                    
                    (ok liquidity)
                )
                
                ;; Additional liquidity
                (let* (
                    (token-amount-optimal (/ (* token-amount reserve-stx) reserve-cxd))
                    (stx-amount-optimal (/ (* stx-amount reserve-cxd) reserve-stx))
                    (liquidity (min token-amount-optimal stx-amount-optimal))
                )
                    (asserts! (>= liquidity min-liquidity) ERR_SLIPPAGE_EXCEEDED)
                    
                    (try! (contract-call? cxd transfer-from caller (as-contract tx-sender) token-amount))
                    (try! (contract-call? stx transfer caller (as-contract tx-sender) stx-amount))
                    
                    (map-set reserves { token: cxd } { amount: (+ reserve-cxd token-amount) })
                    (map-set reserves { token: stx } { amount: (+ reserve-stx stx-amount) })
                    
                    (print (AddLiquidity {
                        provider: caller,
                        token: cxd,
                        amount: token-amount,
                        shares: liquidity
                    }))
                    
                    (ok liquidity)
                )
            )
        )
    )
)

;; ===== Governance Functions =====

(define-public (set-fee-rate (new-fee-rate uint))
    (let ((caller tx-sender))
        (asserts! (contract-call? .all-traits.governance-token-trait has-voting-power caller) ERR_UNAUTHORIZED)
        (asserts! (<= new-fee-rate 10000) ERR_INVALID_AMOUNT)  ;; Max 1% fee
        
        (var-set fee-rate new-fee-rate)
        (ok true)
    )
)

(define-public (set-protocol-fee-receiver (receiver principal))
    (let ((caller tx-sender))
        (asserts! (contract-call? .all-traits.governance-token-trait has-voting-power caller) ERR_UNAUTHORIZED)
        (var-set protocol-fee-receiver (some receiver))
        (ok true)
    )
)

(define-public (pause (paused bool))
    (let ((caller tx-sender))
        (asserts! (contract-call? .all-traits.governance-token-trait has-voting-power caller) ERR_UNAUTHORIZED)
        (var-set is-paused paused)
        (ok true)
    )
)

;; ===== View Functions =====

(define-read-only (get-reserves)
    (ok {
        cxd-reserve: (get-amount reserves { token: (unwrap-panic (var-get cxd-token)) }.amount),
        stx-reserve: (get-amount reserves { token: (unwrap-panic (var-get stx-token)) }.amount),
        fee-rate: (var-get fee-rate),
        is-paused: (var-get is-paused)
    })
)

(define-read-only (get-amount (maybe-amount (optional { amount: uint })))
    (default-to u0 (map-get? maybe-amount amount))
)

(define-read-only (sqrt (y uint))
    (if (or (<= y 1) (>= y MAX_UINT)) 
        y
        (let* (
            (z (>> y 1))
            (x (+ (/ y z) z))
        )
            (if (>= x z) 
                z 
                (sqrt x)
            )
        )
    )
)
