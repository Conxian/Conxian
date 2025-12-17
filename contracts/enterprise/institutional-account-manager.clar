;; institutional-account-manager.clar
;;
;; Manages the lifecycle of institutional accounts, including registration,
;; tiering, and permissions.

(impl-trait .enterprise-traits.account-manager-trait)

(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_LIMIT_EXCEEDED (err u5001))

(define-data-var contract-owner principal tx-sender)

(define-map institutional-accounts
    { account: principal }
    {
        tier: uint,
        daily-limit: uint,
        daily-spent: uint,
        last-reset: uint,
        kyc-verified: bool,
    }
)

(define-public (register-account
        (account principal)
        (tier uint)
        (limit uint)
    )
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set institutional-accounts { account: account } {
            tier: tier,
            daily-limit: limit,
            daily-spent: u0,
            last-reset: block-height,
            kyc-verified: true,
        })
        (ok true)
    )
)

(define-read-only (get-account-details (account principal))
    (map-get? institutional-accounts { account: account })
)

(define-public (check-and-update-daily-spent (account principal) (amount uint))
    (let ((info (unwrap! (map-get? institutional-accounts { account: account }) ERR_UNAUTHORIZED)))
        (let ((new-spent (if (> (- block-height (get last-reset info)) u144)
                amount
                (+ (get daily-spent info) amount)
            )))
            (asserts! (<= new-spent (get daily-limit info)) ERR_LIMIT_EXCEEDED)
            (map-set institutional-accounts { account: account } (merge info { daily-spent: new-spent, last-reset: block-height }))
            (ok true)
        )
    )
)