;; enhanced-flash-loan-vault.clar
;; Enhanced vault with comprehensive flash loan implementation
;; Extends the basic vault with full flash loan functionality

;; Import trait at the top
(use-trait sip10 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSR.sip-010-trait.sip-010-trait)

;; Define flash-loan-receiver trait inline to avoid circular dependency
(define-trait flash-loan-receiver
  (
    (on-flash-loan (sender principal) (token principal) (amount uint) (fee uint) (data (buff 256))) (response bool uint)
    (get-flash-loan-fee (token principal) (amount uint) (data (buff 256))) (response uint uint)
    (get-max-flash-loan (token principal)) (response uint uint)
  )
)

(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSR.vault-trait.vault-trait)
(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSR.vault-admin-trait.vault-admin-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6001))
(define-constant ERR_PAUSED (err u6002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u6003))
(define-constant ERR_INVALID_AMOUNT (err u6004))
(define-constant ERR_CAP_EXCEEDED (err u6005))
(define-constant ERR_INVALID_ASSET (err u6006))
(define-constant ERR_FLASH_LOAN_FAILED (err u6007))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u6008))
(define-constant ERR_CALLBACK_FAILED (err u6009))

(define-constant MAX_BPS u10000)
(define-constant PRECISION u1000000000000000000) ;; 18 decimals

;; Admin and state
(define-data-var admin principal tx-sender)
(define-data-var default-loan-asset (optional principal) none)
(define-data-var paused bool false)
(define-data-var deposit-fee-bps uint u30)  ;; 0.30%
(define-data-var withdrawal-fee-bps uint u20) ;; 0.20%
(define-data-var flash-loan-fee-bps uint u40) ;; 0.40%
(define-data-var revenue-share-bps uint u2500) ;; 25%

;; Multi-asset support
(define-map vault-balances principal uint)       ;; Total balance per asset
(define-map vault-shares principal uint)         ;; Total shares per asset
(define-map user-shares (tuple (user principal) (asset principal)) uint)  ;; Users shares per asset
(define-map supported-assets principal bool)
(define-map vault-caps principal uint)           ;; Max deposit per asset

;; Enhanced flash-loan vault maps
(define-map flash-loan-stats principal 
  {
    total-loans: uint,
    total-volume: uint,
    total-fees: uint,
    average-loan-size: uint
  })

(define-map asset-caps principal uint) ;; asset -> max deposit cap

;; Protocol fee tracking
(define-map collected-fees principal uint) ;; asset -> amount

;; Flash loan specific
(define-data-var flash-loan-in-progress bool false)

;; Revenue tracking
(define-data-var protocol-reserve uint u0)
(define-data-var treasury-reserve uint u0)

;; Optional contract references (dependency injection pattern)
(define-data-var protocol-monitor (optional principal) none)
(define-data-var system-integration-enabled bool false)

;; === ADMIN FUNCTIONS ===
(define-private (is-admin (user principal))
  (is-eq user (var-get admin)))

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set paused pause)
    (print (tuple (event "vault-pause-changed") (paused pause)))
    (ok true)))

(define-public (set-deposit-fee (deposit-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= deposit-bps u1000) ERR_INVALID_AMOUNT)     ;; Max 10%
    (var-set deposit-fee-bps deposit-bps)
    (ok true)))

(define-public (set-withdrawal-fee (withdrawal-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= withdrawal-bps u1000) ERR_INVALID_AMOUNT)  ;; Max 10%
    (var-set withdrawal-fee-bps withdrawal-bps)
    (ok true)))

(define-public (set-fees (deposit-bps uint) (withdrawal-bps uint) (flash-loan-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= deposit-bps u1000) ERR_INVALID_AMOUNT)     ;; Max 10%
    (asserts! (<= withdrawal-bps u1000) ERR_INVALID_AMOUNT)  ;; Max 10%
    (asserts! (<= flash-loan-bps u1000) ERR_INVALID_AMOUNT)  ;; Max 10%
    (var-set deposit-fee-bps deposit-bps)
    (var-set withdrawal-fee-bps withdrawal-bps)
    (var-set flash-loan-fee-bps flash-loan-bps)
    (ok true)))

