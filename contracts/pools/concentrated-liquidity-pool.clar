;; Conxian Concentrated Liquidity Pool

;; Uses fixed-point arithmetic with Q64 precision

(use-trait ft-trait .all-traits.sip-010-ft-trait)
(use-trait pool-trait .all-traits.pool-trait)
(use-trait math-trait .all-traits.math-trait)
(use-trait error-codes-trait .all-traits.error-codes-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(define-constant Q64 u18446744073709551616)  ;; 2^64
(define-constant MAX_TICK 776363)  ;; Corresponds to sqrt(2^128)
(define-constant MIN_TICK (- MAX_TICK))
(define-constant TICK_BASE u10000)  ;; 1.0001 in fixed-point with 4 decimals

;; Math library contract (to be set by admin)
(define-constant MATH_CONTRACT 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INVALID_TICK (err u102))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u103))
(define-constant ERR_SWAP_FAILED (err u104))
(define-constant ERR_MINT_FAILED (err u105))
(define-constant ERR_BURN_FAILED (err u106))
(define-constant ERR_INVALID_POSITION (err u107))

;; Data maps and variables
(define-map pools
  {token-x: principal, token-y: principal}
  {
    pool-id: uint,
    sqrt-price: uint,
    tick: int,
    liquidity: uint,
    fee-protocol: uint,
    fee-tier: uint,
    factory: principal,
    token-x-total-supply: uint,
    token-y-total-supply: uint
  }
)

(define-map positions
  {position-id: uint}
  {
    owner: principal,
    pool-id: uint,
    tick-lower: int,
    tick-upper: int,
    liquidity: uint,
    amount-x: uint,
    amount-y: uint,
    fee-growth-inside-last-x: uint,
    fee-growth-inside-last-y: uint,
    tokens-owed-x: uint,
    tokens-owed-y: uint
  }
)

(define-data-var next-position-id uint u0)
(define-data-var next-pool-id uint u0)

;; Public functions
(define-public (create-pool (token-x principal) (token-y principal) (sqrt-price-x96 uint) (fee-tier uint) (fee-protocol uint))
  (begin
    (asserts! (and (> sqrt-price-x96 u0) (<= fee-tier u10000) (<= fee-protocol u10000)) ERR_INVALID_AMOUNT)
    (let (
      (pool-id (var-get next-pool-id))
      (tick (try! (sqrt-price-to-tick sqrt-price-x96)))
    )
      (map-set pools
        {token-x: token-x, token-y: token-y}
        {
          pool-id: pool-id,
          sqrt-price: sqrt-price-x96,
          tick: tick,
          liquidity: u0,
          fee-protocol: fee-protocol,
          fee-tier: fee-tier,
          factory: tx-sender,
          token-x-total-supply: u0,
          token-y-total-supply: u0
        }
      )
      (var-set next-pool-id (+ pool-id u1))
      (ok pool-id)
    )
  )
)

(define-public (mint-position (pool-id uint) (tick-lower int) (tick-upper int) (amount-x-desired uint) (amount-y-desired uint) (amount-x-min uint) (amount-y-min uint))
  (let (
    (pool (try! (map-get? pools {pool-id: pool-id})))
    (sqrt-price-current (get sqrt-price pool))
    (sqrt-price-lower (try! (tick-to-sqrt-price tick-lower)))
    (sqrt-price-upper (try! (tick-to-sqrt-price tick-upper)))
    (liquidity (get-liquidity-for-amounts sqrt-price-current sqrt-price-lower sqrt-price-upper amount-x-desired amount-y-desired))
    (amount-x (try! (calculate-amount-x liquidity sqrt-price-current sqrt-price-lower sqrt-price-upper)))
    (amount-y (try! (calculate-amount-y liquidity sqrt-price-current sqrt-price-lower sqrt-price-upper)))
    (position-id (var-get next-position-id))
  )
    (asserts! (>= amount-x amount-x-min) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (>= amount-y amount-y-min) ERR_INSUFFICIENT_LIQUIDITY)

    ;; Transfer tokens
    (try! (contract-call? (get token-x pool) transfer amount-x tx-sender (as-contract tx-sender)))
    (try! (contract-call? (get token-y pool) transfer amount-y tx-sender (as-contract tx-sender)))

    ;; Update pool liquidity
    (map-set pools {pool-id: pool-id} (merge pool {liquidity: (+ (get liquidity pool) liquidity)}))

    ;; Create position
    (map-set positions
      {position-id: position-id}
      {
        owner: tx-sender,
        pool-id: pool-id,
        tick-lower: tick-lower,
        tick-upper: tick-upper,
        liquidity: liquidity,
        amount-x: amount-x,
        amount-y: amount-y,
        fee-growth-inside-last-x: u0,
        fee-growth-inside-last-y: u0,
        tokens-owed-x: u0,
        tokens-owed-y: u0
      }
    )
    (var-set next-position-id (+ position-id u1))
    (ok position-id)
  )
)

