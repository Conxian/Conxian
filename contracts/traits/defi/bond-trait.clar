(define-trait bond-trait
  (
    (issue-bond (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (initial-supply uint) (maturity-in-blocks uint) (coupon-rate-scaled uint) (frequency-in-blocks uint) (payment-token-address principal) (response bool (err uint)))
    (claim-coupon () (response uint (err uint)))
    (redeem-at-maturity (payment-token principal) (response uint (err uint)))
    (get-maturity-block () (response uint (err uint)))
    (get-coupon-rate () (response uint (err uint)))
    (get-face-value () (response uint (err uint)))
    (get-payment-token () (response principal (err uint)))
    (is-matured () (response bool (err uint)))
    (get-next-coupon-block (user principal) (response (optional uint) (err uint)))
  )
)
