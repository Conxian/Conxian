(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(define-trait vault-trait
  (
    ;; @notice Deposit funds into the vault
    (deposit (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))

    ;; @notice Withdraw funds from the vault
    (withdraw (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))

    ;; @notice Get the current total supply of shares for a token
    (get-total-shares (token-contract <sip-010-ft-trait>) (response uint (err uint)))

    ;; @notice Get the amount of underlying tokens for a given amount of shares
    (get-amount-out-from-shares (token-contract <sip-010-ft-trait>) (shares uint) (response uint (err uint)))

    ;; @notice Get the amount of shares for a given amount of underlying tokens
    (get-shares-from-amount-in (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))

    ;; @notice Harvest rewards (admin only)
    (harvest (token-contract <sip-010-ft-trait>) (response bool (err uint)))

    ;; @notice Set the strategy for a given token (admin only)
    (set-strategy (token-contract <sip-010-ft-trait>) (strategy-contract principal) (response bool (err uint)))

    ;; @notice Get the current strategy for a given token
    (get-strategy (token-contract <sip-010-ft-trait>) (response (optional principal) (err uint)))

    ;; @notice Get the current APY for a given token
    (get-apy (token-contract <sip-010-ft-trait>) (response uint (err uint)))

    ;; @notice Get the total value locked (TVL) for a given token
    (get-tvl (token-contract <sip-010-ft-trait>) (response uint (err uint)))
  )
)
