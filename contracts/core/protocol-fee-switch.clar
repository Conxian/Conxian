;; protocol-fee-switch.clar
;; Centralized Fee Management System for Conxian Protocol
;;
;; Responsibilities:
;; 1. Maintain dynamic fee rates for all protocol modules (DEX, Lending, NFT, etc.)
;; 2. Manage fee split recipients (Treasury, Stakers, Insurance Fund, Burn)
;; 3. Allow governance to update parameters without contract upgrades
;; 4. Provide a single source of truth for "Active Profitability" logic

(impl-trait .defi-traits.fee-manager-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_FEE (err u1001))
(define-constant ERR_INVALID_SHARE (err u1002))
(define-constant ERR_INVALID_RECIPIENT (err u1003))

;; Max total fee (100%)
(define-constant MAX_BPS u10000)

;; Module Identifiers
(define-constant MODULE_DEX "DEX")
(define-constant MODULE_LENDING "LENDING")
(define-constant MODULE_NFT "NFT")
(define-constant MODULE_STAKING "STAKING")
(define-constant MODULE_SBTC "SBTC")

;; Contract principal for this fee switch. Fees are held by this contract
;; and routed out to recipients.
(define-constant FEE_SWITCH_CONTRACT .protocol-fee-switch)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var policy-engine principal tx-sender)

;; Fee Configurations per Module
;; Key: Module Name
;; Value: Base Fee in BPS (e.g., 30 = 0.3%)
(define-map module-fees
  (string-ascii 32)
  uint
)

;; Fee Split Configurations
;; Where does the collected fee go?
;; Total shares must sum to 10000 (100%)
(define-data-var treasury-share-bps uint u2000) ;; 20% to Ops/Treasury
(define-data-var staking-share-bps uint u6000) ;; 60% to veToken Stakers
(define-data-var insurance-share-bps uint u2000) ;; 20% to Insurance Fund
(define-data-var burn-share-bps uint u0) ;; 0% Burn (Optional)

;; Recipients
(define-data-var treasury-address principal tx-sender)
(define-data-var staking-address principal tx-sender)
(define-data-var insurance-address principal tx-sender)

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized)
  (or (is-owner) (is-eq tx-sender (var-get policy-engine)))
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-policy-engine (new-engine principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set policy-engine new-engine)
    (ok true)
  )
)

(define-public (set-module-fee
    (module (string-ascii 32))
    (fee-bps uint)
  )
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (<= fee-bps MAX_BPS) ERR_INVALID_FEE)
    (map-set module-fees module fee-bps)
    (print {
      event: "fee-updated",
      module: module,
      new-fee: fee-bps,
    })
    (ok true)
  )
)

(define-public (set-fee-splits
    (treasury uint)
    (staking uint)
    (insurance uint)
    (burn uint)
  )
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (asserts! (is-eq (+ (+ (+ treasury staking) insurance) burn) MAX_BPS)
      ERR_INVALID_SHARE
    )

    (var-set treasury-share-bps treasury)
    (var-set staking-share-bps staking)
    (var-set insurance-share-bps insurance)
    (var-set burn-share-bps burn)

    (print {
      event: "splits-updated",
      treasury: treasury,
      staking: staking,
      insurance: insurance,
      burn: burn,
    })
    (ok true)
  )
)

(define-public (set-recipients
    (treasury principal)
    (staking principal)
    (insurance principal)
  )
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set treasury-address treasury)
    (var-set staking-address staking)
    (var-set insurance-address insurance)
    (ok true)
  )
)

;; --- Public Interface ---

;; @desc Get the base fee for a module
(define-read-only (get-fee-rate (module (string-ascii 32)))
  (ok (default-to u0 (map-get? module-fees module)))
)

;; @desc Get the effective fee rate for a user (applying tier discounts)
(define-read-only (get-effective-fee-rate
    (user principal)
    (module (string-ascii 32))
  )
  (let (
      (base-rate (default-to u0 (map-get? module-fees module)))
      ;; Call tier-manager for discount. If it fails (e.g. not deployed), default to 0 discount.
      (discount (match (contract-call? .tier-manager get-discount user)
        d
        d
        err-val
        u0
      ))
    )
    (ok (/ (* base-rate (- MAX_BPS discount)) MAX_BPS))
  )
)

;; @desc Calculate and route fees for a specific amount
;; @param token: The token being collected
;; @param amount: The total amount to calculate fee from (or the raw fee amount depending on context)
;; @param is-total: If true, 'amount' is the transaction size and we calculate fee using effective rate. 
;;                  If false, 'amount' is the already-collected fee to be split.
(define-public (route-fees
    (token <sip-010-trait>)
    (amount uint)
    (is-total bool)
    (module (string-ascii 32))
  )
  (let (
      (sender tx-sender)
      (fee-amount (if is-total
        (let ((rate (unwrap-panic (get-effective-fee-rate sender module))))
          (/ (* amount rate) MAX_BPS)
        )
        amount
      ))
    )
    (if (> fee-amount u0)
      (let (
          (treasury-amt (/ (* fee-amount (var-get treasury-share-bps)) MAX_BPS))
          (staking-amt (/ (* fee-amount (var-get staking-share-bps)) MAX_BPS))
          (insurance-amt (/ (* fee-amount (var-get insurance-share-bps)) MAX_BPS))
          ;; Burn is remainder to avoid dust
          (burn-amt (- fee-amount (+ (+ treasury-amt staking-amt) insurance-amt)))
        )
        ;; Emit Reporting Event
        (print {
          event: "fee-routed",
          module: module,
          token: (contract-of token),
          total-fee: fee-amount,
          treasury: treasury-amt,
          staking: staking-amt,
          insurance: insurance-amt,
          burn: burn-amt,
          timestamp: block-height,
        })

        ;; Execute Transfers
        ;; We assume the calling module has already transferred `fee-amount` to
        ;; this contract, so CXD balances are held by this contract. Inside
        ;; as-contract, tx-sender resolves to this contract's principal.
        (as-contract (print {
          event: "debug-contract-tx-sender",
          sender: tx-sender,
        }))

        (if (> treasury-amt u0)
          (try! (as-contract (contract-call? token transfer treasury-amt tx-sender
            (var-get treasury-address) none
          )))
          true
        )
        (if (> staking-amt u0)
          (try! (as-contract (contract-call? token transfer staking-amt tx-sender
            (var-get staking-address) none
          )))
          true
        )
        (if (> insurance-amt u0)
          (try! (as-contract (contract-call? token transfer insurance-amt tx-sender
            (var-get insurance-address) none
          )))
          true
        )
        (if (> burn-amt u0)
          (try! (as-contract (contract-call? token transfer burn-amt tx-sender
            (var-get treasury-address) none
          )))
          true
        )

        (ok fee-amount)
      )
      (ok u0) ;; No fee to route
    )
  )
)
