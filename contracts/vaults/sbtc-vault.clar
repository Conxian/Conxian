;; sbtc-vault.clar (Refactored)
;; This contract acts as a facade, delegating logic to specialized contracts for custody,
;; yield aggregation, BTC bridging, and fee management.

(use-trait vault-trait .vault-trait)
(use-trait custody-trait .custody.custody-trait)
(use-trait yield-aggregator-trait .yield-aggregator.yield-aggregator-trait)
(use-trait btc-bridge-trait .btc-bridge.btc-bridge-trait)
(use-trait fee-manager-trait .fee-manager.fee-manager-trait)

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
;; @desc The principal of the BTC bridge contract.
(define-data-var btc-bridge-contract principal .btc-bridge)
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

;; @desc Sets the BTC bridge contract address.
;; @param contract principal The new BTC bridge contract principal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-btc-bridge-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set btc-bridge-contract contract)
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
;; @param token-contract principal The sBTC token contract.
;; @param amount uint The amount of sBTC to deposit.
;; @returns (response uint uint) The number of shares minted.
(define-public (deposit (token-contract principal) (amount uint))
  (begin
    (try! (check-not-paused))
    (contract-call? (var-get custody-contract) deposit token-contract amount tx-sender)))

;; @desc Initiates a withdrawal from the vault.
;; @param token-contract principal The sBTC token contract.
;; @param shares uint The number of shares to burn.
;; @returns (response uint uint) The amount of sBTC to be withdrawn.
(define-public (withdraw (token-contract principal) (shares uint))
  (begin
    (try! (check-not-paused))
    (contract-call? (var-get custody-contract) withdraw token-contract shares tx-sender)))

;; @desc Completes a withdrawal from the vault.
;; @param token-contract principal The sBTC token contract.
;; @returns (response uint uint) The amount of sBTC withdrawn.
(define-public (complete-withdrawal (token-contract principal))
  (contract-call? (var-get custody-contract) complete-withdrawal token-contract tx-sender))

;; --- Bitcoin Wrapping/Unwrapping ---

;; @desc Wraps BTC to sBTC.
;; @param btc-amount uint The amount of BTC to wrap.
;; @param btc-txid (buff 32) The Bitcoin transaction ID.
;; @returns (response uint uint) The amount of sBTC minted.
(define-public (wrap-btc (btc-amount uint) (btc-txid (buff 32)))
  (begin
    (try! (check-not-paused))
    (let ((fee (unwrap! (contract-call? (var-get fee-manager-contract) calculate-fee "wrap" btc-amount) (err u0))))
      (let ((net-amount (- btc-amount fee)))
        (contract-call? (var-get btc-bridge-contract) wrap-btc net-amount btc-txid tx-sender)))))

;; @desc Unwraps sBTC to BTC.
;; @param sbtc-amount uint The amount of sBTC to unwrap.
;; @param btc-address (buff 64) The destination BTC address.
;; @returns (response uint uint) The amount of BTC to be sent.
(define-public (unwrap-to-btc (sbtc-amount uint) (btc-address (buff 64)))
  (begin
    (try! (check-not-paused))
    (let ((fee (unwrap! (contract-call? (var-get fee-manager-contract) calculate-fee "unwrap" sbtc-amount) (err u0))))
      (let ((net-amount (- sbtc-amount fee)))
        (contract-call? (var-get btc-bridge-contract) unwrap-to-btc net-amount btc-address tx-sender)))))

;; --- Yield Generation ---

;; @desc Allocates funds to a yield strategy.
;; @param strategy principal The principal of the strategy contract.
;; @param amount uint The amount of sBTC to allocate.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (allocate-to-strategy (strategy principal) (amount uint))
  (begin
    (try! (check-is-owner))
    (contract-call? (var-get yield-aggregator-contract) allocate-to-strategy strategy amount)))

;; @desc Harvests yield from a strategy.
;; @param strategy principal The principal of the strategy contract.
;; @returns (response uint uint) The net yield harvested.
(define-public (harvest-yield (strategy principal))
  (begin
    (try! (check-is-owner))
    (let ((gross-yield (unwrap! (contract-call? (var-get yield-aggregator-contract) harvest-yield strategy) (err u0))))
      (let ((fee (unwrap! (contract-call? (var-get fee-manager-contract) calculate-fee "performance" gross-yield) (err u0))))
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
