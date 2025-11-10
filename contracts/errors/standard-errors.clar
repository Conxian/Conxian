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
        _ none
      )))