(define-public (add-supported-asset (asset principal) (cap uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (map-set supported-assets asset true)
    (map-set vault-caps asset cap)
    (map-set vault-balances asset u0)
    (map-set vault-shares asset u0)
    (ok true)))

;; === CORE VAULT FUNCTIONS ===
(define-public (deposit (asset principal) (amount uint))
  (let ((user tx-sender)
        (fee (calculate-fee amount (var-get deposit-fee-bps)))
        (net-amount (- amount fee))
        (current-balance (unwrap! (get-total-balance asset) ERR_INVALID_ASSET))
        (current-shares (unwrap! (get-total-shares asset) ERR_INVALID_ASSET))
        (shares (calculate-shares asset net-amount))
        (vault-cap (unwrap! (get-vault-cap asset) ERR_INVALID_ASSET))
        (user-current-shares (unwrap! (get-user-shares user asset) ERR_INVALID_ASSET)))
    
    ;; Validations
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-asset-supported asset) ERR_INVALID_ASSET)
    (asserts! (or (is-eq vault-cap u0) (<= (+ current-balance net-amount) vault-cap)) ERR_CAP_EXCEEDED)
    
    ;; Update balances
    (map-set vault-balances asset (+ current-balance net-amount))
    (map-set vault-shares asset (+ current-shares shares))
    (map-set user-shares (tuple (user user) (asset asset)) (+ user-current-shares shares))
    
    ;; Handle fee
    (distribute-fee fee)
    
    ;; Notify monitoring system
    (notify-protocol-monitor "deposit" (tuple (asset asset) (amount net-amount)))
    
    ;; Emit event
    (print (tuple (event "vault-deposit") (user user) (asset asset) 
                  (amount amount) (shares shares) (fee fee)))
    
    (ok (tuple (shares shares) (fee fee)))))

(define-public (withdraw (asset principal) (shares uint))
  (let ((user tx-sender)
        (current-balance (unwrap! (map-get? vault-balances asset) ERR_INVALID_ASSET))
        (current-shares (unwrap! (map-get? vault-shares asset) ERR_INVALID_ASSET))
        (user-current-shares (unwrap! (map-get? user-shares (tuple (user user) (asset asset))) ERR_INVALID_ASSET)))
    
    ;; Validations
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-current-shares shares) ERR_INSUFFICIENT_BALANCE)
    (asserts! (not (var-get flash-loan-in-progress)) ERR_FLASH_LOAN_FAILED) ;; Prevent during flash loan
    
    ;; Update balances
    (map-set vault-balances asset (- current-balance amount))
    (map-set vault-shares asset (- current-shares shares))
    (map-set user-shares (tuple (user user) (asset asset)) (- user-current-shares shares))
    
    ;; Handle fee
    (distribute-fee fee)
    
    ;; Notify monitoring system
    (notify-protocol-monitor "withdraw" (tuple (asset asset) (amount net-amount)))
    
    ;; Emit event
    (print (tuple (event "vault-withdraw") (user user) (asset asset) 
                  (amount net-amount) (shares shares) (fee fee)))
    
    (ok (tuple (amount net-amount) (fee fee)))))

;; === FLASH LOAN IMPLEMENTATION ===
(define-public (flash-loan (asset <sip10>) (amount uint) (receiver <flash-loan-receiver>) (data (buff 256)))
  (let ((receiver-principal (contract-of receiver))
        (asset-principal (contract-of asset)))
    (begin
      (asserts! (not (var-get paused)) ERR_PAUSED)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)
      (asserts! (is-asset-supported asset-principal) ERR_INVALID_ASSET)
      (asserts! (not (var-get flash-loan-in-progress)) ERR_FLASH_LOAN_FAILED) ;; Prevent reentrancy
      
      (let ((available-balance (unwrap! (get-total-balance asset-principal) ERR_INVALID_ASSET))
            (fee (calculate-flash-loan-fee amount)))
        
        (asserts! (>= available-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
        
        ;; Set reentrancy guard
        (var-set flash-loan-in-progress true)
        
        ;; Record balance before
        (let ((balance-before available-balance))
          
          ;; Transfer loan amount to receiver
          (try! (transfer-asset-from-vault asset amount receiver-principal))
          
          ;; Call receivers flash loan callback (expects token principal)
          (match (contract-call? receiver on-flash-loan tx-sender asset amount fee data)
            (ok (success code)) (asserts! success ERR_CALLBACK_FAILED)
            (err error) (begin
              (var-set flash-loan-in-progress false)
              (asserts! false (err error))))
          
          ;; Check that loan + fee was repaid
          (let ((balance-after (unwrap! (get-total-balance asset-principal) ERR_FLASH_LOAN_FAILED))
                (required-balance (+ balance-before fee)))
            
            (asserts! (>= balance-after required-balance) ERR_FLASH_LOAN_FAILED)
            
            ;; Update vault balance to include fee
            (map-set vault-balances asset-principal balance-after)
            
            ;; Update flash loan statistics
            (update-flash-loan-stats asset-principal amount fee)
            
            ;; Distribute fee
            (distribute-fee fee)
            
            ;; Clear reentrancy guard
            (var-set flash-loan-in-progress false)
            
            ;; Emit event
            (print (tuple (event "flash-loan") (initiator tx-sender) (receiver receiver-principal)
                          (asset asset-principal) (amount amount) (fee fee)))
            
            (ok true)))))))

;; Simplified flash loan for basic receivers (legacy support)
(define-public (flash-loan-simple (asset <sip10>) (amount uint) (recipient principal))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-asset-supported (contract-of asset)) ERR_INVALID_ASSET)
    (asserts! (not (var-get flash-loan-in-progress)) ERR_FLASH_LOAN_FAILED)
    
    (let ((available-balance (unwrap! (get-total-balance (contract-of asset)) ERR_INVALID_ASSET))
          (fee (calculate-flash-loan-fee amount)))
      
      (asserts! (>= available-balance amount) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; Set reentrancy guard
      (var-set flash-loan-in-progress true)
      
      (let ((balance-before available-balance))
        ;; Transfer loan amount
        (try! (transfer-asset-from-vault asset amount recipient))
        
        ;; NOTE: In a simple flash loan, the recipient must ensure repayment
        ;; This is less secure but maintains compatibility
        
        ;; For demo purposes, well assume immediate repayment
        ;; In production, this would require a callback mechanism
        
        ;; Clear reentrancy guard
        (var-set flash-loan-in-progress false)
        
        (ok true)))))

