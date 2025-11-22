;; File: contracts/errors/standard-errors.clar
;; Centralized error codes and messages for the Conxian protocol

;; ===========================================
;; General errors (1000-1099)
;; ===========================================
(define-constant ERR_UNKNOWN u1000)
(define-constant ERR_NOT_OWNER u1001)
(define-constant ERR_ZERO_ADDRESS u1002)
(define-constant ERR_PAUSED u1003)
(define-constant ERR_INVALID_INPUT u1004)
(define-constant ERR_TRANSFER_PENDING u1005)
(define-constant ERR_NO_PENDING_OWNER u1006)
(define-constant ERR_NOT_PENDING_OWNER u1007)
(define-constant ERR_ALREADY_INITIALIZED u1008)
(define-constant ERR_NOT_INITIALIZED u1009)
(define-constant ERR_UPGRADE_REQUIRED u1010)

;; ===========================================
;; Access control (1100-1199)
;; ===========================================
(define-constant ERR_UNAUTHORIZED u1100)
(define-constant ERR_ROLE_NOT_FOUND u1101)
(define-constant ERR_MISSING_ROLE u1102)
(define-constant ERR_INVALID_ROLE u1103)
(define-constant ERR_ROLE_ALREADY_GRANTED u1104)
(define-constant ERR_ROLE_NOT_GRANTED u1105)

;; ===========================================
;; Token operations (1200-1299)
;; ===========================================
(define-constant ERR_INSUFFICIENT_BALANCE u1200)
(define-constant ERR_INSUFFICIENT_ALLOWANCE u1201)
(define-constant ERR_TRANSFER_FAILED u1202)
(define-constant ERR_APPROVAL_FAILED u1203)
(define-constant ERR_MINTING_DISABLED u1204)
(define-constant ERR_BURNING_DISABLED u1205)
(define-constant ERR_TRANSFER_TO_SELF u1206)
(define-constant ERR_ZERO_AMOUNT u1207)
(define-constant ERR_EXCEEDS_BALANCE u1208)
(define-constant ERR_EXCEEDS_ALLOWANCE u1209)

;; ===========================================
;; Vault operations (1300-1399)
;; ===========================================
(define-constant ERR_VAULT_PAUSED u1300)
(define-constant ERR_INVALID_AMOUNT u1301)
(define-constant ERR_WITHDRAWAL_LOCKED u1302)
(define-constant ERR_UNWRAP_FAILED u1303)
(define-constant ERR_WRAP_FAILED u1304)
(define-constant ERR_BRIDGE_ERROR u1305)
(define-constant ERR_INVALID_BTC_ADDRESS u1306)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1307)
(define-constant ERR_WITHDRAWAL_TOO_SOON u1308)
(define-constant ERR_DEPOSIT_CAP_REACHED u1309)
(define-constant ERR_INVALID_ASSET u1310)               ;; Invalid or unsupported asset
(define-constant ERR_INSUFFICIENT_COLLATERAL u1311)     ;; Insufficient collateral for operation

;; ===========================================
;; Math operations (1400-1499)
;; ===========================================
(define-constant ERR_OVERFLOW u1400)
(define-constant ERR_UNDERFLOW u1401)
(define-constant ERR_DIVISION_BY_ZERO u1402)
(define-constant ERR_MATH_APPROXIMATION u1403)
(define-constant ERR_NEGATIVE_NUMBER u1404)
(define-constant ERR_PRECISION_LOSS u1405)

;; ===========================================
;; Oracle operations (1500-1599)
;; ===========================================
(define-constant ERR_STALE_PRICE u1500)
(define-constant ERR_NO_PRICE u1501)
(define-constant ERR_PRICE_TOO_OLD u1502)
(define-constant ERR_PRICE_OUT_OF_BOUNDS u1503)
(define-constant ERR_INVALID_PRICE_FEED u1504)
(define-constant ERR_PRICE_VOLATILE u1505)
(define-constant ERR_POR_MISSING u1506)                 ;; Proof of Reserves attestation missing
(define-constant ERR_POR_STALE u1507)                   ;; Proof of Reserves attestation stale
(define-constant ERR_GET_AMOUNT_IN_FAILED (err u1410)) ;; New error code for get amount in failed
(define-constant ERR_ROUTE_ALREADY_EXECUTED (err u1411)) ;; New error code for route already executed
(define-constant ERR_REENTRANCY_GUARD_TRIGGERED (err u1412)) ;; New error code for reentrancy guard triggered
(define-constant ERR_SLIPPAGE_TOLERANCE_EXCEEDED (err u1413)) ;; New error code for slippage tolerance exceeded
(define-constant ERR_INVALID_PATH (err u1414)) ;; New error code for invalid path
(define-constant ERR_SWAP_FAILED (err u1415)) ;; New error code for swap failed
(define-constant ERR_TOKEN_TRANSFER_FAILED (err u1416)) ;; New error code for token transfer failed

;; ===========================================
;; ORACLE OPERATIONS
;; ===========================================

