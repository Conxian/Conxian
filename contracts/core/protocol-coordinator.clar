;; protocol-coordinator.clar
;; This contract is the central authority for the new tokenomics model, managing:
;; 1. The "Genesis Node" sale (minting Yield Tokens for STX).
;; 2. Liquidity mining incentives (minting Yield Tokens for LPs).
;; 3. The Token Generation Event (TGE), converting Yield Tokens to Governance Tokens.

(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_SALE_NOT_ACTIVE (err u102))
(define-constant ERR_INVALID_TOKEN_CONTRACT (err u103))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var treasury-address principal tx-sender)
(define-data-var yield-token-contract principal .yield-token)
(define-data-var governance-token-contract principal .governance-token)
(define-data-var vesting-contract principal tx-sender)
(define-data-var yield-per-block uint u10) ;; Default to 10 micro-yield per block
(define-data-var genesis-node-price uint u500000000) ;; 500 STX in micro-STX
(define-data-var genesis-node-yield-amount uint u1000000000) ;; 1000 Yield Tokens
(define-data-var genesis-sale-active bool false)

;; --- Data Maps ---
(define-map genesis-node-purchases
  principal
  {
    purchased: bool,
    amount-paid: uint,
    yield-tokens-minted: uint
  }
)

;; --- Liquidity Mining ---

(define-constant THREE_MONTH_LOCK u129600) ;; Approx. 3 months in blocks
(define-constant SIX_MONTH_LOCK u259200) ;; Approx. 6 months in blocks
(define-constant TWELVE_MONTH_LOCK u518400) ;; Approx. 12 months in blocks
(define-constant TWENTY_FOUR_MONTH_LOCK u1036800) ;; Approx. 24 months in blocks

(define-constant MULTIPLIER_3_MONTHS u125) ;; 1.25x
(define-constant MULTIPLIER_6_MONTHS u150) ;; 1.5x
(define-constant MULTIPLIER_12_MONTHS u200) ;; 2.0x
(define-constant MULTIPLIER_24_MONTHS u400) ;; 4.0x

(define-map liquidity-deposits
  principal
  {
    stx-amount: uint,
    start-height: uint,
    lock-period: uint,
    multiplier: uint,
    last-claim-height: uint
  }
)

;; --- Token Generation Event (TGE) ---

(define-constant CONVERSION_RATE_LIQUID u50) ;; 100 Yield -> 50 Gov (Liquid)
(define-constant CONVERSION_RATE_VESTED u100) ;; 100 Yield -> 100 Gov (Vested)

(define-public (convert-yield-to-governance (amount uint) (vest bool))
  (begin
    (let ((user tx-sender)
          (yield-token (var-get yield-token-contract))
          (governance-token (var-get governance-token-contract))
          (conversion-rate (if vest CONVERSION_RATE_VESTED CONVERSION_RATE_LIQUID))
          (gov-amount-to-mint (/ (* amount conversion-rate) u100)))

      ;; 1. Burn the user's Yield Tokens
      (try! (contract-call? (var-get yield-token-contract) burn amount user))

      ;; 2. Mint new Governance Tokens
      (if vest
        ;; Mint to the vesting contract, which will manage the lockup
        (try! (contract-call? (var-get governance-token-contract) mint gov-amount-to-mint (var-get vesting-contract)))
        ;; Mint directly to the user for the liquid option
        (try! (contract-call? (var-get governance-token-contract) mint gov-amount-to-mint user)))

      (print {
        event: "tge-conversion",
        user: user,
        yield-burned: amount,
        gov-minted: gov-amount-to-mint,
        vested: vest
      })
      (ok true)
    )
  )
)

;; Helper for testing
(define-public (mint-yield-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (try! (contract-call? (var-get yield-token-contract) mint amount recipient))
    (ok true)
  )
)

(define-read-only (get-liquidity-deposit (user principal))
  (map-get? liquidity-deposits user)
)

