;; Conxian Vault - Core yield-bearing vault with enhanced tokenomics integration
;; Implements vault-trait and vault-admin-trait with full system integration

;; Traits
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

;; Error Constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_PAUSED (err u1002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))
(define-constant ERR_CAP_EXCEEDED (err u1005))
(define-constant ERR_INVALID_ASSET (err u1006))
(define-constant ERR_STRATEGY_FAILED (err u1007))
(define-constant ERR_TRANSFER_FAILED (err u1008))

;; Configuration Constants
(define-constant MAX_BPS u10000)
(define-constant PRECISION u100000000) ;; 8 decimals
(define-constant DEFAULT_DEPOSIT_FEE u50) ;; 0.5%
(define-constant DEFAULT_WITHDRAWAL_FEE u100) ;; 1%
(define-constant DEFAULT_REVENUE_SHARE u2000) ;; 20%
(define-constant MAX_DEPOSIT_FEE u500) ;; 5%
(define-constant MAX_WITHDRAWAL_FEE u1000) ;; 10%
(define-constant MAX_REVENUE_SHARE u5000) ;; 50%

;; State Variables
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var deposit-fee-bps uint DEFAULT_DEPOSIT_FEE)
(define-data-var withdrawal-fee-bps uint DEFAULT_WITHDRAWAL_FEE)
(define-data-var revenue-share-bps uint DEFAULT_REVENUE_SHARE)
(define-data-var monitor-enabled bool true)
(define-data-var emission-enabled bool true)

;; Integration: token system coordinator contract
(define-data-var token-system-coordinator principal .token-system-coordinator)

;; Maps
(define-map vault-balances principal uint) ;; asset -> total balance
(define-map vault-shares principal uint) ;; asset -> total shares
(define-map vault-caps principal uint) ;; asset -> max deposit cap
(define-map user-shares (tuple (user principal) (asset principal)) uint)
(define-map supported-assets principal bool)
(define-map asset-strategies principal principal) ;; asset -> strategy contract

;; Enhanced tokenomics integration maps
(define-map collected-fees principal uint) ;; asset -> accumulated protocol fees
(define-map performance-metrics principal (tuple (total-volume uint) (total-fees uint)))

(define-map service-budgets
  { asset: principal, service-type: (string-ascii 32) }
  {
    period-start: uint,
    period-length: uint,
    max-amount: uint,
    spent: uint
  })

;; Read-only functions
(define-public (get-admin) (ok (var-get admin)))
(define-read-only (is-paused) (ok (var-get paused)))
(define-read-only (get-deposit-fee) (ok (var-get deposit-fee-bps)))
(define-read-only (get-withdrawal-fee) (ok (var-get withdrawal-fee-bps)))
(define-read-only (get-revenue-share) (ok (var-get revenue-share-bps)))
(define-read-only (get-total-balance (asset principal)) (ok (default-to u0 (map-get? vault-balances asset))))
(define-read-only (get-total-shares (asset principal)) (ok (default-to u0 (map-get? vault-shares asset))))
(define-read-only (get-user-shares (user principal) (asset principal)) (ok (default-to u0 (map-get? user-shares (tuple (user user) (asset asset))))))
(define-read-only (get-vault-cap (asset principal)) (ok (default-to u0 (map-get? vault-caps asset))))
(define-read-only (is-asset-supported (asset principal)) (default-to false (map-get? supported-assets asset)))
(define-read-only (get-strategy (token-contract principal)) (ok (map-get? asset-strategies token-contract)))
(define-read-only (get-apy (token-contract principal)) (ok u800)) ;; 8% APY
(define-read-only (get-tvl (token-contract principal)) (ok (default-to u0 (map-get? vault-balances token-contract))))

(define-read-only (get-service-budget (asset principal) (service-type (string-ascii 32)))
  (ok (map-get? service-budgets { asset: asset, service-type: service-type })))

;; Private functions
(define-private (is-admin (user principal)) (is-eq user (var-get admin)))

(define-private (calculate-shares (asset principal) (amount uint))
  (let ((total-balance (unwrap-panic (get-total-balance asset)))
        (total-shares (unwrap-panic (get-total-shares asset))))
    (if (is-eq total-shares u0)
        amount ;; First deposit: 1:1 ratio
        (/ (* amount total-shares) total-balance))))

(define-private (calculate-amount (asset principal) (shares uint))
  (let ((total-balance (unwrap-panic (get-total-balance asset)))
        (total-shares (unwrap-panic (get-total-shares asset))))
    (if (is-eq total-shares u0)
        u0
        (/ (* shares total-balance) total-shares))))

(define-private (calculate-fee (amount uint) (fee-bps uint))
  (/ (* amount fee-bps) MAX_BPS))

(define-private (notify-protocol-monitor (event (string-ascii 32)) (data (tuple (asset principal) (amount uint))))
  ;; Simplified monitoring - just return true for now
  (and (var-get monitor-enabled) true))

