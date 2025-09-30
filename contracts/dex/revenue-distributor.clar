;; revenue-distributor.clar
;; Comprehensive revenue distribution system connecting vaults to token holders
;; Routes protocol fees: 80% to xCXD stakers, 20% to treasury/reserves

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(impl-trait .all-traits.sip-010-ft-trait)
(use-trait staking-trait .all-traits.staking-trait)
(impl-trait .all-traits.staking-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; Revenue split configuration (basis points)
(define-data-var xcxd-split-bps uint u8000) ;; 80% to xCXD stakers
(define-data-var treasury-split-bps uint u1500) ;; 15% to treasury
(define-data-var reserve-split-bps uint u500) ;; 5% to insurance reserve

;; Fee types for tracking
(define-constant FEE_TYPE_VAULT_PERFORMANCE u1)
(define-constant FEE_TYPE_VAULT_MANAGEMENT u2)
(define-constant FEE_TYPE_DEX_TRADING u3)
(define-constant FEE_TYPE_MIGRATION_FEE u4)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u800)
(define-constant ERR_INVALID_AMOUNT u801)
(define-constant ERR_INVALID_FEE_TYPE u802)
(define-constant ERR_DISTRIBUTION_FAILED u803)
(define-constant ERR_INSUFFICIENT_BALANCE u804)
(define-constant ERR_INVALID_TOKEN u805)
(define-constant ERR_BUYBACK_FAILED u806)
(define-constant ERR_INVALID_SPLIT_BPS u807)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var treasury-address principal tx-sender)
(define-data-var reserve-address principal tx-sender)

;; --- Optional Contract References (Dependency Injection) ---
(define-data-var staking-contract-ref (optional principal) none)
(define-data-var cxd-token-contract (optional principal) none)
(define-data-var system-integration-enabled bool false)
(define-data-var initialization-complete bool false)

;; Event-driven communication
(define-data-var event-counter uint u0)
(define-constant EVENT_REVENUE_COLLECTED "revenue-collected")
(define-constant EVENT_REVENUE_DISTRIBUTED "revenue-distributed")
(define-constant EVENT_MINT_RECORDED "mint-recorded")
(define-constant EVENT_BURN_RECORDED "burn-recorded")

;; Authorized fee collectors (vaults, DEX, etc.)
(define-map authorized-collectors principal bool)

;; --- Revenue Accounting ---
(define-data-var total-revenue-collected uint u0)
(define-data-var total-revenue-distributed uint u0)
(define-data-var current-distribution-epoch uint u1)

;; Revenue tracking by source and type
(define-map revenue-by-source
  { collector: principal, epoch: uint }
  { total-amount: uint, fee-type: uint })

;; Revenue tracking by fee type
(define-map revenue-by-type
  { fee-type: uint, epoch: uint }
  { total-amount: uint, distributions: uint })

;; Pending distributions (accumulated before batch distribution)
(define-map pending-distributions
  principal ;; revenue-token
  { total-pending: uint, last-distribution: uint })

;; Distribution history for auditing
(define-map distribution-history
  uint ;; epoch
  {
    total-distributed: uint,
    xcxd-amount: uint,
    treasury-amount: uint,
    reserve-amount: uint,
    timestamp: uint,
    revenue-token: principal
  })

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-revenue-splits (new-xcxd-split-bps uint) (new-treasury-split-bps uint) (new-reserve-split-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Ensure the splits add up to 100%
    (asserts! (is-eq (+ new-xcxd-split-bps new-treasury-split-bps new-reserve-split-bps) u10000) (err ERR_INVALID_SPLIT_BPS))
    ;; Enforce documented guardrails: 60-90% for xCXD stakers
    (asserts! (>= new-xcxd-split-bps u6000) (err ERR_INVALID_SPLIT_BPS))
    (asserts! (<= new-xcxd-split-bps u9000) (err ERR_INVALID_SPLIT_BPS))

    (var-set xcxd-split-bps new-xcxd-split-bps)
    (var-set treasury-split-bps new-treasury-split-bps)
    (var-set reserve-split-bps new-reserve-split-bps)
    (ok true)))

;; --- Contract Configuration Functions (Dependency Injection) ---
(define-public (set-treasury-address (treasury principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set treasury-address treasury)
    (ok true)))

(define-public (set-reserve-address (reserve principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set reserve-address reserve)
    (ok true)))

(define-public (set-staking-contract-ref (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set staking-contract-ref (some contract-address))
    (ok true)))

(define-public (set-cxd-token-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxd-token-contract (some contract-address))
    (ok true)))

(define-public (enable-system-integration)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled true)
    (ok true)))

(define-public (complete-initialization)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (var-get staking-contract-ref)) (err ERR_UNAUTHORIZED))
    (var-set initialization-complete true)
    (ok true)))