(define-public (withdraw-liquidity)
  (begin
    (let ((user tx-sender)
          (deposit (unwrap! (map-get? liquidity-deposits user) (err u404)))
          (unlock-height (+ (get start-height deposit) (get lock-period deposit))))

      (asserts! (>= block-height unlock-height) (err u405)) ;; ERR_STILL_LOCKED

      (try! (as-contract (stx-transfer? (get stx-amount deposit) tx-sender user)))

      (map-delete liquidity-deposits user)

      (print {
        event: "liquidity-withdrawal",
        user: user,
        amount: (get stx-amount deposit)
      })
      (ok true)
    )
  )
)

(define-public (set-token-contracts (yield-token principal) (governance-token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set yield-token-contract yield-token)
    (var-set governance-token-contract governance-token)
    (ok true)
  )
)

(define-public (set-yield-per-block (new-yield-per-block uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set yield-per-block new-yield-per-block)
    (ok true)
  )
)

(define-public (set-vesting-contract (new-vesting-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set vesting-contract new-vesting-contract)
    (ok true)
  )
)

(define-public (toggle-genesis-sale (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set genesis-sale-active active)
    (ok true)
  )
)

;; --- Genesis Node Sale ---
(define-public (purchase-genesis-node)
  (begin
    (asserts! (var-get genesis-sale-active) ERR_SALE_NOT_ACTIVE)

    (let ((price (var-get genesis-node-price))
          (yield-amount (var-get genesis-node-yield-amount))
          (buyer tx-sender)
          (treasury (var-get treasury-address))
          (yield-token (var-get yield-token-contract)))

      ;; Transfer STX to the treasury
      (try! (stx-transfer? price buyer treasury))

      ;; Mint Yield Tokens to the buyer
      (try! (contract-call? (var-get yield-token-contract) mint yield-amount buyer))

      ;; Record the purchase
      (map-set genesis-node-purchases buyer {
        purchased: true,
        amount-paid: price,
        yield-tokens-minted: yield-amount
      })

      (print {
        event: "genesis-node-purchase",
        buyer: buyer,
        price: price,
        yield-minted: yield-amount
      })
      (ok true)
    )
  )
)

(define-public (claim-rewards)
  (begin
    (let ((user tx-sender)
          (deposit (unwrap! (map-get? liquidity-deposits user) (err u404)))
          (yield-token (var-get yield-token-contract))
          (blocks-passed (- block-height (get last-claim-height deposit)))
          (base-reward (* blocks-passed (var-get yield-per-block)))
          (total-reward (/ (* base-reward (get multiplier deposit)) u100)))

      (asserts! (> total-reward u0) (err u0)) ;; No rewards to claim

      (try! (contract-call? (var-get yield-token-contract) mint total-reward user))

      ;; Update the last claim height to prevent double counting
      (map-set liquidity-deposits user
        (merge deposit { last-claim-height: block-height })
      )

      (print {
        event: "yield-claim",
        user: user,
        reward: total-reward
      })
      (ok true)
    )
  )
)

(define-public (deposit-liquidity (stx-amount uint) (lock-period uint))
  (begin
    (let ((depositor tx-sender)
          (multiplier (if (is-eq lock-period THREE_MONTH_LOCK) MULTIPLIER_3_MONTHS
                        (if (is-eq lock-period SIX_MONTH_LOCK) MULTIPLIER_6_MONTHS
                          (if (is-eq lock-period TWELVE_MONTH_LOCK) MULTIPLIER_12_MONTHS
                            (if (is-eq lock-period TWENTY_FOUR_MONTH_LOCK) MULTIPLIER_24_MONTHS
                              u100))))))

      ;; Transfer STX from the user to this contract
      (try! (stx-transfer? stx-amount depositor (as-contract tx-sender)))

      (map-set liquidity-deposits depositor {
        stx-amount: stx-amount,
        start-height: block-height,
        lock-period: lock-period,
        multiplier: multiplier,
        last-claim-height: block-height
      })

      (print {
        event: "liquidity-deposit",
        depositor: depositor,
        stx-amount: stx-amount,
        lock-period: lock-period,
        multiplier: multiplier
      })
      (ok true)
    )
  )
)
