;; SPDX-License-Identifier: TBD

;; Fee Manager
;; This contract manages all fees for the sBTC vault.
(define-trait fee-manager-trait
  (
    ;; @desc Calculates the fee for a given operation.
    ;; @param operation (string-ascii 64) The operation for which to calculate the fee.
    ;; @param amount uint The amount on which the fee is calculated.
    ;; @returns (response uint uint) A response containing the calculated fee or an error.
    (calculate-fee ((string-ascii 64) uint) (response uint uint))

    ;; @desc Sets the fee for a given operation.
    ;; @param operation (string-ascii 64) The operation for which to set the fee.
    ;; @param fee-bps uint The new fee in basis points.
    ;; @returns (response bool uint) A response indicating success or an error.
    (set-fee ((string-ascii 64) uint) (response bool uint))
  )
)

;; --- Data Storage ---

;; @desc The fee for wrapping BTC to sBTC, in basis points.
(define-data-var wrap-fee-bps uint u10)
;; @desc The fee for unwrapping sBTC to BTC, in basis points.
(define-data-var unwrap-fee-bps uint u10)
;; @desc The performance fee charged on yield, in basis points.
(define-data-var performance-fee-bps uint u1000)
;; @desc The management fee, in basis points.
(define-data-var management-fee-bps uint u200)

;; --- Public Functions ---

;; @desc Calculates the fee for a given operation. Can only be called by the sBTC vault.
;; @param operation (string-ascii 64) The operation ("wrap", "unwrap", "performance", "management").
;; @param amount uint The amount to calculate the fee on.
;; @returns (response uint uint) The calculated fee.
(define-public (calculate-fee (operation (string-ascii 64)) (amount uint))
  (begin
    (asserts! (is-eq tx-sender .sbtc-vault) (err u100))
    (cond
      ((is-eq operation "wrap") (ok (/ (* amount (var-get wrap-fee-bps)) u10000)))
      ((is-eq operation "unwrap") (ok (/ (* amount (var-get unwrap-fee-bps)) u10000)))
      ((is-eq operation "performance") (ok (/ (* amount (var-get performance-fee-bps)) u10000)))
      ((is-eq operation "management") (ok (/ (* amount (var-get management-fee-bps)) u10000)))
      (else (err u3001))
    )
  )
)

;; @desc Sets the fee for a given operation. Can only be called by the sBTC vault.
;; @param operation (string-ascii 64) The operation ("wrap", "unwrap", "performance", "management").
;; @param fee-bps uint The new fee in basis points.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-fee (operation (string-ascii 64)) (fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender .sbtc-vault) (err u100))
    (cond
      ((is-eq operation "wrap") (var-set wrap-fee-bps fee-bps))
      ((is-eq operation "unwrap") (var-set unwrap-fee-bps fee-bps))
      ((is-eq operation "performance") (var-set performance-fee-bps fee-bps))
      ((is-eq operation "management") (var-set management-fee-bps fee-bps))
      (else (err u3001))
    )
    (ok true)
  )
)
