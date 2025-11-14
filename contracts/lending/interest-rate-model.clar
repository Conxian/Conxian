;; SPDX-License-Identifier: TBD

;; Interest Rate Model
;; This contract calculates interest rates for the dimensional vault.
(define-trait interest-rate-model-trait
  (
    ;; @desc Calculates the current borrow rate based on the utilization of assets in a lending pool.
    ;; @param utilization uint The current utilization of the vault, expressed as a percentage multiplied by 100 (e.g., 50% is u5000).
    ;; @returns (response uint uint) A response containing the borrow rate, expressed in basis points.
    (get-borrow-rate (uint) (response uint uint))
  )
)

;; --- Public Functions ---

;; @desc Calculates the borrow rate using a simple linear model.
;; @param utilization uint The current utilization of the vault.
;; @returns (response uint uint) The calculated borrow rate.
(define-public (get-borrow-rate (utilization uint))
  ;; A simple linear interest rate model: Rate = 2% + 0.05 * Utilization
  (ok (+ u200 (/ (* utilization u500) u10000))))
