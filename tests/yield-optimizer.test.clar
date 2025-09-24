;; tests/yield-optimizer.test.clar
;;
;; Test suite for the yield optimizer and its integration with the vault.
;;

;; --- Setup ---
(use-trait ft-trait .ft-trait)

(define-contract-public .mock-wstx
  (
    (impl-trait .ft-trait)
    (define-data-var name (string-ascii 32) "Wrapped Stacks")
    (define-data-var symbol (string-ascii 32) "wSTX")
    (define-data-var decimals uint u8)
    (define-map balances principal uint)
    (define-data-var total-supply uint u0)
    (define-data-var token-uri (string-utf8 256) u"")

    (define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
      (begin
        (asserts! (is-eq tx-sender sender) (err u1000))
        (asserts! (>= (get-balance sender) amount) (err u1001))
        (try! (debit sender amount))
        (try! (credit recipient amount))
        (ok true)
      )
    )
    (define-read-only (get-name) (ok (var-get name)))
    (define-read-only (get-symbol) (ok (var-get symbol)))
    (define-read-only (get-decimals) (ok (var-get decimals)))
    (define-read-only (get-balance (owner principal)) (ok (default-to u0 (map-get? balances owner))))
    (define-read-only (get-total-supply) (ok (var-get total-supply)))
    (define-public (set-token-uri (uri (string-utf8 256))) (begin (var-set token-uri uri) (ok true)))

    (define-private (credit (account principal) (amount uint))
      (map-set balances account (+ (get-balance account) amount))
      (var-set total-supply (+ (var-get total-supply) amount))
      (ok true)
    )
    (define-private (debit (account principal) (amount uint))
      (map-set balances account (- (get-balance account) amount))
      (var-set total-supply (- (var-get total-supply) amount))
      (ok true)
    )

    (define-public (mint (recipient principal) (amount uint))
      (begin
        (asserts! (is-eq tx-sender .faucet) (err u2000))
        (try! (credit recipient amount))
        (ok true)
      )
    )
  )
)

(define-contract-public .faucet
  (
    (define-public (mint-wstx (recipient principal) (amount uint))
      (contract-call? .mock-wstx mint recipient amount)
    )
  )
)

;; --- Test Cases ---

(define-test (test-full-rebalance-cycle)
  (let ((wallet-1 .wallet_1)
        (wstx-token .mock-wstx)
        (vault .vault)
        (optimizer .yield-optimizer)
        (metrics .mock-metrics)
        (strategy-a .mock-strategy-a)
        (strategy-b .mock-strategy-b)
        (deposit-amount u10000000000))

    ;; ### Phase 1: Setup ###
    (as-contract (contract-call? vault set-yield-optimizer optimizer))
    (as-contract (contract-call? optimizer set-contracts vault metrics))
    (as-contract (contract-call? optimizer add-strategy strategy-a))
    (as-contract (contract-call? optimizer add-strategy strategy-b))
    (as-contract (contract-call? vault add-supported-asset wstx-token u0))

    (contract-call? .faucet mint-wstx wallet-1 deposit-amount)
    (try! (contract-call? vault deposit wstx-token deposit-amount))
    (assert-uint-eq (unwrap-panic (get-balance vault wstx-token)) deposit-amount)

    ;; ### Phase 2: Rebalance to Strategy A ###
    (print "--- Phase 2: Rebalancing to Strategy A ---")
    (try! (contract-call? metrics set-metric strategy-a u0 u500)) ;; 5% APY
    (try! (contract-call? metrics set-metric strategy-b u0 u200)) ;; 2% APY

    (let ((rebalance-call (as-contract (contract-call? optimizer optimize-and-rebalance wstx-token))))
      (assert-is-ok rebalance-call)
      (assert-uint-eq (unwrap-panic (get-balance vault wstx-token)) u0)
      (assert-uint-eq (unwrap-panic (get-balance strategy-a wstx-token)) deposit-amount)
      (assert-uint-eq (unwrap-panic (get-balance strategy-b wstx-token)) u0)
    )

    ;; ### Phase 3: Rebalance to Strategy B ###
    (print "--- Phase 3: Rebalancing to Strategy B ---")
    (try! (contract-call? metrics set-metric strategy-a u0 u300)) ;; 3% APY
    (try! (contract-call? metrics set-metric strategy-b u0 u800)) ;; 8% APY

    ;; The vault needs to be the sender for the withdraw call to the strategy
    (as-contract (contract-call? optimizer optimize-and-rebalance wstx-token))

    ;; Verification
    (assert-uint-eq (unwrap-panic (get-balance vault wstx-token)) u0)
    (assert-uint-eq (unwrap-panic (get-balance strategy-a wstx-token)) u0)
    (assert-uint-eq (unwrap-panic (get-balance strategy-b wstx-token)) deposit-amount)

    (ok true)
  )
)

(define-read-only (get-balance (contract principal) (token principal))
  (contract-call? token get-balance contract)
)
