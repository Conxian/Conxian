;; standard-constants.clar
;; Implementation of standard constants for the Conxian protocol

(use-trait std-constants .standard-constants-trait)
(use-trait bond-trait .bond-trait)

;; ===== PRECISION CONSTANTS =====
(define-constant PRECISION_18 u1000000000000000000)  ;; 18 decimals
(define-constant PRECISION_8  u100000000)            ;; 8 decimals
(define-constant PRECISION_6  u1000000)              ;; 6 decimals
(define-constant BASIS_POINTS u10000)                ;; 100.00%

;; ===== TIME CONSTANTS (assuming ~1 block per minute) =====
(define-constant BLOCKS_PER_MINUTE u1)
(define-constant BLOCKS_PER_HOUR (* BLOCKS_PER_MINUTE u60))
(define-constant BLOCKS_PER_DAY (* BLOCKS_PER_HOUR u24))
(define-constant BLOCKS_PER_WEEK (* BLOCKS_PER_DAY u7))
(define-constant BLOCKS_PER_YEAR (* BLOCKS_PER_DAY u365))

;; ===== BOND-RELATED CONSTANTS =====
(define-constant BOND_DECIMALS u8)                   ;; 8 decimal places for bonds
(define-constant MAX_BOND_MATURITY (* BLOCKS_PER_YEAR u10))  ;; 10 years max
(define-constant MIN_BOND_AMOUNT u100000000)         ;; 1.0 bond with 8 decimals
(define-constant MAX_BOND_AMOUNT (* u1000000000000 u100000000)) ;; 1 trillion max
(define-constant MIN_BOND_DURATION (* BLOCKS_PER_DAY u30))     ;; 30 days minimum
(define-constant MAX_BOND_DURATION MAX_BOND_MATURITY

;; Bond status values
(define-constant BOND_STATUS_ACTIVE "active")
(define-constant BOND_STATUS_MATURED "matured")
(define-constant BOND_STATUS_DEFAULTED "defaulted")
(define-constant BOND_STATUS_CALLED "called")

;; ===== PERCENTAGE CONSTANTS =====
(define-constant ZERO u0)
(define-constant ONE_HUNDRED_PERCENT u10000)         ;; 100.00%
(define-constant FIFTY_PERCENT u5000)                ;; 50.00%
(define-constant TEN_PERCENT u1000)                  ;; 10.00%
(define-constant ONE_PERCENT u100)                   ;; 1.00%

;; ===== BOND TRAIT DEFINITION =====
(define-trait bond-trait
  ;; Get bond details
  ((get-bond-details (uint) (response {
    issuer: principal,
    principal-amount: uint,
    coupon-rate: uint,           ;; in basis points (100 = 1%)
    issue-block: uint,
    maturity-block: uint,
    collateral-amount: uint,
    collateral-token: principal,
    status: (string-ascii 20),
    is-callable: bool,
    call-premium: uint           ;; in basis points
  } uint))
  
  ;; Calculate accrued interest for a bond position
  (calculate-accrued-interest (uint) (response {
    accrued-interest: uint,
    last-updated: uint
  } uint))
  
  ;; Redeem a matured bond position
  (redeem-bond (uint) (response {
    principal-returned: uint,
    interest-paid: uint,
    collateral-returned: uint
  } uint))
  
  ;; Report coupon payment
  (report-coupon-payment (uint) (response {
    payment-amount: uint,
    payment-token: principal,
    payment-block: uint
  } uint))
  
  ;; Report bond maturity
  (report-bond-maturity (uint) (response {
    principal-amount: uint,
    maturity-block: uint
  } uint))
  
  ;; Get bond price in the secondary market
  (get-bond-price (uint) (response uint uint))
)

(impl-trait .standard-constants-trait)

(define-public (get-precision)
  (ok PRECISION_18))

(define-public (get-basis-points)
  (ok BASIS_POINTS))

(define-public (get-blocks-per-minute)
  (ok BLOCKS_PER_MINUTE))

(define-public (get-blocks-per-hour)
  (ok BLOCKS_PER_HOUR))

(define-public (get-blocks-per-day)
  (ok BLOCKS_PER_DAY))

(define-public (get-blocks-per-week)
  (ok BLOCKS_PER_WEEK))

(define-public (get-blocks-per-year)
  (ok BLOCKS_PER_YEAR))

(define-public (get-max-bps)
  (ok BASIS_POINTS))

(define-public (get-one-hundred-percent)
  (ok ONE_HUNDRED_PERCENT))

(define-public (get-fifty-percent)
  (ok FIFTY_PERCENT))

(define-public (get-zero)
  (ok ZERO))

(define-public (get-precision-18)
  (ok PRECISION_18))

(define-public (get-precision-8)
  (ok PRECISION_8))

(define-public (get-precision-6)
  (ok PRECISION_6))





