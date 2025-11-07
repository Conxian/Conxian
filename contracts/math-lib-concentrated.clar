(define-constant LIB .concentrated-math)

(define-read-only (sqrt-price-x96-to-tick (sqrt-price uint))
  (contract-call? LIB sqrt-price-to-tick sqrt-price))

(define-read-only (tick-to-sqrt-price-x96 (tick int))
  (contract-call? LIB tick-to-sqrt-price tick))

(define-read-only (get-liquidity-for-amounts (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint) (amount-x uint) (amount-y uint))
  (contract-call? LIB get-liquidity-for-amounts sqrt-price-current sqrt-price-lower sqrt-price-upper amount-x amount-y))

(define-read-only (get-amounts-for-liquidity (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint) (liquidity uint))
  (let (
        (amount0 (if (> sqrt-price-current sqrt-price-lower)
                    (/ (* liquidity (- sqrt-price-current sqrt-price-lower)) sqrt-price-current)
                    u0))
        (amount1 (if (< sqrt-price-current sqrt-price-upper)
                    (* liquidity (- sqrt-price-upper sqrt-price-current))
                    u0))
       )
    (ok (tuple (amount0 amount0) (amount1 amount1)))))

(define-read-only (get-amount-out (sqrt-price-current uint) (liquidity uint) (amount-in uint) (zero-for-one bool))
  (let ((fee (/ (* amount-in u30) u10000)))
    (ok (- amount-in fee))))

(define-read-only (get-next-sqrt-price-from-input (sqrt-price-current uint) (liquidity uint) (amount-in uint) (zero-for-one bool))
  (let ((delta (if (> sqrt-price-current u0) (/ sqrt-price-current u1000) u0)))
    (ok (if zero-for-one
          (if (> sqrt-price-current delta) (- sqrt-price-current delta) u0)
          (+ sqrt-price-current delta)))))

(define-read-only (tick-to-sqrt-price (tick int))
  (contract-call? LIB tick-to-sqrt-price tick))

(define-read-only (sqrt-price-to-tick (sqrt-price uint))
  (contract-call? LIB sqrt-price-to-tick sqrt-price))

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint) (tick-spacing uint))
  (match (contract-call? LIB sqrt-price-to-tick sqrt-price)
    t (ok t)
    e (err e)))