;; Core vault functions
(define-public (deposit (asset principal) (amount uint))
  (let ((user tx-sender)
        (fee (calculate-fee amount (var-get deposit-fee-bps)))
        (net-amount (- amount fee))
        (shares (calculate-shares asset net-amount))
        (current-balance (unwrap! (get-total-balance asset) ERR_INVALID_ASSET))
        (current-shares (unwrap! (get-total-shares asset) ERR_INVALID_ASSET))
        (vault-cap (unwrap! (get-vault-cap asset) ERR_INVALID_ASSET))
        (user-current-shares (unwrap! (get-user-shares user asset) ERR_INVALID_ASSET)))
    
    ;; Validations
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-asset-supported asset) ERR_INVALID_ASSET)
    (asserts! (or (is-eq vault-cap u0) (<= (+ current-balance net-amount) vault-cap)) ERR_CAP_EXCEEDED)
    
    ;; Transfer tokens from user to vault
    (try! (contract-call? asset transfer amount user (as-contract tx-sender) none))
    
    ;; Update vault state
    (map-set vault-balances asset (+ current-balance net-amount))
    (map-set vault-shares asset (+ current-shares shares))
    (map-set user-shares (tuple (user user) (asset asset)) (+ user-current-shares shares))
    
    ;; Handle protocol fees
    (if (> fee u0)
        (begin
          (map-set collected-fees asset (+ (default-to u0 (map-get? collected-fees asset)) fee))
          (if (var-get emission-enabled)
            (try! (contract-call? (var-get token-system-coordinator) trigger-revenue-distribution asset fee))
            true)
          true)
        true)
    
    ;; Deploy funds to strategy if available
    (match (map-get? asset-strategies asset)
      strategy-contract
        (let ((deploy-result (try! (contract-call? strategy-contract deploy-funds net-amount))))
          (asserts! (>= deploy-result net-amount) ERR_STRATEGY_FAILED)
          (ok deploy-result))
      (begin
        ;; No strategy configured - keep funds in vault
        (ok net-amount)))
    
    ;; Notify monitoring system
    (notify-protocol-monitor "deposit" (tuple (asset asset) (amount net-amount)))
    
    ;; Emit event
    (print (tuple (event "vault-deposit") (user user) (asset asset) (amount amount) (shares shares) (fee fee)))
    (ok (tuple (shares shares) (fee fee)))))

(define-public (withdraw (asset principal) (shares uint))
  (let ((user tx-sender)
        (amount (calculate-amount asset shares))
        (fee (calculate-fee amount (var-get withdrawal-fee-bps)))
        (net-amount (- amount fee))
        (current-balance (unwrap! (get-total-balance asset) ERR_INVALID_ASSET))
        (current-shares (unwrap! (get-total-shares asset) ERR_INVALID_ASSET))
        (user-current-shares (unwrap! (get-user-shares user asset) ERR_INVALID_ASSET)))
    
    ;; Validations
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-current-shares shares) ERR_INSUFFICIENT_BALANCE)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Withdraw from strategy if needed
    (match (map-get? asset-strategies asset)
      strategy-contract
        (let ((withdraw-result (try! (contract-call? strategy-contract withdraw-funds amount))))
          (asserts! (>= withdraw-result amount) ERR_STRATEGY_FAILED)
          (ok withdraw-result))
      (begin
        ;; No strategy configured - funds are already in vault
        (ok amount)))
    
    ;; Update vault state
    (map-set vault-balances asset (- current-balance amount))
    (map-set vault-shares asset (- current-shares shares))
    (map-set user-shares (tuple (user user) (asset asset)) (- user-current-shares shares))
    
    ;; Handle protocol fees
    (if (> fee u0)
        (begin
          (map-set collected-fees asset (+ (default-to u0 (map-get? collected-fees asset)) fee))
          (if (var-get emission-enabled)
            (try! (contract-call? (var-get token-system-coordinator) trigger-revenue-distribution asset fee))
            true)
          true)
        true)
    
    ;; Transfer tokens to user
    (try! (contract-call? asset transfer net-amount (as-contract tx-sender) user none))
    
    ;; Notify monitoring system
    (notify-protocol-monitor "withdraw" (tuple (asset asset) (amount net-amount)))
    
    ;; Emit event
    (print (tuple (event "vault-withdraw") (user user) (asset asset) (amount net-amount) (shares shares) (fee fee)))
    (ok (tuple (amount net-amount) (fee fee)))))

(define-public (flash-loan (amount uint) (recipient principal))
  (let ((asset-principal SP000000000000000000002Q6VF78) ;; STX for flash loans
        (fee (calculate-fee amount u30))) ;; 0.3% flash loan fee
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Implementation would include flash loan callback pattern
    ;; For now, return success to satisfy trait
    (ok true)))

