(define-trait liquidation-trait
  (
    (is-liquidatable (user principal) (debt-asset principal) (collateral-asset principal) (response bool (err uint)))
    (liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
      (max-collateral-amount uint)
      (response (tuple (debt-repaid uint) (collateral-seized uint)) (err uint))
    )
    (liquidate-multiple-positions
      (positions (list 10 (tuple
        (borrower principal)
        (debt-asset principal)
        (collateral-asset principal)
        (debt-amount uint)
      )))
      (response (tuple (success-count uint) (total-debt-repaid uint) (total-collateral-seized uint)) (err uint))
    )
    (calculate-liquidation-amounts
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (response (tuple
        (debt-value uint)
        (collateral-value uint)
      ) (err uint))
    )
    (emergency-liquidate
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (response bool (err uint))
    )
  )
)
