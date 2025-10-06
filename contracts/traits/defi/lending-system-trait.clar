(define-trait lending-system-trait
  (
    (deposit (asset principal) (amount uint) (response bool (err uint)))
    (withdraw (asset principal) (amount uint) (response bool (err uint)))
    (borrow (asset principal) (amount uint) (response bool (err uint)))
    (repay (asset principal) (amount uint) (response bool (err uint)))
    (liquidate (liquidator principal) (borrower principal) (repay-asset principal) (collateral-asset principal) (repay-amount uint) (response bool (err uint)))
    (get-account-liquidity (user principal) (response (tuple (liquidity uint) (shortfall uint)) (err uint)))
    (get-asset-price (asset principal) (response uint (err uint)))
    (get-borrow-rate (asset principal) (response uint (err uint)))
    (get-supply-rate (asset principal) (response uint (err uint)))
  )
)