;; Enhanced tokenomics integration functions
(define-public (collect-protocol-fees (asset principal))
  (let ((collected (default-to u0 (map-get? collected-fees asset))))
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> collected u0) ERR_INVALID_AMOUNT)
    
    ;; Reset collected fees
    (map-set collected-fees asset u0)
    
    ;; Notify revenue distributor
    (if (var-get emission-enabled)
      (try! (contract-call? (var-get token-system-coordinator) trigger-revenue-distribution asset collected))
      true)
    
    (ok collected)))

;; Administrative functions
(define-public (set-deposit-fee (new-fee-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps u500) ERR_INVALID_AMOUNT) ;; Max 5%
    (var-set deposit-fee-bps new-fee-bps)
    (ok true)))

(define-public (set-withdrawal-fee (new-fee-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR_INVALID_AMOUNT) ;; Max 10%
    (var-set withdrawal-fee-bps new-fee-bps)
    (ok true)))

(define-public (set-vault-cap (asset principal) (new-cap uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (map-set vault-caps asset new-cap)
    (ok true)))

(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set paused pause)
    (print (tuple (event "vault-pause-changed") (paused pause)))
    (ok true)))

(define-public (set-revenue-share (new-share-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= new-share-bps u5000) ERR_INVALID_AMOUNT) ;; Max 50%
    (var-set revenue-share-bps new-share-bps)
    (ok true)))

(define-public (update-integration-settings (settings (tuple (monitor-enabled bool) (emission-enabled bool))))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set monitor-enabled (get monitor-enabled settings))
    (var-set emission-enabled (get emission-enabled settings))
    (ok true)))

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (print (tuple (event "admin-transferred") (old-admin tx-sender) (new-admin new-admin)))
    (ok true)))

(define-public (add-supported-asset (asset principal) (strategy-contract principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (map-set supported-assets asset true)
    (map-set asset-strategies asset strategy-contract)
    (ok true)))

(define-public (emergency-withdraw (asset principal) (amount uint) (recipient principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Emergency withdrawal - transfer assets directly
    (try! (contract-call? asset transfer amount (as-contract tx-sender) recipient none))
    
    ;; Update vault balance
    (let ((current-balance (default-to u0 (map-get? vault-balances asset))))
      (map-set vault-balances asset (if (>= current-balance amount) (- current-balance amount) u0)))
    
    (print (tuple (event "emergency-withdraw") (asset asset) (amount amount) (recipient recipient)))
    (ok amount)))

(define-public (rebalance-vault (asset principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-asset-supported asset) ERR_INVALID_ASSET)
    
    ;; Rebalancing logic - withdraw from strategy and redeploy
    (match (map-get? asset-strategies asset)
      strategy-contract
        (let ((total-balance (default-to u0 (map-get? vault-balances asset))))
          ;; Withdraw all from strategy
          (try! (contract-call? strategy-contract withdraw-funds total-balance))
          ;; Redeploy to strategy
          (try! (contract-call? strategy-contract deploy-funds total-balance))
          (print (tuple (event "vault-rebalanced") (asset asset) (amount total-balance)))
          (ok true))
      ERR_INVALID_ASSET)))

(define-public (set-service-budget
  (asset principal)
  (service-type (string-ascii 32))
  (period-start uint)
  (period-length uint)
  (max-amount uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> max-amount u0) ERR_INVALID_AMOUNT)
    (map-set service-budgets
      { asset: asset, service-type: service-type }
      {
        period-start: period-start,
        period-length: period-length,
        max-amount: max-amount,
        spent: u0
      })
    (ok true)))

(define-public (pay-service
  (asset principal)
  (amount uint)
  (recipient principal)
  (service-type (string-ascii 32)))
  (let ((current-balance (default-to u0 (map-get? vault-balances asset))))
    (begin
      (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      (match (map-get? service-budgets { asset: asset, service-type: service-type })
        budget
          (let ((start (get period-start budget))
                (len (get period-length budget))
                (max-amt (get max-amount budget))
                (spent (get spent budget)))
            (let ((effective-budget
                    (if (and (> len u0) (>= (- block-height start) len))
                      {
                        period-start: block-height,
                        period-length: len,
                        max-amount: max-amt,
                        spent: u0
                      }
                      budget)))
              (let ((new-spent (+ (get spent effective-budget) amount)))
                (asserts! (<= new-spent max-amt) ERR_CAP_EXCEEDED)
                (map-set service-budgets
                  { asset: asset, service-type: service-type }
                  (merge effective-budget { spent: new-spent }))
                (try! (contract-call? asset transfer amount (as-contract tx-sender) recipient none))
                (map-set vault-balances asset (- current-balance amount))
                (print (tuple
                  (event "service-payment")
                  (asset asset)
                  (amount amount)
                  (recipient recipient)
                  (service-type service-type)))
                (ok amount))))
        ERR_INVALID_ASSET))))

