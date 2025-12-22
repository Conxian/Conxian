;; economic-policy-engine.clar
;; "Central Bank" Logic for Conxian Protocol
;; Dynamically adjusts fees, rewards, and interest rates based on system health.

(use-trait fee-manager-trait .defi-traits.fee-manager-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant BLOCKS_PER_DAY u248832000) ;; u144 * 120 for NakamotoTA
(define-constant ERR_STALE_DATA (err u1001))

;; Thresholds
(define-constant TARGET_UTILIZATION u8000) ;; 80%
(define-constant MAX_OPEX_RATIO u8000) ;; OpEx should not exceed 80% of Revenue

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var protocol-fee-switch principal .protocol-fee-switch)
(define-data-var operational-treasury principal .operational-treasury)
(define-data-var tier-manager principal .tier-manager)

;; Economic State
(define-data-var current-mode (string-ascii 16) "NORMAL") ;; NORMAL, AUSTERITY, GROWTH
(define-data-var last-adjustment-block uint u0)
(define-data-var adjustment-cooldown uint u144) ;; ~1 day

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Core Logic ---

;; @desc Main heartbeat function called by Keepers
;; @param revenue: Total revenue in last period (from analytics)
;; @param burn-rate: Operational burn rate (from treasury)
;; @param utilization: Lending utilization (bps)
(define-public (execute-policy-adjustment
    (revenue uint)
    (burn-rate uint)
    (utilization uint)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED) ;; Keepers only
    (asserts!
      (> (- block-height (var-get last-adjustment-block))
        (var-get adjustment-cooldown)
      )
      ERR_STALE_DATA
    )

    ;; 1. Determine Economic Mode
    (let ((opex-ratio (if (> revenue u0)
        (/ (* burn-rate u10000) revenue)
        u10000
      )))
      (if (> opex-ratio MAX_OPEX_RATIO)
        (try! (activate-austerity-mode))
        (if (< opex-ratio u2000) ;; < 20% OpEx
          (try! (activate-growth-mode))
          (try! (activate-normal-mode))
        )
      )
    )

    ;; 2. Adjust Interest Rates based on Utilization
    ;; (Simplified logic - normally would call interest-rate-model setter)

    (var-set last-adjustment-block block-height)
    (ok true)
  )
)

(define-private (activate-austerity-mode)
  (begin
    (var-set current-mode "AUSTERITY")
    (print {
      event: "economic-mode-change",
      mode: "AUSTERITY",
    })

    ;; Increase Protocol Fees to capture more revenue
    (try! (contract-call? .protocol-fee-switch set-module-fee "DEX" u50)) ;; 0.5%

    ;; Reduce Treasury/Staking Split (Keep more for OpEx)
    (contract-call? .protocol-fee-switch set-fee-splits u5000 u3000 u2000 u0) ;; 50% Treasury
  )
)

(define-private (activate-growth-mode)
  (begin
    (var-set current-mode "GROWTH")
    (print {
      event: "economic-mode-change",
      mode: "GROWTH",
    })

    ;; Lower Fees to encourage volume
    (try! (contract-call? .protocol-fee-switch set-module-fee "DEX" u25)) ;; 0.25%

    ;; Increase Staking Rewards
    (contract-call? .protocol-fee-switch set-fee-splits u1000 u8000 u1000 u0) ;; 80% Staking
  )
)

(define-private (activate-normal-mode)
  (begin
    (var-set current-mode "NORMAL")
    (print {
      event: "economic-mode-change",
      mode: "NORMAL",
    })

    ;; Standard Fees
    (try! (contract-call? .protocol-fee-switch set-module-fee "DEX" u30)) ;; 0.3%
    (contract-call? .protocol-fee-switch set-fee-splits u2000 u6000 u2000 u0) ;; 20/60/20
  )
)

;; --- Read Only ---

(define-read-only (get-current-mode)
  (ok (var-get current-mode))
)