(define-public (burn-position (position-id uint) (liquidity-amount uint))
  (let (
    (position (try! (map-get? positions {position-id: position-id})))
    (pool (try! (map-get? pools {pool-id: (get pool-id position)})))
    (sqrt-price-current (get sqrt-price pool))
    (sqrt-price-lower (try! (tick-to-sqrt-price (get tick-lower position))))
    (sqrt-price-upper (try! (tick-to-sqrt-price (get tick-upper position))))
    (amount-x (try! (calculate-amount-x liquidity-amount sqrt-price-current sqrt-price-lower sqrt-price-upper)))
    (amount-y (try! (calculate-amount-y liquidity-amount sqrt-price-current sqrt-price-lower sqrt-price-upper)))
  )
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (asserts! (>= (get liquidity position) liquidity-amount) ERR_INSUFFICIENT_LIQUIDITY)

    ;; Transfer tokens back to user
    (try! (contract-call? (get token-x pool) transfer amount-x (as-contract tx-sender) tx-sender))
    (try! (contract-call? (get token-y pool) transfer amount-y (as-contract tx-sender) tx-sender))

    ;; Update position liquidity
    (map-set positions {position-id: position-id} (merge position {liquidity: (- (get liquidity position) liquidity-amount)}))

    ;; Update pool liquidity
    (map-set pools {pool-id: (get pool-id position)} (merge pool {liquidity: (- (get liquidity pool) liquidity-amount)}))

    (ok {amount-x: amount-x, amount-y: amount-y})
  )
)

(define-public (swap (pool-id uint) (token-in principal) (amount-in uint) (amount-out-min uint) (recipient principal))
  (let (
    (pool (try! (map-get? pools {pool-id: pool-id})))
    (token-x (get token-x pool))
    (token-y (get token-y pool))
    (sqrt-price-current (get sqrt-price pool))
    (liquidity (get liquidity pool))
    (amount-out u0)
    (new-sqrt-price u0)
    (new-liquidity u0)
  )
    (asserts! (or (is-eq token-in token-x) (is-eq token-in token-y)) ERR_INVALID_AMOUNT)

    (if (is-eq token-in token-x)
      (begin
        ;; Swap X for Y
        (asserts! (>= (get token-x pool) amount-in) ERR_INSUFFICIENT_LIQUIDITY)
        (let (
          (amount-out-calc (try! (contract-call? MATH_CONTRACT calculate-swap-amount-out-x-to-y sqrt-price-current liquidity amount-in)))
          (new-sqrt-price-calc (try! (contract-call? MATH_CONTRACT calculate-new-sqrt-price-x-to-y sqrt-price-current liquidity amount-in)))
        )
          (var-set amount-out amount-out-calc)
          (var-set new-sqrt-price new-sqrt-price-calc)
        )
        (asserts! (>= amount-out amount-out-min) ERR_SWAP_FAILED)
        (try! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-y transfer amount-out (as-contract tx-sender) recipient))
      )
      (begin
        ;; Swap Y for X
        (asserts! (>= (get token-y pool) amount-in) ERR_INSUFFICIENT_LIQUIDITY)
        (let (
          (amount-out-calc (try! (contract-call? MATH_CONTRACT calculate-swap-amount-out-y-to-x sqrt-price-current liquidity amount-in)))
          (new-sqrt-price-calc (try! (contract-call? MATH_CONTRACT calculate-new-sqrt-price-y-to-x sqrt-price-current liquidity amount-in)))
        )
          (var-set amount-out amount-out-calc)
          (var-set new-sqrt-price new-sqrt-price-calc)
        )
        (asserts! (>= amount-out amount-out-min) ERR_SWAP_FAILED)
        (try! (contract-call? token-y transfer amount-in tx-sender (as-contract tx-sender)))
        (try! (contract-call? token-x transfer amount-out (as-contract tx-sender) recipient))
      )
    )

    ;; Update pool state
    (map-set pools {pool-id: pool-id} (merge pool {sqrt-price: new-sqrt-price, tick: (try! (sqrt-price-to-tick new-sqrt-price))}))

    (ok amount-out)
  )
)

