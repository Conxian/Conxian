(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)


(define-trait staking-trait
  (
    ;; @notice Stake tokens
    (stake (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))

    ;; @notice Unstake tokens
    (unstake (token-contract <sip-010-ft-trait>) (amount uint) (response uint (err uint)))

    ;; @notice Claim rewards
    (claim-rewards (token-contract <sip-010-ft-trait>) (response uint (err uint)))

    ;; @notice Get the amount of staked tokens for a user
    (get-staked-balance (token-contract <sip-010-ft-trait>) (user principal) (response uint (err uint)))

    ;; @notice Get the amount of available rewards for a user
    (get-available-rewards (token-contract <sip-010-ft-trait>) (user principal) (response uint (err uint)))

    ;; @notice Get the total staked supply of a token
    (get-total-staked (token-contract <sip-010-ft-trait>) (response uint (err uint)))

    ;; @notice Set the reward rate (admin only)
    (set-reward-rate (token-contract <sip-010-ft-trait>) (rate uint) (response bool (err uint)))

    ;; @notice Get the reward rate
    (get-reward-rate (token-contract <sip-010-ft-trait>) (response uint (err uint)))
  )
)
