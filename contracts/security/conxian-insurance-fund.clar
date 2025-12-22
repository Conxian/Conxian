;; conxian-insurance-fund.clar
;; Conxian Safety Module (CSM)
;;
;; @desc A Safety Module acting as the protocol's insurance layer.
;; Users stake CXD tokens to underwrite protocol risk.
;; In exchange, they receive a portion of protocol fees (routed here via protocol-fee-switch).
;; In a shortfall event, funds can be slashed by governance to cover deficits.

(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

;; --- Constants ---

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_NOT_GOVERNANCE (err u5001))
(define-constant ERR_INSUFFICIENT_STAKE (err u5002))
(define-constant ERR_COOLDOWN_ACTIVE (err u5003))
(define-constant ERR_NO_COOLDOWN (err u5004))
(define-constant ERR_SLIPPAGE (err u5005))

(define-constant COOLDOWN_BLOCKS u20736000) ;; ~10 days (assuming 10 min blocks)

;; --- Data Variables ---
(define-data-var governance-contract principal tx-sender)
(define-data-var staking-token principal tx-sender) ;; The token being staked (CONX)

;; --- Maps ---
(define-map user-stakes
  { user: principal }
  {
    amount: uint,
    cooldown-start: uint,
  }
)

(define-data-var total-staked uint u0)

;; --- Admin Functions ---

(define-public (set-governance (new-gov principal))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) ERR_UNAUTHORIZED)
    (var-set governance-contract new-gov)
    (ok true)
  )
)

(define-public (set-staking-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) ERR_UNAUTHORIZED)
    (var-set staking-token token)
    (ok true)
  )
)

;; --- Core Insurance Functions ---

;; @desc Stake tokens into the Safety Module
(define-public (stake
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (let (
      (sender tx-sender)
      (token-principal (contract-of token))
    )
    (asserts! (is-eq token-principal (var-get staking-token)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_SLIPPAGE)

    ;; Transfer tokens to this contract
    (try! (contract-call? token transfer amount sender (as-contract tx-sender) none))

    ;; Update State
    (let ((current-stake (default-to {
        amount: u0,
        cooldown-start: u0,
      }
        (map-get? user-stakes { user: sender })
      )))
      (map-set user-stakes { user: sender } {
        amount: (+ (get amount current-stake) amount),
        cooldown-start: u0, ;; Reset cooldown on new stake
      })
    )
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)
  )
)

;; @desc Initiate cooldown period for unstaking
(define-public (initiate-cooldown)
  (let (
      (sender tx-sender)
      (current-stake (unwrap! (map-get? user-stakes { user: sender }) ERR_INSUFFICIENT_STAKE))
    )
    (asserts! (> (get amount current-stake) u0) ERR_INSUFFICIENT_STAKE)
    (map-set user-stakes { user: sender }
      (merge current-stake { cooldown-start: block-height })
    )
    (ok block-height)
  )
)

;; @desc Unstake tokens after cooldown
(define-public (unstake
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (let (
      (sender tx-sender)
      (token-principal (contract-of token))
      (current-stake (unwrap! (map-get? user-stakes { user: sender }) ERR_INSUFFICIENT_STAKE))
    )
    (asserts! (is-eq token-principal (var-get staking-token)) ERR_UNAUTHORIZED)
    (asserts! (>= (get amount current-stake) amount) ERR_INSUFFICIENT_STAKE)

    ;; Check Cooldown
    (asserts! (> (get cooldown-start current-stake) u0) ERR_NO_COOLDOWN)
    (asserts!
      (>= block-height (+ (get cooldown-start current-stake) COOLDOWN_BLOCKS))
      ERR_COOLDOWN_ACTIVE
    )

    ;; Transfer
    (try! (as-contract (contract-call? token transfer amount tx-sender sender none)))

    ;; Update State
    (map-set user-stakes { user: sender } {
      amount: (- (get amount current-stake) amount),
      cooldown-start: u0, ;; Reset cooldown
    })
    (var-set total-staked (- (var-get total-staked) amount))
    (ok true)
  )
)

;; @desc SLASHING: Governance can seize funds to cover a deficit
;; @param amount: Amount of staking tokens to slash
;; @param recipient: Address receiving the slashed funds (e.g., Recovery Multisig)
(define-public (slash-funds
    (amount uint)
    (token <sip-010-ft-trait>)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) ERR_NOT_GOVERNANCE)
    (asserts! (is-eq (contract-of token) (var-get staking-token))
      ERR_UNAUTHORIZED
    )

    ;; Transfer slashed funds to recipient
    (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))

    ;; Note: We do not reduce 'user-stakes' mapping here because that would require iterating all users.
    ;; Instead, the system is now "insolvent" vs the internal ledger.
    ;; A real implementation would use a 'share-price' exchange rate that drops when funds are slashed.
    ;; For V1, slashing assumes the Safety Module is effectively "burned" or users accept the loss (socialized loss logic needed in V2).
    ;; We update total-staked to reflect reality, but user balances remain high (insolvency).
    ;; In a full production version, we would use an index (like the lending protocol) to propagate the loss.

    (var-set total-staked (- (var-get total-staked) amount))
    (ok true)
  )
)

;; --- Rewards Handling ---
;; This contract can receive ANY token from the fee switch.
;; Governance can skim these tokens to distribute to stakers or buyback CONX.

(define-public (governance-withdraw
    (amount uint)
    (token <sip-010-ft-trait>)
    (recipient principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) ERR_NOT_GOVERNANCE)
    ;; Prevent withdrawing the Staked Token unless it's a slash (use slash-funds for that)
    (asserts! (not (is-eq (contract-of token) (var-get staking-token)))
      ERR_UNAUTHORIZED
    )

    (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
    (ok true)
  )
)

;; --- Vault Trait Implementation (Stubbed for compatibility) ---
(define-public (deposit
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (stake amount token)
)

(define-public (withdraw
    (amount uint)
    (token <sip-010-ft-trait>)
  )
  (unstake amount token)
)

(define-read-only (get-total-assets)
  (ok (var-get total-staked))
)

;; Get user's stake information
(define-read-only (get-user-stake (user principal))
  (map-get? user-stakes { user: user })
)
