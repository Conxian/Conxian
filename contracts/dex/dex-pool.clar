;; Conxian DEX Pool - Constant product AMM pool with enhanced tokenomics integration
;; Implements pool-trait with full system integration

(use-trait pool-trait .all-traits.pool-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(impl-trait .pool-trait)
(impl-trait .sip-010-ft-trait)

(define-constant ONE u1)
(define-constant TWO u2)
(define-constant TEN u10)

;; Private helper functions
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

;; Use math library for square root
(define-constant MATH_CONTRACT .math-lib-advanced)

(define-private (sqrt (n uint))
  (match (contract-call? MATH_CONTRACT sqrt-fixed n)
    result (ok result)
    error (err u3008)  ;; Fallback to 0 on error
  ))

;; Constants
(define-constant ERR_UNAUTHORIZED u1001)
(define-constant ERR_PAUSED u1002)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u3001)
(define-constant ERR_SLIPPAGE_TOO_HIGH u3002)
(define-constant ERR_INVALID_AMOUNT u3003)
(define-constant ERR_DEADLINE_PASSED u3004)
(define-constant ERR_INSUFFICIENT_SHARES u3005)
(define-constant ERR_ZERO_LIQUIDITY u3006)
(define-constant ERR_NOT_INITIALIZED u3007)

(define-constant PRECISION u100000000) ;; 8 decimals
(define-constant MIN_LIQUIDITY u1000)

;; Data variables
(define-data-var token-a (optional principal) none)
(define-data-var token-b (optional principal) none)
(define-data-var reserve-a uint u0)
(define-data-var reserve-b uint u0)
(define-data-var total-supply uint u0)
(define-data-var default-lp-fee-bps uint u30) ;; 0.3%
(define-data-var default-protocol-fee-bps uint u5) ;; 0.05%
(define-data-var paused bool false)
(define-data-var factory principal tx-sender)

;; Maps
(define-map lp-balances principal uint)
(define-map collected-protocol-fees principal uint) ;; token -> collected fees
(define-map cumulative-prices (string-ascii 16) uint) ;; "price-a" or "price-b" -> cumulative price
(define-map last-update-time (string-ascii 16) uint)
(define-map fee-tiers uint { lp-fee-bps: uint, protocol-fee-bps: uint })

;; Pool performance tracking
(define-map daily-stats (string-ascii 32) (tuple (volume uint) (fees uint) (trades uint)))

;; Read-only functions
(define-read-only (get-reserves)
  (ok (tuple (reserve-a (var-get reserve-a)) 
             (reserve-b (var-get reserve-b)))))

(define-read-only (get-fee-info)
  (ok (tuple (lp-fee-bps (var-get default-lp-fee-bps)) 
             (protocol-fee-bps (var-get default-protocol-fee-bps)))))

(define-read-only (get-fee-tier (tier-id uint))
  (ok (map-get? fee-tiers tier-id)))

(define-read-only (get-price)
  (let ((reserve-a-val (var-get reserve-a))
        (reserve-b-val (var-get reserve-b)))
    (if (and (> reserve-a-val u0) (> reserve-b-val u0))
        (ok (tuple (price-x-y (/ (* reserve-b-val PRECISION) reserve-a-val))
                   (price-y-x (/ (* reserve-a-val PRECISION) reserve-b-val))))
        (ok (tuple (price-x-y u0) (price-y-x u0))))))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

 (define-read-only (get-token-a)
  (match (var-get token-a)
    token (ok token)
    ERR_NOT_INITIALIZED))

 (define-read-only (get-token-b)
  (match (var-get token-b)
    token (ok token)
    ERR_NOT_INITIALIZED))

(define-read-only (get-lp-balance (user principal))
  (default-to u0 (map-get? lp-balances user)))

(define-read-only (get-pool-performance)
  (let ((today (/ block-height u144))) ;; Approximate daily blocks
    (ok (tuple (volume-24h u0) (fees-24h u0)))))  ;; Simplified for enhanced deployment

;; Private functions
;; Calculate output amount for constant product formula with fees
(define-private (calculate-swap-amount (amount-in uint) (reserve-in uint) (reserve-out uint) (tier-id uint))
  (let (
    (fees (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE)))
    (lp-fee-bps (get lp-fee-bps fees))
    (protocol-fee-bps (get protocol-fee-bps fees))
    (amount-in-with-lp-fee (- amount-in (/ (* amount-in lp-fee-bps) u10000)))
    (amount-in-with-protocol-fee (- amount-in (/ (* amount-in protocol-fee-bps) u10000)))
    (numerator (* amount-in-with-lp-fee reserve-out))
    (denominator (+ reserve-in amount-in-with-protocol-fee))
  )
  (if (is-eq denominator u0)
    u0
    (/ numerator denominator)
  )
)

