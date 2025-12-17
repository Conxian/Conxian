;; advanced-order-manager.clar
;;
;; Manages the lifecycle of sophisticated order types, such as TWAP and Iceberg
;; orders.

(impl-trait .enterprise-traits.advanced-order-manager-trait)

(define-constant ERR_LIMIT_EXCEEDED (err u5001))

(define-map twap-orders
    { order-id: uint }
    {
        owner: principal,
        token-in: principal,
        token-out: principal,
        total-amount: uint,
        amount-per-interval: uint,
        interval-blocks: uint,
        remaining-amount: uint,
        last-execution: uint,
        active: bool,
    }
)

(define-map iceberg-orders
    { order-id: uint }
    {
        owner: principal,
        token-in: principal,
        token-out: principal,
        total-amount: uint,
        visible-amount: uint,
        remaining-amount: uint,
        active: bool,
    }
)

(define-data-var next-order-id uint u1)

(define-public (submit-twap-order
        (token-in principal)
        (token-out principal)
        (total-amount uint)
        (interval-blocks uint)
        (num-intervals uint)
    )
    (let (
            (order-id (var-get next-order-id))
            (amount-per-interval (/ total-amount num-intervals))
        )
        (asserts! (> total-amount u0) ERR_LIMIT_EXCEEDED)
        (asserts! (> num-intervals u0) ERR_LIMIT_EXCEEDED)
        (asserts! (> interval-blocks u0) ERR_LIMIT_EXCEEDED)

        (map-set twap-orders { order-id: order-id } {
            owner: tx-sender,
            token-in: token-in,
            token-out: token-out,
            total-amount: total-amount,
            amount-per-interval: amount-per-interval,
            interval-blocks: interval-blocks,
            remaining-amount: total-amount,
            last-execution: block-height,
            active: true,
        })

        (var-set next-order-id (+ order-id u1))
        (ok order-id)
    )
)

(define-public (submit-iceberg-order
        (token-in principal)
        (token-out principal)
        (total-amount uint)
        (visible-amount uint)
    )
    (let ((order-id (var-get next-order-id)))
        (asserts! (> total-amount u0) ERR_LIMIT_EXCEEDED)
        (asserts! (< visible-amount total-amount) ERR_LIMIT_EXCEEDED)

        (map-set iceberg-orders { order-id: order-id } {
            owner: tx-sender,
            token-in: token-in,
            token-out: token-out,
            total-amount: total-amount,
            visible-amount: visible-amount,
            remaining-amount: total-amount,
            active: true,
        })

        (var-set next-order-id (+ order-id u1))
        (ok order-id)
    )
)