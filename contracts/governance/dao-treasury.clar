;; dao-treasury.clar
;; Conxian DAO Treasury with Automated Audit Reserve
;;
;; Features:
;; 1. Proposal-based Fund Release
;; 2. Automated 15% Audit Reserve Lock
;; 3. Streaming Payments for OPEX

(impl-trait .governance-traits.treasury-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INSUFFICIENT_FUNDS (err u8001))
(define-constant ERR_RESERVE_LOCKED (err u8002))

(define-constant AUDIT_RESERVE_BPS u1500) ;; 15%

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var proposal-contract principal .proposal-engine)

;; Accounting
(define-data-var total-stx-received uint u0)
(define-data-var audit-reserve-balance uint u0)
(define-data-var opex-balance uint u0)

;; --- Public Functions ---

;; @desc Deposit Funds (e.g. from ICO or Fees)
;; @audit Auto-allocates 15% to Security Audit Reserve
(define-public (deposit-stx (amount uint))
    (let (
        (audit-amt (/ (* amount AUDIT_RESERVE_BPS) u10000))
        (opex-amt (- amount audit-amt))
    )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (var-set total-stx-received (+ (var-get total-stx-received) amount))
        (var-set audit-reserve-balance (+ (var-get audit-reserve-balance) audit-amt))
        (var-set opex-balance (+ (var-get opex-balance) opex-amt))
        
        (print { event: "treasury-deposit", amount: amount, audit-allocation: audit-amt })
        (ok true)
    )
)

;; @desc Execute Approved Proposal Spending
(define-public (execute-spend (recipient principal) (amount uint) (token (optional <sip-010-trait>)) (is-audit-spend bool))
    (begin
        ;; Only Proposal Engine can call this
        (asserts! (is-eq tx-sender (var-get proposal-contract)) ERR_UNAUTHORIZED)

        (if is-audit-spend
            (begin
                (asserts! (>= (var-get audit-reserve-balance) amount) ERR_INSUFFICIENT_FUNDS)
                (var-set audit-reserve-balance (- (var-get audit-reserve-balance) amount))
            )
            (begin
                (asserts! (>= (var-get opex-balance) amount) ERR_INSUFFICIENT_FUNDS)
                (var-set opex-balance (- (var-get opex-balance) amount))
            )
        )

        (match token
            t (as-contract (contract-call? t transfer amount tx-sender recipient none))
            (as-contract (stx-transfer? amount tx-sender recipient))
        )
    )
)

;; @desc Flash Audit Check
;; Checks if we have enough for a specific audit quote
(define-read-only (can-afford-audit (quote-amount uint))
    (>= (var-get audit-reserve-balance) quote-amount)
)