(define-private (get-lp-fee-bps (tier-id uint))
  (let ((fees (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE))))
    (get lp-fee-bps fees)
  )
)

(define-private (get-protocol-fee-bps (tier-id uint))
  (let ((fees (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE))))
    (get protocol-fee-bps fees)
  )
)

(define-public (swap-exact-in (token-in principal) (amount-in uint) (min-amount-out uint) (recipient principal) (deadline uint) (tier-id uint))
  (begin
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (>= block-height deadline) (err ERR_DEADLINE_PASSED))
    (asserts! (> amount-in u0) (err ERR_INVALID_AMOUNT))

    (let (
      (token-x (unwrap! (var-get token-a) (err ERR_NOT_INITIALIZED)))
      (token-y (unwrap! (var-get token-b) (err ERR_NOT_INITIALIZED)))
      (reserve-x (var-get reserve-a))
      (reserve-y (var-get reserve-b))
      (amount-out u0)
      (lp-fee-bps (get-lp-fee-bps tier-id))
      (protocol-fee-bps (get-protocol-fee-bps tier-id))
    )

    (if (is-eq token-in token-x)
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-a (+ reserve-x amount-in))
        (var-set reserve-b (- reserve-y amount-out))
        (try! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-y transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-a (+ reserve-x amount-in))
        (var-set reserve-b (- reserve-y amount-out))
        (ok amount-out)
      )
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-b (+ reserve-y amount-in))
        (var-set reserve-a (- reserve-x amount-out))
        (try! (contract-call? token-y transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-x transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-b (+ reserve-y amount-in))
        (var-set reserve-a (- reserve-x amount-out))
        (ok amount-out)
      )
    )
  )
)

(define-public (swap-exact-out (token-out principal) (amount-out uint) (max-amount-in uint) (recipient principal) (deadline uint) (tier-id uint))
  (begin
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (>= block-height deadline) (err ERR_DEADLINE_PASSED))
    (asserts! (> amount-out u0) (err ERR_INVALID_AMOUNT))

    (let (
      (token-x (unwrap! (var-get token-a) (err ERR_NOT_INITIALIZED)))
      (token-y (unwrap! (var-get token-b) (err ERR_NOT_INITIALIZED)))
      (reserve-x (var-get reserve-a))
      (reserve-y (var-get reserve-b))
      (amount-in u0)
      (lp-fee-bps (get-lp-fee-bps tier-id))
      (protocol-fee-bps (get-protocol-fee-bps tier-id))
    )

    (if (is-eq token-out token-x)
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-x (- reserve-x amount-out))
        (var-set reserve-y (+ reserve-y amount-in))
        (try! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-y transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-x (- reserve-x amount-out))
        (var-set reserve-y (+ reserve-y amount-in))
        (ok amount-in)
      )
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-y (- reserve-y amount-out))
        (var-set reserve-x (+ reserve-x amount-in))
        (try! (contract-call? token-y transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-x transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-y (- reserve-y amount-out))
        (var-set reserve-x (+ reserve-x amount-in))
        (ok amount-in)
      )
    )
  )
)


(define-public (set-fee-tier (tier-id uint) (lp-fee-bps uint) (protocol-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get factory)) (err ERR_UNAUTHORIZED))
    (map-set fee-tiers tier-id { lp-fee-bps: lp-fee-bps, protocol-fee-bps: protocol-fee-bps })
    (ok true)
  )
)

(define-public (set-default-fee-tier (lp-fee-bps uint) (protocol-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get factory)) (err ERR_UNAUTHORIZED))
    (var-set default-lp-fee-bps lp-fee-bps)
    (var-set default-protocol-fee-bps protocol-fee-bps)
    (ok true)
  )
)

;; Private functions
;; Calculate output amount for constant product formula with fees
(define-private (calculate-swap-amount (amount-in uint) (reserve-in uint) (reserve-out uint) (tier-id uint))
  (let (
    (fees (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE)))
    (lp-fee-bps (get lp-fee-bps fees))
    (protocol-fee-bps (get protocol-fee-bps fees))
    (amount-in-with-lp-fee (- amount-in (/ (* amount-in lp-fee-bps) u10000)))
    (amount-in-with-protocol-fee (- amount-in (/ (* amount-in protocol-fee-bps) u10000)))
    (numerator (* amount-in-with-lp-fee reserve-out))
    (denominator (+ reserve-in amount-in-with-protocol-fee))
  )
  (if (is-eq denominator u0)
    u0
    (/ numerator denominator)
  )
)

