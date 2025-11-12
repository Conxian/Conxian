;; ===========================================
;; STAKING TRAIT
;; ===========================================
;; Interface for staking tokens and earning rewards.
;;
;; This trait provides functions for users to stake tokens, unstake them,
;; and claim accumulated rewards.
;;
;; Example usage:
;;   (use-trait staking-trait .staking-trait.staking-trait)
(define-trait staking-trait
  (
    ;; @desc Stakes tokens into the contract.
    ;; @param amount The number of tokens to stake.
    ;; @returns (response bool uint) True if successful, or an error.
    (stake (amount uint)) (response bool uint))

    ;; @desc Unstakes tokens from the contract.
    ;; @param amount The number of tokens to unstake.
    ;; @returns (response bool uint) True if successful, or an error.
    (unstake (amount uint)) (response bool uint))

    ;; @desc Claims accumulated rewards.
    ;; @returns (response bool uint) True if successful, or an error.
    (claim-rewards () (response bool uint))

    ;; @desc Returns the amount of tokens staked by a principal.
    ;; @param owner The principal to query the staked amount for.
    ;; @returns (response uint uint) The staked amount.
    (get-staked-amount (owner principal)) (response uint uint))

    ;; @desc Returns the amount of rewards available for a principal.
    ;; @param owner The principal to query the rewards for.
    ;; @returns (response uint uint) The available rewards.
    (get-rewards (owner principal)) (response uint uint))
  )
)
