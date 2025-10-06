(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(define-trait strategy-trait
  (
    ;; @notice Deposit funds into the strategy
    (deposit (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))

    ;; @notice Withdraw funds from the strategy
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))

    ;; @notice Harvest rewards from the strategy
    (harvest ()) (response bool (err uint))

    ;; @notice Rebalance the strategy
    (rebalance ()) (response bool (err uint))

    ;; @notice Get the current APY of the strategy
    (get-apy ()) (response uint (err uint))

    ;; @notice Get the total value locked (TVL) in the strategy
    (get-tvl ()) (response uint (err uint))

    ;; @notice Get the underlying token of the strategy
    (get-underlying-token ()) (response principal (err uint))

    ;; @notice Get the vault associated with this strategy
    (get-vault ()) (response principal (err uint))
  )
)