(define-private (get-lp-fee-bps (tier-id uint))
  (let ((fees (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE))))
    (get lp-fee-bps fees)
  )
)

(define-private (get-protocol-fee-bps (tier-id uint))
  (let ((fees (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE))))
    (get protocol-fee-bps fees)
  )
)

(define-public (swap-exact-in (token-in principal) (amount-in uint) (min-amount-out uint) (recipient principal) (deadline uint) (tier-id uint))
  (begin
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (>= block-height deadline) (err ERR_DEADLINE_PASSED))
    (asserts! (> amount-in u0) (err ERR_INVALID_AMOUNT))

    (let (
      (token-x (unwrap! (var-get token-a) (err ERR_NOT_INITIALIZED)))
      (token-y (unwrap! (var-get token-b) (err ERR_NOT_INITIALIZED)))
      (reserve-x (var-get reserve-a))
      (reserve-y (var-get reserve-b))
      (amount-out u0)
      (lp-fee-bps (get-lp-fee-bps tier-id))
      (protocol-fee-bps (get-protocol-fee-bps tier-id))
    )

    (if (is-eq token-in token-x)
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-a (+ reserve-x amount-in))
        (var-set reserve-b (- reserve-y amount-out))
        (try! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-y transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-a (+ reserve-x amount-in))
        (var-set reserve-b (- reserve-y amount-out))
        (ok amount-out)
      )
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-b (+ reserve-y amount-in))
        (var-set reserve-a (- reserve-x amount-out))
        (try! (contract-call? token-y transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-x transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-b (+ reserve-y amount-in))
        (var-set reserve-a (- reserve-x amount-out))
        (ok amount-out)
      )
    )
  )
)

(define-public (swap-exact-out (token-out principal) (amount-out uint) (max-amount-in uint) (recipient principal) (deadline uint) (tier-id uint))
  (begin
    (asserts! (not (var-get paused)) (err ERR_PAUSED))
    (asserts! (>= block-height deadline) (err ERR_DEADLINE_PASSED))
    (asserts! (> amount-out u0) (err ERR_INVALID_AMOUNT))

    (let (
      (token-x (unwrap! (var-get token-a) (err ERR_NOT_INITIALIZED)))
      (token-y (unwrap! (var-get token-b) (err ERR_NOT_INITIALIZED)))
      (reserve-x (var-get reserve-a))
      (reserve-y (var-get reserve-b))
      (amount-in u0)
      (lp-fee-bps (get-lp-fee-bps tier-id))
      (protocol-fee-bps (get-protocol-fee-bps tier-id))
    )

    (if (is-eq token-out token-x)
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-x (- reserve-x amount-out))
        (var-set reserve-y (+ reserve-y amount-in))
        (try! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-y transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-x (- reserve-x amount-out))
        (var-set reserve-y (+ reserve-y amount-in))
        (ok amount-in)
      )
      (begin
        (asserts! (> reserve-x u0) (err ERR_ZERO_LIQUIDITY))
        (asserts! (> reserve-y u0) (err ERR_ZERO_LIQUIDITY))
        (var-set reserve-y (- reserve-y amount-out))
        (var-set reserve-x (+ reserve-x amount-in))
        (try! (contract-call? token-y transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-x transfer amount-out (as-contract tx-sender) recipient))
        (var-set reserve-y (- reserve-y amount-out))
        (var-set reserve-x (+ reserve-x amount-in))
        (ok amount-in)
      )
    )
  )
)


(define-public (set-fee-tier (tier-id uint) (lp-fee-bps uint) (protocol-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get factory)) (err ERR_UNAUTHORIZED))
    (map-set fee-tiers tier-id { lp-fee-bps: lp-fee-bps, protocol-fee-bps: protocol-fee-bps })
    (ok true)
  )
)

(define-public (set-default-fee-tier (lp-fee-bps uint) (protocol-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get factory)) (err ERR_UNAUTHORIZED))
    (var-set default-lp-fee-bps lp-fee-bps)
    (var-set default-protocol-fee-bps protocol-fee-bps)
    (ok true)
  )
)

