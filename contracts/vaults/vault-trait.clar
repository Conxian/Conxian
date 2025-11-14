;; SPDX-License-Identifier: TBD

;; Trait for an sBTC Vault
;; This trait defines the standard interface for a vault that manages sBTC deposits,
;; withdrawals, and yield generation.
(define-trait vault-trait
  (
    ;; --- Core Vault Functions ---

    ;; @desc Deposits sBTC into the vault and mints shares representing the user's portion of the vault's assets.
    ;; @param token-contract <sip-010-ft-trait> A trait reference to the sBTC token contract, ensuring it conforms to the SIP-010 standard.
    ;; @param amount uint The amount of sBTC to deposit, denominated in the smallest unit of sBTC.
    ;; @returns (response uint uint) A response containing the number of shares minted for the user, or an error code if the deposit fails.
    (deposit (trait_reference, uint) (response uint uint))

    ;; @desc Requests the withdrawal of sBTC from the vault by burning a specified number of shares. This initiates a timelock period.
    ;; @param token-contract <sip-010-ft-trait> A trait reference to the sBTC token contract.
    ;; @param shares uint The number of shares to burn in exchange for sBTC.
    ;; @returns (response uint uint) A response containing the amount of sBTC that will be available for withdrawal after the timelock, or an error.
    (withdraw (trait_reference, uint) (response uint uint))

    ;; @desc Completes the withdrawal process after the timelock period has passed, transferring the sBTC to the user.
    ;; @param token-contract <sip-010-ft-trait> A trait reference to the sBTC token contract.
    ;; @returns (response uint uint) A response containing the amount of sBTC transferred to the user, or an error if the withdrawal is not yet unlocked or fails.
    (complete-withdrawal (trait_reference) (response uint uint))

    ;; --- Bitcoin Wrapping/Unwrapping ---

    ;; @desc Initiates the process of wrapping BTC into sBTC. This function is typically called after a BTC transaction has been confirmed.
    ;; @param btc-amount uint The amount of BTC to wrap, denominated in satoshis.
    ;; @param btc-txid (buff 32) The transaction ID of the BTC deposit on the Bitcoin blockchain.
    ;; @returns (response uint uint) A response containing the amount of sBTC minted as a result of the wrap, or an error.
    (wrap-btc (uint, (buff 32)) (response uint uint))

    ;; @desc Initiates the process of unwrapping sBTC back into BTC.
    ;; @param sbtc-amount uint The amount of sBTC to unwrap.
    ;; @param btc-address (buff 64) The destination Bitcoin address where the BTC will be sent.
    ;; @returns (response uint uint) A response containing the amount of BTC that will be sent, or an error.
    (unwrap-to-btc (uint, (buff 64)) (response uint uint))

    ;; --- Yield Generation ---

    ;; @desc Allocates a specified amount of sBTC from the vault to a yield-generating strategy contract.
    ;; @param strategy principal The principal of the strategy contract to which the funds will be allocated.
    ;; @param amount uint The amount of sBTC to allocate to the strategy.
    ;; @returns (response bool uint) A response indicating `(ok true)` on successful allocation, or an error.
    (allocate-to-strategy (principal, uint) (response bool uint))

    ;; @desc Harvests yield earned from a specific strategy, bringing the profits back into the main vault.
    ;; @param strategy principal The principal of the strategy contract from which to harvest yield.
    ;; @returns (response uint uint) A response containing the net yield harvested from the strategy, or an error.
    (harvest-yield (principal) (response uint uint))

    ;; --- Read-Only Functions ---

    ;; @desc Retrieves a summary of the vault's key statistics.
    ;; @returns (response { total-sbtc: uint, total-shares: uint, total-yield: uint, share-price: uint, paused: bool } uint) A response containing a tuple with the total sBTC deposited, total shares minted, total yield generated, the current price per share, and the vault's paused status.
    (get-vault-stats () (response {
      total-sbtc: uint,
      total-shares: uint,
      total-yield: uint,
      share-price: uint,
      paused: bool
    } uint))
  )
)
