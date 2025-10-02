;; sbtc-vault.clar
;; Bitcoin asset management vault with sBTC wrapping/unwrapping
;; Provides secure custody, yield generation, and cross-chain bridging for BTC

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait vault-trait .all-traits.vault-trait)
(use-trait vault-admin-trait .all-traits.vault-admin-trait)

(impl-trait .all-traits.vault-trait)
(impl-trait .all-traits.vault-admin-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u2002))
(define-constant ERR_INVALID_AMOUNT (err u2003))
(define-constant ERR_VAULT_PAUSED (err u2004))
(define-constant ERR_WITHDRAWAL_LOCKED (err u2005))
(define-constant ERR_UNWRAP_FAILED (err u2006))
(define-constant ERR_WRAP_FAILED (err u2007))
(define-constant ERR_BRIDGE_ERROR (err u2008))
(define-constant ERR_INVALID_BTC_ADDRESS (err u2009))

(define-constant PRECISION u100000000) ;; 8 decimals for BTC
(define-constant MIN_WRAP_AMOUNT u100000) ;; 0.001 BTC
(define-constant MIN_UNWRAP_AMOUNT u100000) ;; 0.001 BTC
(define-constant WITHDRAWAL_DELAY_BLOCKS u144) ;; ~24 hours

;; Fee configuration (in basis points)
(define-constant DEFAULT_WRAP_FEE_BPS u10) ;; 0.1%
(define-constant DEFAULT_UNWRAP_FEE_BPS u10) ;; 0.1%
(define-constant DEFAULT_PERFORMANCE_FEE_BPS u1000) ;; 10%
(define-constant DEFAULT_MANAGEMENT_FEE_BPS u200) ;; 2% annually

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var vault-paused bool false)
(define-data-var total-sbtc-deposited uint u0)
(define-data-var total-shares-minted uint u0)
(define-data-var total-yield-generated uint u0)

;; Fee settings
(define-data-var wrap-fee-bps uint DEFAULT_WRAP_FEE_BPS)
(define-data-var unwrap-fee-bps uint DEFAULT_UNWRAP_FEE_BPS)
(define-data-var performance-fee-bps uint DEFAULT_PERFORMANCE_FEE_BPS)
(define-data-var management-fee-bps uint DEFAULT_MANAGEMENT_FEE_BPS)

;; Protocol addresses
(define-data-var sbtc-token-contract (optional principal) none)
(define-data-var treasury-address principal tx-sender)
(define-data-var bridge-contract (optional principal) none)

;; ===== User Positions =====
(define-map user-deposits principal {
  sbtc-amount: uint,
  shares: uint,
  deposited-at: uint,
  last-claim: uint,
  total-claimed: uint
})

;; Withdrawal requests (timelock)
(define-map withdrawal-requests principal {
  amount: uint,
  requested-at: uint,
  unlock-at: uint,
  btc-address: (buff 64)
})

;; Share tracking
(define-map share-balances principal uint)

;; Wrapped/unwrapped tracking
(define-map wrap-history {user: principal, timestamp: uint} {
  btc-amount: uint,
  sbtc-amount: uint,
  fee-paid: uint
})

(define-map unwrap-history {user: principal, timestamp: uint} {
  sbtc-amount: uint,
  btc-amount: uint,
  fee-paid: uint,
  btc-address: (buff 64)
})

;; Yield strategy allocations
(define-map strategy-allocations principal {
  allocated-amount: uint,
  current-value: uint,
  apy: uint,
  last-harvest: uint
})

;; ===== Authorization =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (check-not-paused)
  (ok (asserts! (not (var-get vault-paused)) ERR_VAULT_PAUSED)))

;; ===== Admin Functions =====
(define-public (set-vault-paused (paused bool))
  (begin
    (try! (check-is-owner))
    (var-set vault-paused paused)
    (ok true)))

(define-public (set-sbtc-token (token principal))
  (begin
    (try! (check-is-owner))
    (var-set sbtc-token-contract (some token))
    (ok true)))

(define-public (set-bridge-contract (bridge principal))
  (begin
    (try! (check-is-owner))
    (var-set bridge-contract (some bridge))
    (ok true)))

(define-public (set-wrap-fee (fee-bps uint))
  (begin
    (try! (check-is-owner))
    (asserts! (<= fee-bps u1000) ERR_INVALID_AMOUNT) ;; Max 10%
    (var-set wrap-fee-bps fee-bps)
    (ok true)))

(define-public (set-unwrap-fee (fee-bps uint))
  (begin
    (try! (check-is-owner))
    (asserts! (<= fee-bps u1000) ERR_INVALID_AMOUNT)
    (var-set unwrap-fee-bps fee-bps)
    (ok true)))

(define-public (set-performance-fee (fee-bps uint))
  (begin
    (try! (check-is-owner))
    (asserts! (<= fee-bps u5000) ERR_INVALID_AMOUNT) ;; Max 50%
    (var-set performance-fee-bps fee-bps)
    (ok true)))