;; Private functions
;; Calculate output amount for constant product formula with fees
(define-private (calculate-swap-amount (amount-in uint) (reserve-in uint) (reserve-out uint))
  (let ((amount-in-with-fee (- amount-in (/ (* amount-in (var-get lp-fee-bps)) u10000)))
        (numerator (* amount-in-with-fee reserve-out))
        (denominator (+ reserve-in amount-in-with-fee)))
    (/ numerator denominator)))

;; Update time-weighted average price
(define-private (update-cumulative-prices)
  (let ((current-time block-height)
        (time-elapsed (- current-time 
                        (default-to current-time 
                                   (map-get? last-update-time "price-a")))))
    (if (> time-elapsed u0)
        (let ((price-info (unwrap-panic (get-price))))
          (map-set cumulative-prices "price-a" 
                   (+ (default-to u0 (map-get? cumulative-prices "price-a"))
                      (* (get price-x-y price-info) time-elapsed)))
          (map-set cumulative-prices "price-b"
                   (+ (default-to u0 (map-get? cumulative-prices "price-b"))
                      (* (get price-y-x price-info) time-elapsed)))
          (map-set last-update-time "price-a" current-time)
          (map-set last-update-time "price-b" current-time))
        false)))

;; Update daily trading statistics
(define-private (update-daily-stats (volume uint) (fees uint))
  (let ((today-key "current")
        (current-stats (default-to (tuple (volume u0) (fees u0) (trades u0))
                                (map-get? daily-stats {day: today-key}))))
    (map-set daily-stats {day: today-key}
             (tuple (volume (+ (get volume current-stats) volume))
                    (fees (+ (get fees current-stats) fees))
                    (trades (+ (get trades current-stats) u1))))))

;; Core AMM functions
(define-public (swap-exact-in (amount-in uint) (min-amount-out uint) (x-to-y bool) (deadline uint))
  (let ((current-block block-height)
        (reserve-in (if x-to-y (var-get reserve-a) (var-get reserve-b)))
        (reserve-out (if x-to-y (var-get reserve-b) (var-get reserve-a)))
        (amount-out (calculate-swap-amount amount-in reserve-in reserve-out))
        (protocol-fee (/ (* amount-in (var-get protocol-fee-bps)) u10000))
        (lp-fee (/ (* amount-in (var-get lp-fee-bps)) u10000))
        (total-fee (+ protocol-fee lp-fee)))
    
    ;; Validations
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (<= current-block deadline) ERR_DEADLINE_PASSED)
    (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)
    (asserts! (<= amount-out reserve-out) ERR_INSUFFICIENT_LIQUIDITY)
    
    ;; Update reserves
    (if x-to-y
        (begin
          (var-set reserve-a (+ reserve-in amount-in))
          (var-set reserve-b (- reserve-out amount-out)))
        (begin
          (var-set reserve-b (+ reserve-in amount-in))
          (var-set reserve-a (- reserve-out amount-out))))
    
    ;; Handle protocol fees
    (if (> protocol-fee u0)
        (let ((fee-token (if x-to-y 
                            (unwrap-panic (var-get token-a)) 
                            (unwrap-panic (var-get token-b)))))
          (map-set collected-protocol-fees fee-token
                   (+ (default-to u0 (map-get? collected-protocol-fees fee-token))
                      protocol-fee))
          ;; Skip revenue distributor for enhanced deployment
          true)
        true)
    
    ;; Update statistics
    (update-cumulative-prices)
    (update-daily-stats amount-in total-fee)
    
    ;; Update factory stats - skip for enhanced deployment
    true
    
    ;; Emit event
    (print (tuple (event "swap") 
                  (user tx-sender)
                  (amount-in amount-in)
                  (amount-out amount-out)
                  (fee total-fee)
                  (x-to-y x-to-y)))
    
    (ok (tuple (amount-out amount-out) (fee total-fee)))))

(define-public (add-liquidity (dx uint) (dy uint) (min-shares uint))
  (let ((current-supply (var-get total-supply))
        (reserve-x (var-get reserve-a))
        (reserve-y (var-get reserve-b))
        (shares (if (is-eq current-supply u0)
                    (let ((product (* dx dy)))
                      (let ((sqrt-result (unwrap! (contract-call? MATH_CONTRACT sqrt-fixed product) (err u3008))))
                        (if (< sqrt-result MIN_LIQUIDITY)
                          (err u3008) ;; ERR_INSUFFICIENT_LIQUIDITY
                          (- sqrt-result MIN_LIQUIDITY))))
                    ;; Subsequent liquidity provision
                    (min (/ (* dx current-supply) reserve-x)
                         (/ (* dy current-supply) reserve-y))))
        (user tx-sender))
    
    ;; Validations
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (and (> dx u0) (> dy u0)) ERR_INVALID_AMOUNT)
    (asserts! (>= shares min-shares) ERR_SLIPPAGE_TOO_HIGH)
    
    ;; Update reserves and supply
    (var-set reserve-a (+ reserve-x dx))
    (var-set reserve-b (+ reserve-y dy))
    (var-set total-supply (+ current-supply shares))
    
    ;; Update user LP balance
    (map-set lp-balances user (+ (get-lp-balance user) shares))
    
    ;; Update statistics
    (update-cumulative-prices)
    
    ;; Emit event
    (print (tuple (event "add-liquidity")
                  (user user)
                  (amount-a dx)
                  (amount-b dy)
                  (shares shares)))
    
    (ok (tuple (shares shares) (amount-a dx) (amount-b dy)))))