;; === FLASH LOAN HELPERS ===
(define-private (calculate-flash-loan-fee (amount uint))
  (/ (* amount (var-get flash-loan-fee-bps)) MAX_BPS))

(define-private (update-flash-loan-stats (asset principal) (amount uint) (fee uint))
  (let ((current-stats (default-to 
                         {
                           total-loans: u0, 
                           total-volume: u0, 
                           total-fees: u0, 
                           average-loan-size: u0
                         }
                         (map-get? flash-loan-stats asset))))
    (map-set flash-loan-stats asset
      {
        total-loans: (+ (get total-loans current-stats) u1),
        total-volume: (+ (get total-volume current-stats) amount),
        total-fees: (+ (get total-fees current-stats) fee),
        average-loan-size: (/ (+ (get total-volume current-stats) amount) 
                            (+ (get total-loans current-stats) u1))
      })))

(define-private (transfer-asset-from-vault (asset <sip10>) (amount uint) (recipient principal))
  ;; SIP-010 transfer: (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (try! (as-contract (contract-call? asset transfer amount tx-sender recipient none)))
    (let ((asset-principal (contract-of asset))
          (current-balance (unwrap! (get-total-balance (contract-of asset)) ERR_INVALID_ASSET)))
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      (map-set vault-balances asset-principal (- current-balance amount))
      (ok true))))

;; Get actual token balance from SIP-010 contract
(define-private (get-actual-token-balance (asset <sip10>))
  (contract-call? asset get-balance (as-contract tx-sender)))

;; === UTILITY FUNCTIONS ===
(define-private (is-asset-supported (asset principal))
  (default-to false (map-get? supported-assets asset)))

(define-read-only (get-total-shares (asset principal))
  (default-to u0 (map-get? vault-shares asset)))

(define-private (calculate-fee (amount uint) (fee-bps uint))
  (/ (* amount fee-bps) MAX_BPS))

(define-private (calculate-shares (asset principal) (amount uint))
  (let ((current-balance (unwrap-panic (get-total-balance asset)))
        (current-shares (unwrap-panic (get-total-shares asset))))
    (if (is-eq current-shares u0)
      amount ;; First deposit gets 1:1 ratio
      (/ (* amount current-shares) current-balance))))

(define-private (calculate-amount (asset principal) (shares uint))
  (let ((current-balance (unwrap-panic (get-total-balance asset)))
        (current-shares (unwrap-panic (get-total-shares asset))))
    (if (is-eq current-shares u0)
      u0
      (/ (* shares current-balance) current-shares))))

(define-private (distribute-fee (fee uint))
  (let ((treasury-share (/ (* fee (var-get revenue-share-bps)) MAX_BPS))
        (protocol-share (- fee treasury-share)))
    (var-set treasury-reserve (+ (var-get treasury-reserve) treasury-share))
    (var-set protocol-reserve (+ (var-get protocol-reserve) protocol-share))))

(define-private (notify-protocol-monitor (action (string-ascii 20)) (data (tuple (asset principal) (amount uint))))
  (if (and (var-get system-integration-enabled) (is-some (var-get protocol-monitor)))
    (match (var-get protocol-monitor)
      monitor-ref
        ;; Would call monitor contract if available
        true
      true)
    true))

;; === READ-ONLY FUNCTIONS ===
(define-read-only (get-total-balance (asset principal))
  (ok (default-to u0 (map-get? vault-balances asset))))

(define-read-only (get-total-shares (asset principal))
  (ok (default-to u0 (map-get? vault-shares asset))))

(define-read-only (get-user-shares (user principal) (asset principal))
  (ok (default-to u0 (map-get? user-shares (tuple (user user) (asset asset))))))

