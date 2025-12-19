;; SPDX-License-Identifier: TBD

;; Custody Contract
;; This contract manages the custody of sBTC deposits and withdrawals for the sBTC vault.

(define-trait custody-trait (
  (deposit
    (principal uint principal)
    (response uint uint)
  )
  (withdraw
    (principal uint principal)
    (response uint uint)
  )
  (complete-withdrawal
    (principal principal)
    (response uint uint)
  )
))

;; --- Data Storage ---

;; @desc Stores the deposit information for each user.
(define-map user-deposits
  principal
  {
    sbtc-amount: uint,
    shares: uint,
    deposited-at: uint,
    last-claim: uint,
    total-claimed: uint,
  }
)

;; @desc Stores withdrawal requests, which are subject to a timelock.
(define-map withdrawal-requests
  principal
  {
    amount: uint,
    requested-at: uint,
    unlock-at: uint,
    btc-address: (buff 64),
  }
)

;; @desc Stores the share balance for each user.
(define-map share-balances
  principal
  uint
)

;; @desc Stores the total amount of sBTC deposited in the contract.
(define-data-var total-sbtc-deposited uint u0)

;; @desc Stores the total number of shares minted.
(define-data-var total-shares-minted uint u0)

;; @desc The number of blocks for the withdrawal timelock. (Nakamoto-adjusted: 12 days * 17280 blocks/day)
(define-constant WITHDRAWAL_DELAY_BLOCKS u207360)

;; --- Private Functions ---

;; @desc Calculates the number of shares to mint for a given amount of sBTC.
;; @param sbtc-amount uint The amount of sBTC being deposited.
;; @returns uint The number of shares to be minted.
(define-private (calculate-shares-to-mint (sbtc-amount uint))
  (let (
      (total-sbtc (var-get total-sbtc-deposited))
      (total-shares (var-get total-shares-minted))
    )
    (if (is-eq total-shares u0)
      ;; Burn 1000 shares
      (if (> sbtc-amount u1000)
        (- sbtc-amount u1000)
        u0
      )
      (/ (* sbtc-amount total-shares) total-sbtc)
    )
  )
)

;; @desc Calculates the amount of sBTC corresponding to a given number of shares.
;; @param shares uint The number of shares.
;; @returns uint The corresponding amount of sBTC.
(define-private (calculate-sbtc-from-shares (shares uint))
  (let (
      (total-sbtc (var-get total-sbtc-deposited))
      (total-shares (var-get total-shares-minted))
    )
    (if (is-eq total-shares u0)
      u0
      (/ (* shares total-sbtc) total-shares)
    )
  )
)

;; --- Public Functions ---

;; @desc Deposits sBTC into the contract. Can only be called by the sBTC vault.
;; @param token-contract principal The sBTC token contract.
;; @param amount uint The amount of sBTC to deposit.
;; @param recipient principal The user depositing the sBTC.
;; @returns (response uint uint) The number of shares minted.
(define-public (deposit
    (amount uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender .sbtc-vault) (err u100))
    (let ((shares (calculate-shares-to-mint amount)))
      (match (map-get? user-deposits recipient)
        existing (map-set user-deposits recipient {
          sbtc-amount: (+ (get sbtc-amount existing) amount),
          shares: (+ (get shares existing) shares),
          deposited-at: (get deposited-at existing),
          last-claim: block-height,
          total-claimed: (get total-claimed existing),
        })
        (map-set user-deposits recipient {
          sbtc-amount: amount,
          shares: shares,
          deposited-at: block-height,
          last-claim: block-height,
          total-claimed: u0,
        })
      )
      (map-set share-balances recipient
        (+ (default-to u0 (map-get? share-balances recipient)) shares)
      )
      (var-set total-sbtc-deposited (+ (var-get total-sbtc-deposited) amount))
      (var-set total-shares-minted
        (+ (var-get total-shares-minted)
          (if (is-eq (var-get total-shares-minted) u0)
            (+ shares u1000)
            shares
          ))
      )
      (ok shares)
    )
  )
)

;; @desc Initiates a withdrawal. Can only be called by the sBTC vault.
;; @param token-contract principal The sBTC token contract.
;; @param shares uint The number of shares to burn.
;; @param recipient principal The user withdrawing sBTC.
;; @returns (response uint uint) The amount of sBTC to be withdrawn.
(define-public (withdraw
    (shares uint)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender .sbtc-vault) (err u100))
    (let ((user-shares (default-to u0 (map-get? share-balances recipient))))
      (asserts! (>= user-shares shares) (err u2002))
      (let ((sbtc-amount (calculate-sbtc-from-shares shares)))
        (map-set withdrawal-requests recipient {
          amount: sbtc-amount,
          requested-at: burn-block-height,
          unlock-at: (+ burn-block-height WITHDRAWAL_DELAY_BLOCKS),
          btc-address: 0x00,
        })
        (map-set share-balances recipient (- user-shares shares))
        (var-set total-shares-minted (- (var-get total-shares-minted) shares))
        (ok sbtc-amount)
      )
    )
  )
)

;; @desc Completes a withdrawal after the timelock. Can only be called by the sBTC vault.
;; @param token-contract principal The sBTC token contract.
;; @param recipient principal The user completing the withdrawal.
;; @returns (response uint uint) The amount of sBTC withdrawn.
(define-public (complete-withdrawal (recipient principal))
  (begin
    (asserts! (is-eq tx-sender .sbtc-vault) (err u100))
    (let ((request (unwrap! (map-get? withdrawal-requests recipient) (err u2001))))
      (asserts! (>= burn-block-height (get unlock-at request)) (err u2005))
      (let ((amount (get amount request)))
        (map-delete withdrawal-requests recipient)
        (var-set total-sbtc-deposited (- (var-get total-sbtc-deposited) amount))
        (ok amount)
      )
    )
  )
)
