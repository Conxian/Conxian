;; ============================================================
;; TEST UTILITIES FOR CONXIAN PROTOCOL (v:0.1)
;; ============================================================
;; Reusable test utilities for the Conxian test suite

(use-trait token .sip-010-ft-trait.sip-010-ft-trait)
(use-trait dimensional-engine .dimensional-engine-interface.dimensional-engine-trait)

;; ======================
;; TEST ACCOUNTS
;; ======================

(define-constant ADMIN 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant ALICE 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(define-constant BOB 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)
(define-constant CHARLIE 'ST2NEB84ASENDXKYGJPQW86YXQCEFEX2ARQCPJME)
(define-constant DAVE 'ST2REHHS5J3CERCRBEPMGH7921Q6PYKAADT7JP2VB)
(define-constant EVE 'ST3AM1A56AK2C1XAFJ4115ZRT26GVJMYQBZ25YH6)

;; ======================
;; TOKEN HELPERS
;; ======================

;; Mint test tokens to an address
(define-public (mint-tokens (token-contract <sip-010-ft-trait>) (to principal) (amount uint))
  (contract-call? token-contract mint amount to)
)

;; Get token balance of an address
(define-read-only (get-balance (token-contract <sip-010-ft-trait>) (owner principal))
  (contract-call? token-contract get-balance owner)
)

;; Approve token spending
(define-public (approve-token (token-contract <sip-010-ft-trait>) (spender principal) (amount uint))
  (contract-call? token-contract approve spender amount (some "Test approval"))
)

;; ======================
;; POSITION HELPERS
;; ======================

;; Open a test position with default parameters
(define-public (open-test-position 
    (engine <dimensional-engine-trait>)
    (asset principal)
    (collateral uint)
    (leverage uint)
    (is-long bool)
  )
  (contract-call? engine open-position asset collateral leverage is-long none none)
)

;; Close a position with default slippage
(define-public (close-test-position (engine <dimensional-engine-trait>) (position-id uint))
  (contract-call? engine close-position position-id none)
)

;; Get position details
(define-read-only (get-position-details (engine <dimensional-engine-trait>) (position-id uint))
  (contract-call? engine get-position position-id)
)

;; ======================
;; ASSERTION HELPERS
;; ======================

;; Assert that a transaction succeeds
(define-public (assert-succeeded (result (response AnyType uint)))
  (match result
    (ok value) (ok true)
    (err code) (err (err-to-uint (err code)))
  )
)

;; Assert that a transaction fails with a specific error code
(define-public (assert-fails-with (result (response AnyType uint)) (expected-error uint))
  (match result
    (ok value) (err u1001) ;; ERR_ASSERTION_FAILED
    (err code) 
      (if (is-eq code expected-error)
        (ok true)
        (err (err-to-uint (err u1002))) ;; ERR_UNEXPECTED_ERROR
      )
  )
)

;; Assert two values are equal
(define-public (assert-eq (a AnyType) (b AnyType))
  (if (is-eq a b)
    (ok true)
    (err (err-to-uint (err u1003))) ;; ERR_NOT_EQUAL
  )
)

;; Assert a boolean is true
(define-public (assert-true (value bool))
  (if value
    (ok true)
    (err (err-to-uint (err u1004))) ;; ERR_NOT_TRUE
  )
)

;; ======================
;; ERROR CODES
;; ======================

(define-constant ERR_ASSERTION_FAILED u1000)
(define-constant ERR_UNEXPECTED_ERROR u1001)
(define-constant ERR_NOT_EQUAL u1002)
(define-constant ERR_NOT_TRUE u1003)

;; ======================
;; TIME HELPERS
;; ======================

;; Get current block height
(define-read-only (get-block-height)
  (ok block-height)
)

;; Advance blocks (simulate time passing)
(define-public (advance-blocks (count uint))
  (ok true) ;; Actual implementation depends on the test environment
)

;; ======================
;; MOCK HELPERS
;; ======================

;; Create a mock price feed
(define-read-only (mock-price (price uint) (decimals uint))
  (ok (* price (pow u10 decimals)))
)

;; Create a mock timestamp
(define-read-only (mock-timestamp (offset uint))
  (ok (+ block-height offset))
)