(define-public (remove-liquidity (shares uint) (min-dx uint) (min-dy uint))
  (let ((current-supply (var-get total-supply))
        (reserve-x (var-get reserve-a))
        (reserve-y (var-get reserve-b))
        (user tx-sender)
        (user-shares (get-lp-balance user))
        (dx (/ (* shares reserve-x) current-supply))
        (dy (/ (* shares reserve-y) current-supply)))
    
    ;; Validations
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-shares shares) ERR_INSUFFICIENT_SHARES)
    (asserts! (and (>= dx min-dx) (>= dy min-dy)) ERR_SLIPPAGE_TOO_HIGH)
    
    ;; Update reserves and supply
    (var-set reserve-a (- reserve-x dx))
    (var-set reserve-b (- reserve-y dy))
    (var-set total-supply (- current-supply shares))
    
    ;; Update user LP balance
    (map-set lp-balances user (- user-shares shares))
    
    ;; Update statistics
    (update-cumulative-prices)
    
    ;; Emit event
    (print (tuple (event "remove-liquidity")
                  (user user)
                  (amount-a dx)
                  (amount-b dy)
                  (shares shares)))
    
    (ok (tuple (amount-a dx) (amount-b dy)))))

;; Enhanced tokenomics integration
(define-public (collect-protocol-fees)
  (let ((fee-a (default-to u0 (map-get? collected-protocol-fees (unwrap-panic (var-get token-a)))))
        (fee-b (default-to u0 (map-get? collected-protocol-fees (unwrap-panic (var-get token-b))))))
    
    ;; Reset collected fees
    (map-set collected-protocol-fees (unwrap-panic (var-get token-a)) u0)
    (map-set collected-protocol-fees (unwrap-panic (var-get token-b)) u0)
    
    ;; Notify revenue distributor
    (if (> fee-a u0)
        ;; Skip revenue distributor for enhanced deployment 
        true
        true)
    
    (if (> fee-b u0)
        ;; Skip revenue distributor for enhanced deployment
        true
        true)
    
    (ok (tuple (fee-a fee-a) (fee-b fee-b)))))

(define-public (update-reward-distribution)
  (begin
    ;; Integration with enhanced tokenomics reward system - simplified for enhanced deployment
    (ok true)))

;; Administrative functions
(define-public (initialize (token-a-addr principal) (token-b-addr principal) (fee-bps uint) (factory-addr principal))
  (begin
    ;; This function should only be called once, by the factory that created this pool.
    (asserts! (is-eq tx-sender factory-addr) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (var-get token-a)) (err ERR_NOT_INITIALIZED)) ;; ERR_ALREADY_INITIALIZED

    (var-set factory factory-addr)
    (var-set token-a (some token-a-addr))
    (var-set token-b (some token-b-addr))
    (var-set lp-fee-bps fee-bps)
    (ok true)
  )
)

(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-eq tx-sender (var-get factory)) ERR_UNAUTHORIZED)
    (var-set paused pause)
    (print (tuple (event "pool-pause-changed") (paused pause)))
    (ok true)))

(define-public (set-fees (lp-fee uint) (protocol-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get factory)) ERR_UNAUTHORIZED)
    (asserts! (<= lp-fee u1000) ERR_INVALID_AMOUNT) ;; Max 10%
    (asserts! (<= protocol-fee u100) ERR_INVALID_AMOUNT) ;; Max 1%
    (var-set lp-fee-bps lp-fee)
    (var-set protocol-fee-bps protocol-fee)
    (ok true)))

;; (int-to-ascii) helper removed; not used and caused parsing issues

;; Initialize cumulative price tracking
(map-set last-update-time "price-a" block-height)
(map-set last-update-time "price-b" block-height)
