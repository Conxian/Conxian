

;; Conxian DEX Pool - Constant product AMM pool with enhanced tokenomics integration

;; Implements pool-trait with full system integration
(define-constant ONE u1)
(define-constant TWO u2)
(define-constant TEN u10)
(define-constant PRECISION u100000000) 

;; 8 decimals
(define-constant MIN_LIQUIDITY u1000)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_PAUSED (err u1002))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u3001))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u3002))
(define-constant ERR_INVALID_AMOUNT (err u3003))
(define-constant ERR_DEADLINE_PASSED (err u3004))
(define-constant ERR_INSUFFICIENT_SHARES (err u3005))
(define-constant ERR_ZERO_LIQUIDITY (err u3006))
(define-constant ERR_NOT_INITIALIZED (err u3007))
(define-constant ERR_INVALID_FEE (err u3008))

;; --- Data Variables ---
(define-data-var token-a (optional principal) none)
(define-data-var token-b (optional principal) none)
(define-data-var reserve-a uint u0)
(define-data-var reserve-b uint u0)
(define-data-var total-supply uint u0)
(define-data-var paused bool false)
(define-data-var factory principal tx-sender)

;; --- Maps ---
(define-map lp-balances principal uint)
(define-map collected-protocol-fees principal uint)
(define-map cumulative-prices (string-ascii 16) uint)
(define-map last-update-time (string-ascii 16) uint)
(define-map fee-tiers uint { lp-fee-bps: uint, protocol-fee-bps: uint })
(define-map daily-stats (string-ascii 32) (tuple (volume uint) (fees uint) (trades uint)))

;; --- Read-only Functions ---
(define-read-only (get-reserves)
  (ok (tuple (reserve-a (var-get reserve-a))
             (reserve-b (var-get reserve-b)))))
(define-read-only (get-total-supply)  (ok (var-get total-supply)))
(define-read-only (get-token-a)  (match (var-get token-a)    token (ok token)    (err ERR_NOT_INITIALIZED)))
(define-read-only (get-token-b)  (match (var-get token-b)    token (ok token)    (err ERR_NOT_INITIALIZED)))

;; --- Private Functions ---
(define-private (get-lp-fee-bps (tier-id uint))  (get lp-fee-bps (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE))))
(define-private (get-protocol-fee-bps (tier-id uint))  (get protocol-fee-bps (unwrap! (map-get? fee-tiers tier-id) (err ERR_INVALID_FEE))))
(define-private (calculate-swap-amount (amount-in uint) (reserve-in uint) (reserve-out uint) (tier-id uint))  (let ((lp-fee-bps (get-lp-fee-bps tier-id))        (protocol-fee-bps (get-protocol-fee-bps tier-id))        (amount-in-with-lp-fee (- amount-in (/ (* amount-in lp-fee-bps) u10000)))        (amount-in-with-protocol-fee (- amount-in (/ (* amount-in protocol-fee-bps) u10000)))        (numerator (* amount-in-with-lp-fee reserve-out))        (denominator (+ reserve-in amount-in-with-protocol-fee)))    (if (is-eq denominator u0) u0 (/ numerator denominator))))
(define-private (swap-exact-in (token-in principal) (amount-in uint) (min-amount-out uint) (recipient principal) (deadline uint) (tier-id uint))  (begin    (asserts! (not (var-get paused)) ERR_PAUSED)    (asserts! (>= block-height deadline) ERR_DEADLINE_PASSED)    (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)    (let ((token-x (unwrap! (var-get token-a) (err ERR_NOT_INITIALIZED)))          (token-y (unwrap! (var-get token-b) (err ERR_NOT_INITIALIZED)))          (reserve-x (var-get reserve-a))          (reserve-y (var-get reserve-b)))      (if (is-eq token-in token-x)        (let ((amount-out (calculate-swap-amount amount-in reserve-x reserve-y tier-id)))          (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)          (var-set reserve-a (+ reserve-x amount-in))          (var-set reserve-b (- reserve-y amount-out))          (try! (contract-call? (as-contract token-x) transfer amount-in tx-sender (as-contract tx-sender) none))          (try! (contract-call? (as-contract token-y) transfer amount-out (as-contract tx-sender) recipient none))          (ok amount-out))        (let ((amount-out (calculate-swap-amount amount-in reserve-y reserve-x tier-id)))          (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_TOO_HIGH)          (var-set reserve-b (+ reserve-y amount-in))          (var-set reserve-a (- reserve-x amount-out))          (try! (contract-call? (as-contract token-y) transfer amount-in tx-sender (as-contract tx-sender) none))          (try! (contract-call? (as-contract token-x) transfer amount-out (as-contract tx-sender) recipient none))          (ok amount-out))))))

