;; error-handling-trait.clar
;; Shared error handling patterns and constants for Conxian contracts

;; ===== Standard Error Codes =====
;; Common errors (100-999)
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_NOT_FOUND u102)
(define-constant ERR_ALREADY_EXISTS u103)
(define-constant ERR_PAUSED u104)
(define-constant ERR_INVALID_INPUT u105)

;; DEX-specific errors (1000-1999)
(define-constant ERR_POOL_NOT_FOUND u1000)
(define-constant ERR_POOL_ALREADY_EXISTS u1001)
(define-constant ERR_INSUFFICIENT_LIQUIDITY u1002)
(define-constant ERR_SLIPPAGE_TOO_HIGH u1003)
(define-constant ERR_INVALID_TOKEN_PAIR u1004)

;; Dimensional errors (2000-2999)
(define-constant ERR_DIMENSION_NOT_CONFIGURED u2000)
(define-constant ERR_POSITION_NOT_FOUND u2001)
(define-constant ERR_INVALID_LEVERAGE u2002)
(define-constant ERR_MARGIN_CALL u2003)
(define-constant ERR_POSITION_CLOSED u2004)

;; Oracle errors (3000-3999)
(define-constant ERR_ORACLE_FAILURE u3000)
(define-constant ERR_STALE_PRICE u3001)
(define-constant ERR_INVALID_PRICE_RANGE u3002)

;; Staking errors (4000-4999)
(define-constant ERR_NO_STAKE_FOUND u4000)
(define-constant ERR_LOCKUP_NOT_EXPIRED u4001)
(define-constant ERR_INVALID_LOCK_PERIOD u4002)
(define-constant ERR_REWARDS_CLAIMED u4003)

;; ===== Common Guard Functions =====
(define-trait error-handling
  ((check-authorization (principal) (response bool uint))
   (validate-amount (uint) (response bool uint))
   (handle-error (uint) (response bool uint)))
)

;; ===== Standard Error Response Helper =====
(define-read-only (standard-error (error-code uint))
  (err error-code)
)

;; ===== Common Validation Functions =====
(define-read-only (is-valid-amount (amount uint))
  (and (> amount u0) (<= amount u340282366920938463463374607431768211455))
)

(define-read-only (is-valid-principal (addr principal))
  (is-some addr)
)

;; ===== Error Formatting =====
(define-read-only (format-error (context (string-ascii 64)) (error-code uint))
  {
    context: context,
    code: error-code,
    message: (default-to "Unknown error" (match error-code
      u100 "Unauthorized"
      u101 "Invalid amount"
      u102 "Not found"
      u103 "Already exists"
      u104 "Contract paused"
      u105 "Invalid input"
      u1000 "Pool not found"
      u1001 "Pool already exists"
      u1002 "Insufficient liquidity"
      u1003 "Slippage too high"
      u1004 "Invalid token pair"
      u2000 "Dimension not configured"
      u2001 "Position not found"
      u2002 "Invalid leverage"
      u2003 "Margin call"
      u2004 "Position closed"
      u3000 "Oracle failure"
      u3001 "Stale price"
      u3002 "Invalid price range"
      u4000 "No stake found"
      u4001 "Lockup not expired"
      u4002 "Invalid lock period"
      u4003 "Rewards already claimed"
      else "Unknown error"
    ))
  }
)