;; ===========================================
;; Helper function for error messages
;; ===========================================
(define-read-only (get-error-message (code uint))
  (ok (match code
    ERR_UNKNOWN (some (as-max-len? u"Unknown error" u100))
    ERR_NOT_OWNER (some (as-max-len? u"Caller is not owner" u100))
    ERR_PAUSED (some (as-max-len? u"Contract is paused" u100))
    ERR_UNAUTHORIZED (some (as-max-len? u"Unauthorized access" u100))
    ERR_INSUFFICIENT_BALANCE (some (as-max-len? u"Insufficient balance" u100))
    ERR_INSUFFICIENT_ALLOWANCE (some (as-max-len? u"Insufficient allowance" u100))
    ERR_INVALID_AMOUNT (some (as-max-len? u"Invalid amount" u100))
    ERR_OVERFLOW (some (as-max-len? u"Arithmetic overflow" u100))
    ERR_UNDERFLOW (some (as-max-len? u"Arithmetic underflow" u100))
    ERR_DIVISION_BY_ZERO (some (as-max-len? u"Division by zero" u100))
    ERR_STALE_PRICE (some (as-max-len? u"Stale price data" u100))
    ERR_NO_PRICE (some (as-max-len? u"No price available" u100))
    ERR_INVALID_ASSET (some (as-max-len? u"Invalid or unsupported asset" u100))
    ERR_INSUFFICIENT_COLLATERAL (some (as-max-len? u"Insufficient collateral for operation" u100))
    ERR_POR_MISSING (some (as-max-len? u"Proof of Reserves attestation missing" u100))
    ERR_POR_STALE (some (as-max-len? u"Proof of Reserves attestation stale" u100))
    other-code
    none
  ))
)

(define-constant err-invalid-pool-type (err u1500))
(define-constant err-pool-already-exists (err u1501))
(define-constant err-asset-not-found (err u1502))
(define-constant err-circuit-open (err u1503))
(define-constant err-commit-exists (err u1600))
(define-constant err-commit-not-found (err u1601))
(define-constant err-reveal-window-closed (err u1602))
(define-constant err-reveal-window-open (err u1603))
(define-constant err-invalid-order-hash (err u1604))
(define-constant err-auction-not-active (err u1605))
(define-constant err-auction-active (err u1606))
(define-constant err-bid-window-closed (err u1607))

(define-read-only (get-error-message (code uint))
  (ok (lookup-error-message code)))

(define-constant err-invalid-pool-type (err u1500))
(define-constant err-pool-already-exists (err u1501))
(define-constant err-asset-not-found (err u1502))
(define-constant err-circuit-open (err u1503))
(define-constant err-commit-exists (err u1600))
(define-constant err-commit-not-found (err u1601))
(define-constant err-reveal-window-closed (err u1602))
(define-constant err-reveal-window-open (err u1603))
(define-constant err-invalid-order-hash (err u1604))
(define-constant err-auction-not-active (err u1605))
(define-constant err-auction-active (err u1606))
(define-constant err-bid-window-closed (err u1607))
(define-constant err-bid-too-low (err u1608))
(define-constant err-invalid-auction-id (err u1609))
(define-constant err-mev-detected (err u1610))
(define-constant err-delayed-execution-not-met (err u1611))
(define-constant err-invalid-protection-level (err u1612))
(define-constant err-account-not-found (err u1700))
(define-constant err-invalid-tier (err u1701))
(define-constant err-invalid-order (err u1702))
(define-constant err-order-not-found (err u1703))
(define-constant err-account-not-verified (err u1704))
(define-constant err-invalid-fee-discount (err u1705))
(define-constant err-invalid-privilege (err u1706))
(define-constant err-dex-router-not-set (err u1707))
(define-constant err-compliance-hook-not-set (err u1708))
(define-constant err-circuit-breaker-not-set (err u1709))
(define-constant err-order-already-executed (err u1710))
(define-constant err-order-expired (err u1711))
(define-constant err-insufficient-funds (err u1712))
(define-constant err-invalid-api-key (err u1713))
(define-constant err-api-key-expired (err u1714))
(define-constant ERR_INVALID_API_KEY (err u1715))

;; Yield Optimizer Errors (u1800 - u1815)
(define-constant ERR_YIELD_UNAUTHORIZED (err u1800))
(define-constant ERR_YIELD_STRATEGY_ALREADY_EXISTS (err u1801))
(define-constant ERR_YIELD_STRATEGY_NOT_FOUND (err u1802))
(define-constant ERR_YIELD_REBALANCE_FAILED (err u1803))
(define-constant ERR_YIELD_INVALID_CONTRACT (err u1804))
(define-constant ERR_YIELD_METRICS_CALL_FAILED (err u1805))
(define-constant ERR_YIELD_ENGINE_NOT_SET (err u1806))
(define-constant ERR_YIELD_STRATEGY_INACTIVE (err u1807))
(define-constant ERR_YIELD_ZERO_AMOUNT (err u1808))
(define-constant ERR_YIELD_DEPOSIT_FAILED (err u1809))
(define-constant ERR_YIELD_WITHDRAW_FAILED (err u1810))
(define-constant ERR_YIELD_NO_ACTIVE_STRATEGIES (err u1811))
(define-constant ERR_YIELD_INVALID_ALLOCATION (err u1812))
(define-constant ERR_YIELD_OPTIMIZATION_FAILED (err u1813))
(define-constant ERR_YIELD_AUTO_COMPOUND_FAILED (err u1814))
(define-constant ERR_YIELD_UNSUPPORTED_ASSET (err u1815))