;; --- Public API ---
(define-public (add-liquidity (amount-a uint) (amount-b uint) (recipient principal))  (let ((current-supply (var-get total-supply))        (reserve-x (var-get reserve-a))        (reserve-y (var-get reserve-b))        (shares (if (is-eq current-supply u0)                    MIN_LIQUIDITY                    (min (/ (* amount-a current-supply) reserve-x)                         (/ (* amount-b current-supply) reserve-y)))))    (asserts! (not (var-get paused)) ERR_PAUSED)    (asserts! (and (> amount-a u0) (> amount-b u0)) ERR_INVALID_AMOUNT)    (let ((token-x (unwrap! (var-get token-a) (err ERR_NOT_INITIALIZED)))          (token-y (unwrap! (var-get token-b) (err ERR_NOT_INITIALIZED))))      (try! (contract-call? (as-contract token-x) transfer amount-a tx-sender (as-contract tx-sender) none))      (try! (contract-call? (as-contract token-y) transfer amount-b tx-sender (as-contract tx-sender) none)))    (var-set reserve-a (+ reserve-x amount-a))    (var-set reserve-b (+ reserve-y amount-b))    (var-set total-supply (+ current-supply shares))    (map-set lp-balances recipient (+ (default-to u0 (map-get? lp-balances recipient)) shares))    (ok (tuple (tokens-minted shares) (token-a-used amount-a) (token-b-used amount-b)))))
(define-public (remove-liquidity (amount uint) (recipient principal))  (let ((current-supply (var-get total-supply))        (reserve-x (var-get reserve-a))        (reserve-y (var-get reserve-b))        (user-shares (default-to u0 (map-get? lp-balances recipient)))        (dx (/ (* amount reserve-x) current-supply))        (dy (/ (* amount reserve-y) current-supply)))    (asserts! (not (var-get paused)) ERR_PAUSED)    (asserts! (> amount u0) ERR_INVALID_AMOUNT)    (asserts! (>= user-shares amount) ERR_INSUFFICIENT_SHARES)    (let ((token-x (unwrap! (var-get token-a) (err ERR_NOT_INITIALIZED)))          (token-y (unwrap! (var-get token-b) (err ERR_NOT_INITIALIZED))))        (try! (contract-call? (as-contract token-x) transfer dx (as-contract tx-sender) recipient none))        (try! (contract-call? (as-contract token-y) transfer dy (as-contract tx-sender) recipient none)))    (var-set reserve-a (- reserve-x dx))    (var-set reserve-b (- reserve-y dy))    (var-set total-supply (- current-supply amount))    (map-set lp-balances recipient (- user-shares amount))    (ok (tuple (token-a-returned dx) (token-b-returned dy)))))
(define-public (swap (token-in principal) (amount-in uint) (recipient principal))  (swap-exact-in token-in amount-in u0 recipient (+ block-height u100) u0))
(define-public (initialize (token-a-addr principal) (token-b-addr principal) (factory-addr principal))  (begin    (asserts! (is-eq tx-sender factory-addr) ERR_UNAUTHORIZED)    (asserts! (is-none (var-get token-a)) ERR_NOT_INITIALIZED)    (var-set factory factory-addr)    (var-set token-a (some token-a-addr))    (var-set token-b (some token-b-addr))    (map-set last-update-time "price-a" block-height)    (map-set last-update-time "price-b" block-height)    (ok true)))
(define-public (set-paused (pause bool))  (begin    (asserts! (is-eq tx-sender (var-get factory)) ERR_UNAUTHORIZED)    (var-set paused pause)    (ok true)))