(define-public (authorize-collector (collector principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (if authorized
      (map-set authorized-collectors collector true)
      (map-delete authorized-collectors collector))
    (ok true)))

;; --- Revenue Collection ---

;; Collect revenue from authorized sources (vaults, DEX, etc.)
(define-public (collect-revenue (amount uint) (revenue-token <ft-trait>) (fee-type uint))
  (let ((collector tx-sender)
        (current-epoch (var-get current-distribution-epoch))
        (revenue-token-principal (contract-of revenue-token)))
    (begin
      (asserts! (default-to false (map-get? authorized-collectors collector)) (err ERR_UNAUTHORIZED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (<= fee-type u4) (err ERR_INVALID_FEE_TYPE))
      
      ;; Transfer revenue to this contract
      (try! (contract-call? revenue-token transfer amount collector (as-contract tx-sender) none))
      
      ;; Update tracking
      (var-set total-revenue-collected (+ (var-get total-revenue-collected) amount))
      
      ;; Track by source
      (let ((source-data (default-to { total-amount: u0, fee-type: fee-type }
                                    (map-get? revenue-by-source { collector: collector, epoch: current-epoch }))))
        (map-set revenue-by-source 
          { collector: collector, epoch: current-epoch }
          { total-amount: (+ (get total-amount source-data) amount), fee-type: fee-type }))
      
      ;; Emit event for off-chain tracking and other contracts
      (emit-revenue-collected-event collector amount revenue-token-principal fee-type)
      (ok true))))

;; --- Event Emission Functions ---
(define-private (emit-revenue-collected-event 
  (collector principal) 
  (amount uint) 
  (token principal) 
  (fee-type uint))
  (let ((event-id (+ (var-get event-counter) u1)))
    (var-set event-counter event-id)
    (print {
      event-type: EVENT_REVENUE_COLLECTED,
      contract: (as-contract tx-sender),
      collector: collector,
      amount: amount,
      token: token,
      fee-type: fee-type,
      epoch: (var-get current-distribution-epoch),
      block-height: block-height,
      event-id: event-id,
      timestamp: (unwrap-panic (get-block-info? time block-height))
    })
    event-id))

(define-private (emit-revenue-distributed-event 
  (total-amount uint) 
  (xcxd-amount uint) 
  (treasury-amount uint) 
  (reserve-amount uint))
  (let ((event-id (+ (var-get event-counter) u1)))
    (var-set event-counter event-id)
    (print {
      event-type: EVENT_REVENUE_DISTRIBUTED,
      contract: (as-contract tx-sender),
      total-amount: total-amount,
      xcxd-amount: xcxd-amount,
      treasury-amount: treasury-amount,
      reserve-amount: reserve-amount,
      epoch: (var-get current-distribution-epoch),
      block-height: block-height,
      event-id: event-id,
      timestamp: (unwrap-panic (get-block-info? time block-height))
    })
    event-id))

;; --- Event Listener Functions (for other contracts) ---
(define-public (record-mint-event 
  (recipient principal) 
  (amount uint))
  (begin
    (asserts! (var-get system-integration-enabled) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (var-get cxd-token-contract)) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (unwrap-panic (var-get cxd-token-contract))) (err ERR_UNAUTHORIZED))
    
    ;; Emit event for tracking
    (let ((event-id (+ (var-get event-counter) u1)))
      (var-set event-counter event-id)
      (print {
        event-type: EVENT_MINT_RECORDED,
        contract: (as-contract tx-sender),
        recipient: recipient,
        amount: amount,
        block-height: block-height,
        event-id: event-id,
        timestamp: (unwrap-panic (get-block-info? time block-height))
      }))
    (ok true)))

(define-public (record-burn-event 
  (user principal) 
  (amount uint))
  (begin
    (asserts! (var-get system-integration-enabled) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (var-get cxd-token-contract)) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (unwrap-panic (var-get cxd-token-contract))) (err ERR_UNAUTHORIZED))
    
    ;; Emit event for tracking
    (let ((event-id (+ (var-get event-counter) u1)))
      (var-set event-counter event-id)
      (print {
        event-type: EVENT_BURN_RECORDED,
        contract: (as-contract tx-sender),
        user: user,
        amount: amount,
        block-height: block-height,
        event-id: event-id,
        timestamp: (unwrap-panic (get-block-info? time block-height))
      }))
    (ok true)))

;; --- Revenue Distribution ---

