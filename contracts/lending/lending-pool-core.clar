;; SPDX-License-Identifier: TBD

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

;; Lending Pool Core
;; This contract contains the central state management and logic for the lending pool.
(define-trait lending-pool-core-trait
  (
    ;; @desc Deposits an asset into the lending pool.
    ;; @param asset principal The contract principal of the asset to deposit.
    ;; @param amount uint The amount of the asset to deposit.
    ;; @param on-behalf-of principal The user for whom the deposit is being made.
    ;; @returns (response bool uint) `(ok true)` on success.
    (deposit (asset <sip-010-ft-trait>) (amount uint) (on-behalf-of principal) (response bool uint))

    ;; @desc Withdraws an asset from the lending pool.
    ;; @param asset principal The contract principal of the asset to withdraw.
    ;; @param amount uint The amount of the asset to withdraw.
    ;; @param to principal The user to whom the asset will be sent.
    ;; @returns (response bool uint) `(ok true)` on success.
    (withdraw (asset <sip-010-ft-trait>) (amount uint) (to principal) (response bool uint))

    ;; @desc Borrows an asset from the lending pool.
    ;; @param asset principal The contract principal of the asset to borrow.
    ;; @param amount uint The amount of the asset to borrow.
    ;; @param on-behalf-of principal The user for whom the borrow is being made.
    ;; @returns (response bool uint) `(ok true)` on success.
    (borrow (principal, uint, principal) (response bool uint))

    ;; @desc Repays a borrowed asset to the lending pool.
    ;; @param asset principal The contract principal of the asset to repay.
    ;; @param amount uint The amount of the asset to repay.
    ;; @param on-behalf-of principal The user for whom the repayment is being made.
    ;; @returns (response bool uint) `(ok true)` on success.
    (repay (principal, uint, principal) (response bool uint))
  )
)

(impl-trait .lending-pool-core-trait)


(define-constant ERR_AMOUNT_MUST_BE_POSITIVE (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))


;; --- Data Storage ---

;; @desc Stores the reserves data for each asset.
(define-map reserves { asset: principal } {
  total-supply: uint,
  total-borrows: uint,
  last-updated-block: uint
})

;; @desc Stores the user data for each asset.
(define-map user-reserves { user: principal, asset: principal } {
  collateral: bool,
  balance: uint
})

;; --- Public Functions ---

;; @desc Deposits an asset into the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to deposit.
;; @param on-behalf-of principal The user to deposit on behalf of.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (deposit (asset <sip-010-ft-trait>) (amount uint) (on-behalf-of principal))
  (begin
    (asserts! (> amount u0) ERR_AMOUNT_MUST_BE_POSITIVE)
    (try! (ft-transfer? asset amount tx-sender (as-contract tx-sender)))

    (let ((asset-principal (contract-of asset)))
      (let ((reserve (default-to {total-supply: u0, total-borrows: u0, last-updated-block: u0} (map-get? reserves {asset: asset-principal}))))
        (map-set reserves {asset: asset-principal} (merge reserve {
          total-supply: (+ (get total-supply reserve) amount),
          last-updated-block: block-height
        }))
      )

      (let ((user-reserve (default-to {collateral: false, balance: u0} (map-get? user-reserves {user: on-behalf-of, asset: asset-principal}))))
        (map-set user-reserves {user: on-behalf-of, asset: asset-principal} (merge user-reserve {
          balance: (+ (get balance user-reserve) amount)
        }))
      )

      (print {
        event: "deposit",
        asset: asset-principal,
        user: on-behalf-of,
        amount: amount
      })
      (ok true)
    )
  )
)

;; @desc Withdraws an asset from the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to withdraw.
;; @param to principal The user to withdraw to.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (withdraw (asset <sip-010-ft-trait>) (amount uint) (to principal))
  (begin
    (asserts! (> amount u0) ERR_AMOUNT_MUST_BE_POSITIVE)
    (let ((asset-principal (contract-of asset))
          (user-reserve (unwrap! (map-get? user-reserves {user: tx-sender, asset: asset-principal}) (err ERR_INSUFFICIENT_BALANCE)))
          (reserve (unwrap! (map-get? reserves {asset: asset-principal}) (err u201))))
      (asserts! (>= (get balance user-reserve) amount) ERR_INSUFFICIENT_BALANCE)

      (try! (as-contract (ft-transfer? asset amount to)))

      (map-set reserves {asset: asset-principal} (merge reserve {
        total-supply: (- (get total-supply reserve) amount),
        last-updated-block: block-height
      }))
      (map-set user-reserves {user: tx-sender, asset: asset-principal} (merge user-reserve {
        balance: (- (get balance user-reserve) amount)
      }))

      (print {
        event: "withdraw",
        asset: asset-principal,
        user: to,
        amount: amount
      })
      (ok true)
    )
  )
)

;; @desc Borrows an asset from the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to borrow.
;; @param on-behalf-of principal The user to borrow on behalf of.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (borrow (asset <sip-010-ft-trait>) (amount uint) (on-behalf-of principal))
  (begin
    (asserts! (> amount u0) ERR_AMOUNT_MUST_BE_POSITIVE)
    ;; TODO: Add collateral checks
    (let ((asset-principal (contract-of asset))
          (reserve (unwrap! (map-get? reserves {asset: asset-principal}) (err u201))))
      (asserts! (>= (get total-supply reserve) amount) (err ERR_INSUFFICIENT_BALANCE))

      (try! (as-contract (ft-transfer? asset amount on-behalf-of)))

      (map-set reserves {asset: asset-principal} (merge reserve {
        total-borrows: (+ (get total-borrows reserve) amount),
        last-updated-block: block-height
      }))

      (print {
        event: "borrow",
        asset: asset-principal,
        user: on-behalf-of,
        amount: amount
      })
      (ok true)
    )
  )
)

;; @desc Repays a borrowed asset to the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to repay.
;; @param on-behalf-of principal The user to repay on behalf of.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (repay (asset <sip-010-ft-trait>) (amount uint) (on-behalf-of principal))
  (begin
    (asserts! (> amount u0) ERR_AMOUNT_MUST_BE_POSITIVE)
    (try! (ft-transfer? asset amount tx-sender (as-contract tx-sender)))

    (let ((asset-principal (contract-of asset))
          (reserve (unwrap! (map-get? reserves {asset: asset-principal}) (err u201))))
      (map-set reserves {asset: asset-principal} (merge reserve {
        total-borrows: (- (get total-borrows reserve) amount),
        last-updated-block: block-height
      }))

      (print {
        event: "repay",
        asset: asset-principal,
        user: on-behalf-of,
        amount: amount
      })
      (ok true)
    )
  )
)

(define-public (set-collateral (asset principal) (as-collateral bool))
  (let ((user-reserve (unwrap! (map-get? user-reserves {user: tx-sender, asset: asset}) (err u202))))
    (map-set user-reserves {user: tx-sender, asset: asset} (merge user-reserve {
      collateral: as-collateral
    }))
    (ok true)
  )
)

(define-public (add-asset (asset principal) (governance principal))
  (begin
    (asserts! (is-eq tx-sender governance) (err u301))
    (map-set reserves {asset: asset} {
      total-supply: u0,
      total-borrows: u0,
      last-updated-block: block-height
    })
    (ok true)
  )
)
