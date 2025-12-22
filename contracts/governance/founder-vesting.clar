;; founder-vesting.clar
;; Standard Vesting Contract for Founder Allocation
;;
;; Features:
;; 1. Supports multiple tokens (CXD, CXVG, CXLP, etc.)
;; 2. Linear vesting with Cliff
;; 3. Beneficiary is hardcoded (or set once) to Founder
;; 4. Revocable only by Governance (optional, sticking to irrevocable for trust)

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_NOTHING_TO_CLAIM (err u8001))
(define-constant ERR_VESTING_NOT_STARTED (err u8002))

;; Vesting Parameters (Standard 4-year vesting, 1-year cliff)
(define-constant VESTING_DURATION u25228800) ;; 4 years in Nakamoto blocks (6,307,200 * 4)
(define-constant CLIFF_DURATION u6307200) ;; 1 year in Nakamoto blocks (5s blocks)

;; --- Data Variables ---
(define-data-var founder-address principal tx-sender)
(define-data-var start-block uint u0)
(define-data-var is-initialized bool false)

;; Token Tracking: Token -> { total-allocated, claimed }
(define-map vesting-schedule
  principal
  {
    total-allocated: uint,
    amount-claimed: uint,
  }
)

;; --- Admin / Initialization ---

(define-public (initialize (founder principal))
  (begin
    (asserts! (not (var-get is-initialized)) (err u1006))
    (var-set founder-address founder)
    (var-set start-block block-height)
    (var-set is-initialized true)
    (ok true)
  )
)

;; @desc Register a token allocation for vesting
;; Can be called by anyone depositing tokens, but typically the Genesis Allocator
(define-public (add-vesting-allocation
    (token <sip-010-trait>)
    (amount uint)
  )
  (let (
      (token-contract (contract-of token))
      (current-schedule (default-to {
        total-allocated: u0,
        amount-claimed: u0,
      }
        (map-get? vesting-schedule token-contract)
      ))
    )
    ;; Transfer tokens to this contract
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))

    ;; Update Schedule
    (map-set vesting-schedule token-contract {
      total-allocated: (+ (get total-allocated current-schedule) amount),
      amount-claimed: (get amount-claimed current-schedule),
    })
    (print {
      event: "vesting-added",
      token: token-contract,
      amount: amount,
    })
    (ok true)
  )
)

;; --- Claiming ---

(define-read-only (get-claimable-amount (token principal))
  (let (
      (schedule (unwrap! (map-get? vesting-schedule token) ERR_NOTHING_TO_CLAIM))
      (total (get total-allocated schedule))
      (claimed (get amount-claimed schedule))
      (current-height block-height)
      (start (var-get start-block))
    )
    (ok (if (< current-height (+ start CLIFF_DURATION))
      u0 ;; In Cliff
      (if (>= current-height (+ start VESTING_DURATION))
        (- total claimed) ;; Fully Vested
        (let (
            (time-passed (- current-height start))
            (vested (/ (* total time-passed) VESTING_DURATION))
          )
          (if (> vested claimed)
            (- vested claimed)
            u0
          )
        )
      )
    ))
  )
)

(define-public (claim (token <sip-010-trait>))
  (let (
      (token-contract (contract-of token))
      (claimable (unwrap! (get-claimable-amount token-contract) ERR_NOTHING_TO_CLAIM))
      (schedule (unwrap! (map-get? vesting-schedule token-contract) ERR_NOTHING_TO_CLAIM))
    )
    (asserts! (is-eq tx-sender (var-get founder-address)) ERR_UNAUTHORIZED)
    (asserts! (> claimable u0) ERR_NOTHING_TO_CLAIM)

    ;; Update State
    (map-set vesting-schedule token-contract
      (merge schedule { amount-claimed: (+ (get amount-claimed schedule) claimable) })
    )

    ;; Transfer Tokens
    (as-contract (try! (contract-call? token transfer claimable tx-sender (var-get founder-address)
      none
    )))

    (print {
      event: "vesting-claimed",
      token: token-contract,
      amount: claimable,
      recipient: (var-get founder-address),
    })
    (ok claimable)
  )
)
