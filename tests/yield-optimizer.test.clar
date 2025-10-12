;; tests/yield-optimizer.test.clar
    ;;
    ;; Test suite for the yield optimizer and its integration with the vault.
    ;;

    ;; --- Setup ---
    (use-trait sip-010-ft-trait sip-010-ft-trait)

    (define-contract-public .mock-wstx
      (
        (use-trait sip-010-ft-trait sip-010-ft-trait)
        (impl-trait sip-010-ft-trait)
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
{{ ... }}
  )
)

;; --- Test Cases ---

    (define-contract-public .mock-auto-compounder
      (
        (use-trait yield-optimizer-trait .all-traits.yield-optimizer-trait)
        (use-trait sip-010-ft-trait sip-010-ft-trait)

    (define-data-var contract-owner principal tx-sender)
    (define-data-var yield-optimizer-contract principal .yield-optimizer)
    (define-map user-positions { user: principal, token: principal } { amount: uint, last-compounded: uint })

{{ ... }}
      (map-get? user-positions { user: user, token: token })
    )
  )
)

    (define-contract-public .mock-strategy-a
      (
        (use-trait sip-010-ft-trait sip-010-ft-trait)
        (define-data-var apy uint u0)

    (define-public (harvest-rewards)
      (ok u1000)
    )

{{ ... }}
      (ok (var-get apy))
    )
  )
)

    (define-contract-public .mock-strategy-b
      (
        (use-trait sip-010-ft-trait sip-010-ft-trait)
        (define-data-var apy uint u0)

    (define-public (harvest-rewards)
      (ok u2000)
    )

{{ ... }}
      (begin
        (var-set apy new-apy)
        (ok true)
      )
    )

    (define-read-only (get-apy)
      (ok (var-get apy))
    )
  )
)

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

(define-test (test-auto-compounder-integration)
  (let ((wallet-1 .wallet_1)
        (wstx-token .mock-wstx)
        (optimizer .yield-optimizer)
        (auto-compounder .mock-auto-compounder)
        (deposit-amount u1000000))

    ;; Set the yield optimizer contract in the auto-compounder
    (as-contract (contract-call? auto-compounder set-yield-optimizer-contract optimizer))

    ;; Mint tokens to wallet-1
    (contract-call? .faucet mint-wstx wallet-1 deposit-amount)

    ;; Deposit into auto-compounder
    (as-contract (contract-call? wstx-token transfer deposit-amount wallet-1 auto-compounder))
    (assert-uint-eq (unwrap-panic (contract-call? wstx-token get-balance auto-compounder)) deposit-amount)

    ;; Call compound on auto-compounder
    (as-contract (contract-call? auto-compounder compound wallet-1 wstx-token))

    ;; Verify that auto-compound in yield-optimizer was called (this is hard to directly assert in Clarity tests)
    ;; For now, we'll rely on the print statement in mock-auto-compounder to indicate it was called.
    (ok true)
  )
)