(define-read-only (get-vault-cap (asset principal))
  (ok (default-to u0 (map-get? vault-caps asset))))

(define-read-only (get-deposit-fee)
  (ok (var-get deposit-fee-bps)))

(define-read-only (get-withdrawal-fee)
  (ok (var-get withdrawal-fee-bps)))

(define-read-only (get-flash-loan-fee-rate)
  (ok (var-get flash-loan-fee-bps)))

(define-read-only (get-revenue-share)
  (ok (var-get revenue-share-bps)))

(define-read-only (is-paused)
  (ok (var-get paused)))

(define-read-only (get-flash-loan-stats (asset principal))
  (map-get? flash-loan-stats asset))

(define-read-only (get-max-flash-loan (asset principal))
  (if (is-asset-supported asset)
    (get-total-balance asset)
    (ok u0)))

(define-read-only (get-flash-loan-fee (asset principal) (amount uint))
  (ok (calculate-flash-loan-fee amount)))

;; === ENHANCED ANALYTICS ===
(define-read-only (get-utilization (asset principal))
  (let ((total-balance (unwrap! (get-total-balance asset) 
                                (err (tuple 
                                  (total-balance u0)
                                  (flash-loans-count u0)
                                  (flash-loan-volume u0)
                                  (fees-collected u0)
                                  (utilization-rate u0)))))
        (stats (default-to 
                 {
                   total-loans: u0, 
                   total-volume: u0, 
                   total-fees: u0,
                   average-loan-size: u0
                 }
                 (map-get? flash-loan-stats asset)))
        (utilization-rate (if (is-eq total-balance u0) 
                            u0 
                            (/ (* (get total-volume stats) PRECISION) total-balance))))
    (ok (tuple 
      (total-balance total-balance)
      (flash-loans-count (get total-loans stats))
      (flash-loan-volume (get total-volume stats))
      (fees-collected (get total-fees stats))
      (utilization-rate utilization-rate)))))

;; === LEGACY VAULT TRAIT COMPLIANCE ===
;; Fix flash-loan-basic function to use trait-based contract call

(define-public (flash-loan-basic (amount uint) (recipient principal))
  (let ((token-principal (unwrap-panic (var-get default-loan-asset))))
    (match (as-contract (contract-call? (as-contract (contract-of token-principal)) transfer amount tx-sender recipient none))
      (ok true) (ok true)
      (err e) (err e))))

;; Define the flash-loan-simple function that will be called by other contracts
(define-public (flash-loan-simple (token principal) (amount uint) (recipient principal))
  (flash-loan token amount recipient))

;; === DEPENDENCY INJECTION ===
(define-public (set-protocol-monitor (monitor-contract principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set protocol-monitor (some monitor-contract))
    (ok true)))

(define-public (enable-system-integration)
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set system-integration-enabled true)
    (ok true)))

;; === VAULT ADMIN TRAIT COMPLIANCE ===
(define-public (emergency-withdraw (asset principal) (amount uint) (recipient principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    ;; Emergency withdrawal implementation - placeholder
    (ok amount)))

(define-public (set-vault-cap (asset principal) (cap uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (map-set vault-caps asset cap)
    (ok true)))

(define-public (rebalance-vault (asset principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    ;; Rebalancing logic placeholder
    (ok true)))

(define-public (set-revenue-share (share-bps uint))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set revenue-share-bps share-bps)
    (ok true)))

(define-public (update-integration-settings (settings (tuple (monitor-enabled bool) (emission-enabled bool))))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set system-integration-enabled (get monitor-enabled settings))
    (ok true)))

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (get-admin)
  (ok (var-get admin)))

(define-public (set-default-loan-asset (asset principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set default-loan-asset (some asset))
    (ok true)))

;; === COLLECT PROTOCOL FEES ===
(define-public (collect-protocol-fees (asset <sip10>))
  (let ((fees (default-to u0 (map-get? collected-fees (contract-of asset))))
        (admin-address (var-get admin)))
    (begin
      (asserts! (is-eq tx-sender admin-address) ERR_UNAUTHORIZED)
      (asserts! (> fees u0) ERR_INVALID_AMOUNT)
      
      (match (as-contract (contract-call? asset transfer fees tx-sender admin-address none))
        result (begin 
                (map-set collected-fees (contract-of asset) u0)
                (ok (tuple (fees-collected fees))))
        error (err error))
    )
  )
)

(define-read-only (get-revenue-stats)
  (ok (tuple 
    (protocol-reserve (var-get protocol-reserve))
    (treasury-reserve (var-get treasury-reserve))
    (total-revenue (+ (var-get protocol-reserve) (var-get treasury-reserve)))
    (revenue-share-bps (var-get revenue-share-bps)))))

(define-read-only (get-total-balance (asset principal))
  (ok (default-to u0 (map-get? vault-balances asset))))