;; ===== Core Vault Functions (impl-trait vault-trait) =====

;; Deposit sBTC into vault
(define-public (deposit (token-contract (contract-of sip-010-ft-trait)) (amount uint))
  (begin
    (try! (check-not-paused))
    (asserts! (>= amount MIN_WRAP_AMOUNT) ERR_INVALID_AMOUNT)
    
    ;; Transfer sBTC from user
    (try! (contract-call? token-contract transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Calculate shares to mint
    (let ((shares (calculate-shares-to-mint amount)))
      
      ;; Update user position
      (match (map-get? user-deposits tx-sender)
        existing
        (map-set user-deposits tx-sender {
          sbtc-amount: (+ (get sbtc-amount existing) amount),
          shares: (+ (get shares existing) shares),
          deposited-at: (get deposited-at existing),
          last-claim: block-height,
          total-claimed: (get total-claimed existing)
        })
        (map-set user-deposits tx-sender {
          sbtc-amount: amount,
          shares: shares,
          deposited-at: block-height,
          last-claim: block-height,
          total-claimed: u0
        }))
      
      ;; Update share balance
      (map-set share-balances tx-sender 
               (+ (default-to u0 (map-get? share-balances tx-sender)) shares))
      
      ;; Update totals
      (var-set total-sbtc-deposited (+ (var-get total-sbtc-deposited) amount))
      (var-set total-shares-minted (+ (var-get total-shares-minted) shares))
      
      (ok shares))))

;; Request withdrawal (timelock)
(define-public (withdraw (token-contract (contract-of sip-010-ft-trait)) (shares uint))
  (begin
    (try! (check-not-paused))
    
    (let ((user-shares (default-to u0 (map-get? share-balances tx-sender))))
      (asserts! (>= user-shares shares) ERR_INSUFFICIENT_BALANCE)
      
      ;; Calculate sBTC amount
      (let ((sbtc-amount (calculate-sbtc-from-shares shares)))
        (asserts! (>= sbtc-amount MIN_UNWRAP_AMOUNT) ERR_INVALID_AMOUNT)
        
        ;; Create withdrawal request with timelock
        (map-set withdrawal-requests tx-sender {
          amount: sbtc-amount,
          requested-at: block-height,
          unlock-at: (+ block-height WITHDRAWAL_DELAY_BLOCKS),
          btc-address: 0x00 ;; Will be set when claiming
        })
        
        ;; Burn shares
        (map-set share-balances tx-sender (- user-shares shares))
        (var-set total-shares-minted (- (var-get total-shares-minted) shares))
        
        (ok sbtc-amount)))))

;; Complete withdrawal after timelock
(define-public (complete-withdrawal (token-contract (contract-of sip-010-ft-trait)))
  (begin
    (let ((request (unwrap! (map-get? withdrawal-requests tx-sender) ERR_UNAUTHORIZED)))
      
      ;; Check timelock
      (asserts! (>= block-height (get unlock-at request)) ERR_WITHDRAWAL_LOCKED)
      
      ;; Calculate fee
      (let ((fee (/ (* (get amount request) (var-get unwrap-fee-bps)) u10000))
            (amount-after-fee (- (get amount request) fee)))
        
        ;; Transfer sBTC back to user
        (try! (as-contract (contract-call? token-contract transfer 
                                          amount-after-fee 
                                          tx-sender 
                                          tx-sender 
                                          none)))
        
        ;; Remove withdrawal request
        (map-delete withdrawal-requests tx-sender)
        
        ;; Update totals
        (var-set total-sbtc-deposited (- (var-get total-sbtc-deposited) (get amount request)))
        
        (ok amount-after-fee)))))

;; Get total balance of vault
(define-public (get-total-balance (token-contract (contract-of sip-010-ft-trait)))
  (ok (var-get total-sbtc-deposited)))

;; ===== Bitcoin Wrapping/Unwrapping =====

;; Wrap BTC to sBTC (placeholder - requires bridge integration)
(define-public (wrap-btc (btc-amount uint) (btc-txid (buff 32)))
  (begin
    (try! (check-not-paused))
    (asserts! (>= btc-amount MIN_WRAP_AMOUNT) ERR_INVALID_AMOUNT)
    
    ;; Verify BTC deposit via bridge contract
    (match (var-get bridge-contract)
      bridge
      ;; In production: verify BTC transaction and mint sBTC
      (let ((fee (/ (* btc-amount (var-get wrap-fee-bps)) u10000))
            (sbtc-amount (- btc-amount fee)))
        
        ;; Record wrap history
        (map-set wrap-history {user: tx-sender, timestamp: block-height} {
          btc-amount: btc-amount,
          sbtc-amount: sbtc-amount,
          fee-paid: fee
        })
        
        (ok sbtc-amount))
      ERR_BRIDGE_ERROR)))

;; Unwrap sBTC to BTC (placeholder - requires bridge integration)
(define-public (unwrap-to-btc (sbtc-amount uint) (btc-address (buff 64)))
  (begin
    (try! (check-not-paused))
    (asserts! (>= sbtc-amount MIN_UNWRAP_AMOUNT) ERR_INVALID_AMOUNT)
    
    ;; Validate BTC address format (simplified)
    (asserts! (> (len btc-address) u0) ERR_INVALID_BTC_ADDRESS)
    
    ;; Calculate fee
    (let ((fee (/ (* sbtc-amount (var-get unwrap-fee-bps)) u10000))
          (btc-amount (- sbtc-amount fee)))
      
      ;; Record unwrap history
      (map-set unwrap-history {user: tx-sender, timestamp: block-height} {
        sbtc-amount: sbtc-amount,
        btc-amount: btc-amount,
        fee-paid: fee,
        btc-address: btc-address
      })
      
      ;; In production: initiate BTC withdrawal via bridge
      (ok btc-amount))))

;; ===== Yield Generation =====

;; Allocate funds to yield strategy
(define-public (allocate-to-strategy (strategy principal) (amount uint))
  (begin
    (try! (check-is-owner))
    
    (map-set strategy-allocations strategy {
      allocated-amount: amount,
      current-value: amount,
      apy: u0,
      last-harvest: block-height
    })
    
    (ok true)))

;; Harvest yield from strategies
(define-public (harvest-yield (strategy principal))
  (begin
    (try! (check-is-owner))
    
    (match (map-get? strategy-allocations strategy)
      allocation
      (let ((yield-earned (- (get current-value allocation) (get allocated-amount allocation))))
        
        ;; Calculate performance fee
        (let ((performance-fee (/ (* yield-earned (var-get performance-fee-bps)) u10000))
              (net-yield (- yield-earned performance-fee)))
          
          ;; Update total yield
          (var-set total-yield-generated (+ (var-get total-yield-generated) net-yield))
          
          ;; Update allocation
          (map-set strategy-allocations strategy (merge allocation {
            last-harvest: block-height
          }))
          
          (ok net-yield)))
      ERR_UNAUTHORIZED)))

;; ===== Helper Functions =====

(define-private (calculate-shares-to-mint (sbtc-amount uint))
  (let ((total-sbtc (var-get total-sbtc-deposited))
        (total-shares (var-get total-shares-minted)))
    (if (is-eq total-shares u0)
        sbtc-amount ;; First deposit: 1:1 ratio
        (/ (* sbtc-amount total-shares) total-sbtc))))

(define-private (calculate-sbtc-from-shares (shares uint))
  (let ((total-sbtc (var-get total-sbtc-deposited))
        (total-shares (var-get total-shares-minted)))
    (if (is-eq total-shares u0)
        u0
        (/ (* shares total-sbtc) total-shares))))

;; ===== Read-Only Functions =====

(define-read-only (get-user-position (user principal))
  (map-get? user-deposits user))

(define-read-only (get-user-shares (user principal))
  (default-to u0 (map-get? share-balances user)))

(define-read-only (get-withdrawal-request (user principal))
  (map-get? withdrawal-requests user))

(define-read-only (get-vault-stats)
  {
    total-sbtc: (var-get total-sbtc-deposited),
    total-shares: (var-get total-shares-minted),
    total-yield: (var-get total-yield-generated),
    share-price: (if (> (var-get total-shares-minted) u0)
                     (/ (* (var-get total-sbtc-deposited) PRECISION) (var-get total-shares-minted))
                     PRECISION),
    paused: (var-get vault-paused)
  })

(define-read-only (get-fee-config)
  {
    wrap-fee-bps: (var-get wrap-fee-bps),
    unwrap-fee-bps: (var-get unwrap-fee-bps),
    performance-fee-bps: (var-get performance-fee-bps),
    management-fee-bps: (var-get management-fee-bps)
  })

(define-read-only (get-strategy-allocation (strategy principal))
  (map-get? strategy-allocations strategy))

(define-read-only (estimate-shares (sbtc-amount uint))
  (ok (calculate-shares-to-mint sbtc-amount)))

(define-read-only (estimate-withdrawal (shares uint))
  (let ((sbtc-amount (calculate-sbtc-from-shares shares))
        (fee (/ (* sbtc-amount (var-get unwrap-fee-bps)) u10000)))
    {
      gross-amount: sbtc-amount,
      fee: fee,
      net-amount: (- sbtc-amount fee)
    }))

;; ===== Vault Admin Trait Functions =====

(define-public (set-deposit-fee (fee-bps uint))
  (set-wrap-fee fee-bps))

(define-public (set-withdrawal-fee (fee-bps uint))
  (set-unwrap-fee fee-bps))

(define-public (emergency-pause)
  (set-vault-paused true))

(define-public (emergency-unpause)
  (set-vault-paused false))

;; Placeholder implementations for strategy functions
(define-public (deposit-to-strategy (asset (contract-of sip-010-ft-trait)) (amount uint) (strategy principal))
  (allocate-to-strategy strategy amount))

(define-public (withdraw-from-strategy (asset (contract-of sip-010-ft-trait)) (amount uint) (strategy principal))
  (ok true))