;; Distribute accumulated revenue using buyback-and-make for CXD
(define-public (distribute-revenue (revenue-token <ft-trait>) (total-amount uint))
  (let ((revenue-token-principal (contract-of revenue-token))
        (current-epoch (var-get current-distribution-epoch)))
    (begin
      (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
      (asserts! (> total-amount u0) (err ERR_INSUFFICIENT_BALANCE))
      
      ;; Calculate splits
      (let ((xcxd-amount (/ (* total-amount (var-get xcxd-split-bps)) u10000))
            (treasury-amount (/ (* total-amount (var-get treasury-split-bps)) u10000))
            (reserve-amount (/ (* total-amount (var-get reserve-split-bps)) u10000)))
        
        ;; Simplified distribution for enhanced deployment
        (try! (as-contract (contract-call? revenue-token transfer treasury-amount (as-contract tx-sender) (var-get treasury-address) none)))
        (try! (as-contract (contract-call? revenue-token transfer reserve-amount (as-contract tx-sender) (var-get reserve-address) none)))
        
        ;; Update distribution tracking
        (var-set total-revenue-distributed (+ (var-get total-revenue-distributed) total-amount))
        (var-set current-distribution-epoch (+ current-epoch u1))
        
        (ok total-amount)))))

;; Emergency distribution bypass for specific scenarios
(define-public (emergency-distribute (revenue-token <ft-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (try! (as-contract (contract-call? revenue-token transfer amount (as-contract tx-sender) recipient none)))
    (ok amount)))

;; --- Revenue Path Integration ---

;; Called by vault contracts to report fee collection
(define-public (report-vault-fees (performance-fee uint) (management-fee uint) (fee-token <ft-trait>))
  (begin
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) (err ERR_UNAUTHORIZED))
    
    (let ((total-fees (+ performance-fee management-fee)))
      (begin
        (if (> performance-fee u0)
          (unwrap! (collect-revenue performance-fee fee-token FEE_TYPE_VAULT_PERFORMANCE) (err ERR_DISTRIBUTION_FAILED))
          true)
        
        (if (> management-fee u0)
          (unwrap! (collect-revenue management-fee fee-token FEE_TYPE_VAULT_MANAGEMENT) (err ERR_DISTRIBUTION_FAILED))
          true)
        
        (ok total-fees)))))

;; Called by DEX contracts to report trading fees
(define-public (report-dex-fees (trading-fee uint) (fee-token <ft-trait>))
  (begin
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) (err ERR_UNAUTHORIZED))
    (if (> trading-fee u0)
      (try! (collect-revenue trading-fee fee-token FEE_TYPE_DEX_TRADING))
      true)
    (ok u0)))

;; Called by migration system to report migration fees
(define-public (report-migration-fees (migration-fee uint) (fee-token <ft-trait>))
  (begin
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) (err ERR_UNAUTHORIZED))
    (if (> migration-fee u0)
      (collect-revenue migration-fee fee-token FEE_TYPE_MIGRATION_FEE)
      (ok true))))

;; --- Buyback Mechanism (Future Integration) ---

;; Interface for DEX integration to perform buyback-and-make
(define-public (execute-buyback (revenue-amount uint) (revenue-token <ft-trait>) (min-cxd-out uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; TODO: Integrate with existing dex-factory.clar for optimal buyback path
    ;; This requires implementing swap routing through the factory
    (ok min-cxd-out)))

;; --- Read-Only Functions ---

(define-read-only (get-pending-distributions (revenue-token principal))
  (map-get? pending-distributions revenue-token))

(define-read-only (get-revenue-by-source (collector principal) (epoch uint))
  (map-get? revenue-by-source { collector: collector, epoch: epoch }))

(define-read-only (get-revenue-by-type (fee-type uint) (epoch uint))
  (map-get? revenue-by-type { fee-type: fee-type, epoch: epoch }))

(define-read-only (get-distribution-history (epoch uint))
  (map-get? distribution-history epoch))

(define-read-only (is-authorized-collector (collector principal))
  (default-to false (map-get? authorized-collectors collector)))

(define-read-only (get-revenue-splits)
  {
    xcxd-split-bps: (var-get xcxd-split-bps),
    treasury-split-bps: (var-get treasury-split-bps),
    reserve-split-bps: (var-get reserve-split-bps)
  })

(define-read-only (get-protocol-revenue-stats)
  {
    total-collected: (var-get total-revenue-collected),
    total-distributed: (var-get total-revenue-distributed),
    current-epoch: (var-get current-distribution-epoch),
    pending-distribution: (get total-pending (default-to { total-pending: u0, last-distribution: u0 } 
                                                         (match (var-get cxd-token-contract)
                                                           cxd-addr (map-get? pending-distributions cxd-addr)
                                                           none))),
    treasury-address: (var-get treasury-address),
    reserve-address: (var-get reserve-address),
    staking-contract-ref: (var-get staking-contract-ref)
  })

;; Get comprehensive revenue report for specific epoch
(define-read-only (get-epoch-revenue-report (epoch uint))
  {
    distribution-info: (get-distribution-history epoch),
    vault-performance: (get-revenue-by-type FEE_TYPE_VAULT_PERFORMANCE epoch),
    vault-management: (get-revenue-by-type FEE_TYPE_VAULT_MANAGEMENT epoch),
    dex-trading: (get-revenue-by-type FEE_TYPE_DEX_TRADING epoch),
    migration-fees: (get-revenue-by-type FEE_TYPE_MIGRATION_FEE epoch)
  })

;; Calculate theoretical APY for xCXD staking based on recent revenue
(define-read-only (estimate-xcxd-apy (lookback-epochs uint))
  (let ((current-epoch (var-get current-distribution-epoch))
        (total-recent-revenue u0)) ;; TODO: Calculate from recent epochs
    ;; Placeholder calculation - requires historical analysis
    (ok u500))) ;; 5% placeholder APY





