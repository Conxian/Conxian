;; sbtc-vault.clar (Refactored)
;; This contract acts as a facade, delegating logic to specialized contracts for custody,
;; yield aggregation, BTC bridging, and fee management.

(use-trait vault-trait .defi-traits.vault-trait)
(use-trait custody-trait .custody.custody-trait)
(use-trait yield-aggregator-trait .yield-aggregator.yield-aggregator-trait)
(use-trait fee-manager-trait .fee-manager.fee-manager-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_VAULT_PAUSED (err u2004))
(define-constant ERR_INVALID_AMOUNT (err u2003))

;; --- Data Variables ---

;; @desc The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @desc A boolean indicating if the vault is paused.
(define-data-var vault-paused bool false)
;; @desc The principal of the custody contract.
(define-data-var custody-contract principal .custody)
;; @desc The principal of the yield aggregator contract.
(define-data-var yield-aggregator-contract principal .yield-aggregator)
;; @desc The principal of the fee manager contract.
(define-data-var fee-manager-contract principal .fee-manager)
;; @desc The principal of the sBTC token contract.
(define-data-var sbtc-token-contract principal .sbtc-token)

;; --- Authorization ---

;; @desc Asserts that the transaction sender is the contract owner.
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

;; @desc Asserts that the vault is not paused.
(define-private (check-not-paused)
  (ok (asserts! (not (var-get vault-paused)) ERR_VAULT_PAUSED)))

;; --- Admin Functions ---

;; @desc Pauses or unpauses the vault.
;; @param paused bool The new paused status.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-vault-paused (paused bool))
  (begin
    (try! (check-is-owner))
    (var-set vault-paused paused)
    (ok true)))

;; @desc Sets the custody contract address.
;; @param contract principal The new custody contract principal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-custody-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set custody-contract contract)
    (ok true)))

;; @desc Sets the yield aggregator contract address.
;; @param contract principal The new yield aggregator contract principal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-yield-aggregator-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set yield-aggregator-contract contract)
    (ok true)))


;; @desc Sets the fee manager contract address.
;; @param contract principal The new fee manager contract principal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-fee-manager-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set fee-manager-contract contract)
    (ok true)))

;; --- Core Vault Functions ---

;; @desc Deposits sBTC into the vault.
;; @param token-contract <sip-010-ft-trait> The sBTC token contract.
;; @param amount uint The amount of sBTC to deposit.
;; @returns (response uint uint) The number of shares minted.
(define-public (deposit (token-contract <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-not-paused))
    (try! (contract-call? token-contract transfer amount tx-sender (as-contract tx-sender) none))
    (as-contract (contract-call? .custody deposit amount tx-sender))))

;; @desc Initiates a withdrawal from the vault.
;; @param token-contract <sip-010-ft-trait> The sBTC token contract.
;; @param shares uint The number of shares to burn.
;; @returns (response uint uint) The amount of sBTC to be withdrawn.
(define-public (withdraw (shares uint))
  (begin
    (try! (check-not-paused))
    (contract-call? .custody withdraw shares tx-sender)))

;; @desc Completes a withdrawal after the timelock period.
;; @param token-contract <sip-010-ft-trait> The sBTC token contract.
;; @returns (response uint uint) The amount of sBTC withdrawn.
(define-public (complete-withdrawal (token-contract <sip-010-ft-trait>))
  (let ((amount-response (try! (contract-call? .custody complete-withdrawal tx-sender))))
    (begin
      (try! (check-not-paused))
      (try! (as-contract (contract-call? token-contract transfer amount-response tx-sender tx-sender
        none
      )))
      (ok amount-response)
    )
  )
)

;; --- sBTC Deposit/Withdrawal ---

;; @desc Deposits sBTC into the vault.
;; @param amount uint The amount of sBTC to deposit.
;; @returns (response uint uint) The amount of sBTC deposited.
(define-public (sbtc-deposit (amount uint))
  (begin
    (try! (check-not-paused))
    (let ((fee (unwrap! (contract-call? .fee-manager calculate-fee "deposit" amount) (err u0))))
      (let ((net-amount (- amount fee)))
        (try! (as-contract (contract-call? .sbtc-token transfer net-amount tx-sender (as-contract tx-sender) none)))
        (ok net-amount)))))

;; @desc Withdraws sBTC from the vault.
;; @param amount uint The amount of sBTC to withdraw.
;; @returns (response uint uint) The amount of sBTC withdrawn.
(define-public (sbtc-withdraw (amount uint))
  (begin
    (try! (check-not-paused))
    (let ((fee (unwrap! (contract-call? .fee-manager calculate-fee "withdraw" amount) (err u0))))
      (let ((net-amount (- amount fee)))
        (as-contract (contract-call? .sbtc-token transfer net-amount (as-contract tx-sender) tx-sender none))))))

;; --- Yield Generation ---

;; @desc Allocates funds to a yield strategy.
;; @param strategy principal The principal of the strategy contract.
;; @param amount uint The amount of sBTC to allocate.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (allocate-to-strategy (strategy principal) (amount uint))
  (begin
    (try! (check-is-owner))
    (contract-call? .yield-aggregator allocate-to-strategy strategy amount)))

;; @desc Harvests yield from a strategy.
;; @param strategy principal The principal of the strategy contract.
;; @returns (response uint uint) The net yield harvested.
(define-public (harvest-yield (strategy principal))
  (begin
    (try! (check-is-owner))
    (let ((gross-yield (unwrap! (contract-call? .yield-aggregator harvest-yield strategy) (err u0))))
      (let ((fee (unwrap! (contract-call? .fee-manager calculate-fee "performance" gross-yield) (err u0))))
        (ok (- gross-yield fee))))))

;; --- Read-Only Functions ---

;; @desc Gets the vault's statistics.
;; @returns (response object uint) An object containing the vault's stats.
(define-read-only (get-vault-stats)
  ;; This would need to be updated to aggregate data from the different contracts
  (ok {
    total-sbtc: u0,
    total-shares: u0,
    total-yield: u0,
    share-price: u100000000,
    paused: (var-get vault-paused)
  }))