;; Read-only functions (placeholders)
(define-read-only (get-pool (token-x principal) (token-y principal))
  (ok {pool-id: u0, sqrt-price: u0, tick: u0, liquidity: u0, fee-protocol: u0, fee-tier: u0, factory: tx-sender})
)

(define-read-only (get-position (position-id uint))
  (ok {owner: tx-sender, pool-id: u0, tick-lower: u0, tick-upper: u0, liquidity: u0, amount-x: u0, amount-y: u0, fee-growth-inside-last-x: u0, fee-growth-inside-last-y: u0, tokens-owed-x: u0, tokens-owed-y: u0})
)

;; Calculate sqrt price from tick using fixed-point arithmetic
(define-read-only (tick-to-sqrt-price (tick int))
  (let ((math-addr MATH_CONTRACT))
    (if (>= tick 0)
      (let ((base-power (try! (contract-call? math-addr pow TICK_BASE (to-uint tick)))))
        (contract-call? math-addr sqrt base-power))
      (let ((base-power (try! (contract-call? math-addr pow TICK_BASE (to-uint (- tick))))))
        (let ((sqrt-result (try! (contract-call? math-addr sqrt base-power))))
          (ok (/ Q64 sqrt-result))))
    )
  )
)

;; Calculate tick from sqrt price using fixed-point arithmetic
(define-read-only (sqrt-price-to-tick (sqrt-price uint))
  (let ((math-addr MATH_CONTRACT))
    (let ((price-squared (try! (contract-call? math-addr multiply sqrt-price sqrt-price)))
          (ratio (/ price-squared Q64))
          (log-sqrt (try! (contract-call? math-addr log2 ratio)))
          (log-tick-base (try! (contract-call? math-addr log2 TICK_BASE))))
      (ok (to-int (/ (* log-sqrt Q64) log-tick-base)))
    )
  )
)

;; Calculate liquidity amounts for given ticks
(define-read-only (get-liquidity-for-amounts (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint) (amount-x uint) (amount-y uint))
  (let (
      (liquidity-x (if (<= sqrt-price-current sqrt-price-lower)
        u0
        (div (mul amount-x sqrt-price-current) (sub sqrt-price-current sqrt-price-lower))
      ))
      (liquidity-y (if (>= sqrt-price-current sqrt-price-upper)
        u0
        (div amount-y (sub sqrt-price-upper sqrt-price-current))
      ))
    )
    (if (< sqrt-price-current sqrt-price-upper)
      (min liquidity-x liquidity-y)
      liquidity-x
    )
  ))

;; Fee calculation
(define-read-only (calculate-fee (liquidity uint) (fee-rate uint) (time-in-seconds uint))
  (div (* liquidity fee-rate time-in-seconds) u1000000)
)


;; Calculate amount of token-x for a given liquidity and price range
(define-read-only (calculate-amount-x (liquidity uint) (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint))
  (if (>= sqrt-price-current sqrt-price-upper)
    u0
    (if (<= sqrt-price-current sqrt-price-lower)
      (div (mul liquidity (sub sqrt-price-upper sqrt-price-lower)) (mul sqrt-price-lower sqrt-price-upper))
      (div (mul liquidity (sub sqrt-price-current sqrt-price-lower)) (mul sqrt-price-current sqrt-price-lower))
    )
  )
)

;; Calculate amount of token-y for a given liquidity and price range
(define-read-only (calculate-amount-y (liquidity uint) (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint))
  (if (<= sqrt-price-current sqrt-price-lower)
    u0
    (if (>= sqrt-price-current sqrt-price-upper)
      (mul liquidity (sub sqrt-price-upper sqrt-price-lower))
      (mul liquidity (sub sqrt-price-current sqrt-price-lower))
    )
  )
)