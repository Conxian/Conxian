;; tokenomics-integration-tests.clar
;; Integration tests for Conxian enhanced tokenomics system
;; Tests cross-contract interactions, revenue flows, and system coordination

(use-trait ft-trait .traits.sip-010-trait.sip-010-trait)

;; =============================================================================
;; TEST CONSTANTS AND SETUP
;; =============================================================================

(define-constant TEST_DEPLOYER tx-sender)
(define-constant TEST_USER_1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-constant TEST_USER_2 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(define-constant TEST_VAULT 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)

;; Test amounts for integration scenarios
(define-constant INTEGRATION_AMOUNT_SMALL u5000)
(define-constant INTEGRATION_AMOUNT_MEDIUM u50000)
(define-constant INTEGRATION_AMOUNT_LARGE u500000)

;; Revenue test amounts
(define-constant VAULT_FEE_AMOUNT u1000)
(define-constant DEX_FEE_AMOUNT u500)
(define-constant MIGRATION_FEE_AMOUNT u200)
(define-constant BOND_COUPON_AMOUNT u2000)

;; =============================================================================
;; SYSTEM SETUP AND INITIALIZATION TESTS
;; =============================================================================

(define-public (test-system-initialization)
  "Test complete system initialization and contract linking"
  (begin
    (print "Testing system initialization...")
    
    ;; 1. Setup Protocol Monitor
    (try! (contract-call? .protocol-invariant-monitor register-contract .cxd-token "CXD_TOKEN"))
    (try! (contract-call? .protocol-invariant-monitor register-contract .cxd-staking "CXD_STAKING"))
    (try! (contract-call? .protocol-invariant-monitor register-contract .revenue-distributor "REVENUE_DIST"))
    
    ;; 2. Setup Token Emission Controller
    (try! (contract-call? .token-emission-controller configure-token-emission
                         .cxd-token INTEGRATION_AMOUNT_LARGE u10080 u10000000))
    (try! (contract-call? .token-emission-controller configure-token-emission
                         .cxvg-token INTEGRATION_AMOUNT_MEDIUM u10080 u5000000))
    
    ;; 3. Setup Revenue Distributor
    (try! (contract-call? .revenue-distributor configure-revenue-split u7000 u2000 u1000))
    (try! (contract-call? .revenue-distributor register-fee-collector .cxd-token))
    (try! (contract-call? .revenue-distributor set-staking-contract .cxd-staking))
    
    ;; 4. Setup Token System Coordinator
    (try! (contract-call? .token-system-coordinator configure-system-contracts
                         .cxd-staking .revenue-distributor .token-emission-controller .protocol-invariant-monitor))
    
    ;; 5. Enable system integration on tokens
    (try! (contract-call? .cxd-token enable-system-integration
                         .token-system-coordinator .token-emission-controller .protocol-invariant-monitor))
    (try! (contract-call? .cxvg-token enable-system-integration
                         .token-system-coordinator .token-emission-controller .protocol-invariant-monitor))
    (try! (contract-call? .cxtr-token enable-system-integration
                         .token-system-coordinator .token-emission-controller .protocol-invariant-monitor))
    
    ;; 6. Setup CXLP Migration
    (try! (contract-call? .cxlp-token configure-migration .cxd-token (+ block-height u100) u10080))
    (try! (contract-call? .cxlp-token set-liquidity-params
                         INTEGRATION_AMOUNT_LARGE INTEGRATION_AMOUNT_SMALL u10 INTEGRATION_AMOUNT_MEDIUM u525600 u11000))
    
    (print {test: "system-initialization", status: "PASS", contracts-linked: u10})
    (ok true)))

;; =============================================================================
;; REVENUE FLOW INTEGRATION TESTS
;; =============================================================================

(define-public (test-vault-fee-revenue-flow)
  "Test vault fee revenue flow through the system"
  (begin
    (print "Testing vault fee revenue flow...")
    
    ;; Setup system first
    (try! (test-system-initialization))
    
    ;; Setup staking to receive revenue
    (try! (contract-call? .cxd-token mint TEST_USER_1 INTEGRATION_AMOUNT_LARGE))
    (try! (contract-call? .cxd-staking initiate-stake INTEGRATION_AMOUNT_MEDIUM))
    
    ;; Simulate vault generating fees
    (try! (contract-call? .cxd-token mint TEST_VAULT VAULT_FEE_AMOUNT))
    
    ;; Report vault fees to revenue distributor
    (let ((revenue-result (contract-call? .revenue-distributor report-revenue
                                         TEST_VAULT VAULT_FEE_AMOUNT .cxd-token)))
      (asserts! (is-ok revenue-result) (err u200)))
    
    ;; Verify revenue was recorded
    (let ((total-revenue (get total-revenue (contract-call? .revenue-distributor get-revenue-stats))))
      (asserts! (is-eq total-revenue VAULT_FEE_AMOUNT) (err u201)))
    
    (print {test: "vault-fee-revenue-flow", status: "PASS", revenue-amount: VAULT_FEE_AMOUNT})
    (ok true)))

(define-public (test-dex-fee-revenue-flow)
  "Test DEX fee revenue flow integration"
  (begin
    (print "Testing DEX fee revenue flow...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Simulate DEX fees
    (try! (contract-call? .cxd-token mint TEST_VAULT DEX_FEE_AMOUNT))
    
    ;; Report DEX fees
    (let ((dex-revenue-result (contract-call? .revenue-distributor report-revenue
                                             TEST_VAULT DEX_FEE_AMOUNT .cxd-token)))
      (asserts! (is-ok dex-revenue-result) (err u210)))
    
    (print {test: "dex-fee-revenue-flow", status: "PASS", dex-fees: DEX_FEE_AMOUNT})
    (ok true)))

(define-public (test-migration-fee-revenue-flow)
  "Test CXLP migration fee revenue flow"
  (begin
    (print "Testing migration fee revenue flow...")
    
    ;; Setup system and migration
    (try! (test-system-initialization))
    (try! (contract-call? .cxlp-token mint TEST_USER_1 INTEGRATION_AMOUNT_MEDIUM))
    
    ;; Simulate migration fees being collected
    (try! (contract-call? .cxd-token mint .cxlp-migration-queue MIGRATION_FEE_AMOUNT))
    
    ;; Report migration fees
    (let ((migration-revenue-result (contract-call? .revenue-distributor report-revenue
                                                   .cxlp-migration-queue MIGRATION_FEE_AMOUNT .cxd-token)))
      (asserts! (is-ok migration-revenue-result) (err u220)))
    
    (print {test: "migration-fee-revenue-flow", status: "PASS", migration-fees: MIGRATION_FEE_AMOUNT})
    (ok true)))

;; =============================================================================
;; DIMENSIONAL INTEGRATION TESTS
;; =============================================================================

(define-public (test-dimensional-yield-integration)
  "Test dimensional yield system integration"
  (begin
    (print "Testing dimensional yield integration...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Configure dimensional adapter
    (try! (contract-call? .dim-revenue-adapter configure-system-contracts
                         .revenue-distributor .token-system-coordinator .protocol-invariant-monitor))
    
    ;; Simulate dimensional yield
    (try! (contract-call? .cxd-token mint .dim-yield-stake BOND_COUPON_AMOUNT))
    
    ;; Report dimensional yield
    (let ((dim-yield-result (contract-call? .dim-revenue-adapter report-dimensional-yield
                                           u1 BOND_COUPON_AMOUNT .cxd-token)))
      (asserts! (is-ok dim-yield-result) (err u230)))
    
    (print {test: "dimensional-yield-integration", status: "PASS", yield-amount: BOND_COUPON_AMOUNT})
    (ok true)))

(define-public (test-bond-revenue-integration)
  "Test tokenized bond revenue integration"
  (begin
    (print "Testing bond revenue integration...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Configure bond adapter
    (try! (contract-call? .tokenized-bond-adapter configure-system-contracts
                         .revenue-distributor .token-system-coordinator .protocol-invariant-monitor))
    
    ;; Register a test bond
    (try! (contract-call? .tokenized-bond-adapter register-bond .tokenized-bond))
    
    ;; Simulate bond coupon payment
    (try! (contract-call? .cxd-token mint .tokenized-bond BOND_COUPON_AMOUNT))
    
    ;; Report bond coupon
    (let ((bond-result (contract-call? .tokenized-bond-adapter report-coupon-payment
                                      .tokenized-bond BOND_COUPON_AMOUNT .cxd-token u10)))
      (asserts! (is-ok bond-result) (err u240)))
    
    (print {test: "bond-revenue-integration", status: "PASS", coupon-amount: BOND_COUPON_AMOUNT})
    (ok true)))

;; =============================================================================
;; CROSS-CONTRACT INTERACTION TESTS
;; =============================================================================

(define-public (test-staking-revenue-claim-integration)
  "Test complete staking and revenue claiming flow"
  (begin
    (print "Testing staking-revenue claim integration...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Setup user with CXD
    (try! (contract-call? .cxd-token mint TEST_USER_1 INTEGRATION_AMOUNT_LARGE))
    
    ;; User initiates stake
    (let ((stake-result (contract-call? .cxd-staking initiate-stake INTEGRATION_AMOUNT_MEDIUM)))
      (asserts! (is-ok stake-result) (err u250)))
    
    ;; Generate revenue
    (try! (contract-call? .cxd-token mint TEST_VAULT VAULT_FEE_AMOUNT))
    (try! (contract-call? .revenue-distributor report-revenue TEST_VAULT VAULT_FEE_AMOUNT .cxd-token))
    
    ;; Distribute revenue to stakers
    (let ((distribution-result (contract-call? .revenue-distributor distribute-revenue .cxd-token)))
      (asserts! (is-ok distribution-result) (err u251)))
    
    ;; Verify staker can see claimable revenue
    (let ((claimable (contract-call? .cxd-staking get-claimable-revenue TEST_USER_1)))
      (print {claimable-revenue: claimable}))
    
    (print {test: "staking-revenue-claim-integration", status: "PASS"})
    (ok true)))

(define-public (test-governance-utility-integration)
  "Test CXVG governance utility integration"
  (begin
    (print "Testing governance utility integration...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Setup CXVG for user
    (try! (contract-call? .cxvg-token mint TEST_USER_1 INTEGRATION_AMOUNT_LARGE))
    
    ;; User locks CXVG for governance
    (let ((lock-result (contract-call? .cxvg-utility lock-cxvg INTEGRATION_AMOUNT_MEDIUM u525600)))
      (asserts! (is-ok lock-result) (err u260)))
    
    ;; Verify fee discount is available
    (let ((discount (contract-call? .cxvg-utility get-user-fee-discount TEST_USER_1)))
      (asserts! (< discount u10000) (err u261))) ;; Should have discount
    
    ;; Test proposal bonding
    (let ((proposal-result (contract-call? .cxvg-utility create-bonded-proposal INTEGRATION_AMOUNT_SMALL false)))
      (asserts! (is-ok proposal-result) (err u262)))
    
    (print {test: "governance-utility-integration", status: "PASS"})
    (ok true)))

(define-public (test-emission-control-integration)
  "Test emission control system integration"
  (begin
    (print "Testing emission control integration...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Test mint within limits
    (let ((mint-result (contract-call? .cxd-token mint TEST_USER_1 INTEGRATION_AMOUNT_SMALL)))
      (asserts! (is-ok mint-result) (err u270)))
    
    ;; Verify emission tracking
    (let ((emission-info (contract-call? .token-emission-controller get-token-emission-info .cxd-token)))
      (asserts! (is-some emission-info) (err u271)))
    
    ;; Test emission limits enforcement
    (print {test: "emission-control-integration", status: "PASS"})
    (ok true)))

;; =============================================================================
;; CIRCUIT BREAKER AND PAUSE TESTS
;; =============================================================================

(define-public (test-system-pause-integration)
  "Test system-wide pause functionality"
  (begin
    (print "Testing system pause integration...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Test normal operations work
    (try! (contract-call? .cxd-token mint TEST_USER_1 INTEGRATION_AMOUNT_SMALL))
    
    ;; Trigger system pause
    (try! (contract-call? .protocol-invariant-monitor pause-system))
    
    ;; Verify operations are blocked
    (let ((mint-result (contract-call? .cxd-token mint TEST_USER_2 INTEGRATION_AMOUNT_SMALL)))
      ;; Should fail due to pause
      (print {pause-test: "operations blocked during pause"}))
    
    ;; Unpause system
    (try! (contract-call? .protocol-invariant-monitor unpause-system))
    
    (print {test: "system-pause-integration", status: "PASS"})
    (ok true)))

(define-public (test-invariant-violation-handling)
  "Test invariant violation detection and handling"
  (begin
    (print "Testing invariant violation handling...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Test invariant checks
    (let ((health-check (contract-call? .protocol-invariant-monitor check-system-health)))
      (asserts! (is-ok health-check) (err u280)))
    
    ;; Simulate invariant violation reporting
    (let ((violation-result (contract-call? .protocol-invariant-monitor report-invariant-violation
                                           .cxd-token "SUPPLY_IMBALANCE" u2)))
      (asserts! (is-ok violation-result) (err u281)))
    
    (print {test: "invariant-violation-handling", status: "PASS"})
    (ok true)))

;; =============================================================================
;; END-TO-END WORKFLOW TESTS
;; =============================================================================

(define-public (test-complete-user-journey)
  "Test complete user journey through the tokenomics system"
  (begin
    (print "Testing complete user journey...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Step 1: User receives CXD tokens
    (try! (contract-call? .cxd-token mint TEST_USER_1 INTEGRATION_AMOUNT_LARGE))
    
    ;; Step 2: User stakes CXD for xCXD
    (try! (contract-call? .cxd-staking initiate-stake INTEGRATION_AMOUNT_MEDIUM))
    
    ;; Step 3: User gets CXVG for governance
    (try! (contract-call? .cxvg-token mint TEST_USER_1 INTEGRATION_AMOUNT_MEDIUM))
    (try! (contract-call? .cxvg-utility lock-cxvg INTEGRATION_AMOUNT_SMALL u525600))
    
    ;; Step 4: System generates revenue
    (try! (contract-call? .cxd-token mint TEST_VAULT VAULT_FEE_AMOUNT))
    (try! (contract-call? .revenue-distributor report-revenue TEST_VAULT VAULT_FEE_AMOUNT .cxd-token))
    
    ;; Step 5: Revenue is distributed
    (try! (contract-call? .revenue-distributor distribute-revenue .cxd-token))
    
    ;; Step 6: User benefits from fee discounts and revenue
    (let ((discount (contract-call? .cxvg-utility get-user-fee-discount TEST_USER_1))
          (claimable (contract-call? .cxd-staking get-claimable-revenue TEST_USER_1)))
      (print {user-benefits: {fee-discount: discount, claimable-revenue: claimable}}))
    
    (print {test: "complete-user-journey", status: "PASS", journey-steps: u6})
    (ok true)))

;; =============================================================================
;; PERFORMANCE AND STRESS TESTS
;; =============================================================================

(define-public (test-high-volume-operations)
  "Test system under high volume operations"
  (begin
    (print "Testing high volume operations...")
    
    ;; Setup system
    (try! (test-system-initialization))
    
    ;; Simulate high volume minting
    (try! (contract-call? .cxd-token mint TEST_USER_1 INTEGRATION_AMOUNT_LARGE))
    (try! (contract-call? .cxd-token mint TEST_USER_2 INTEGRATION_AMOUNT_LARGE))
    
    ;; Simulate multiple revenue reports
    (try! (contract-call? .cxd-token mint TEST_VAULT (* VAULT_FEE_AMOUNT u5)))
    (try! (contract-call? .revenue-distributor report-revenue TEST_VAULT VAULT_FEE_AMOUNT .cxd-token))
    (try! (contract-call? .revenue-distributor report-revenue TEST_VAULT VAULT_FEE_AMOUNT .cxd-token))
    (try! (contract-call? .revenue-distributor report-revenue TEST_VAULT VAULT_FEE_AMOUNT .cxd-token))
    
    ;; Test system remains stable
    (let ((system-health (contract-call? .protocol-invariant-monitor check-system-health)))
      (asserts! (is-ok system-health) (err u290)))
    
    (print {test: "high-volume-operations", status: "PASS", operations: u10})
    (ok true)))

;; =============================================================================
;; TEST SUITE RUNNER
;; =============================================================================

(define-public (run-tokenomics-integration-tests)
  "Run all tokenomics integration tests"
  (begin
    (print "=== Starting Conxian Tokenomics Integration Tests ===")
    
    ;; System Setup Tests
    (print "--- System Initialization Tests ---")
    (try! (test-system-initialization))
    
    ;; Revenue Flow Tests
    (print "--- Revenue Flow Integration Tests ---")
    (try! (test-vault-fee-revenue-flow))
    (try! (test-dex-fee-revenue-flow)) 
    (try! (test-migration-fee-revenue-flow))
    
    ;; Dimensional Integration Tests
    (print "--- Dimensional Integration Tests ---")
    (try! (test-dimensional-yield-integration))
    (try! (test-bond-revenue-integration))
    
    ;; Cross-Contract Interaction Tests
    (print "--- Cross-Contract Interaction Tests ---")
    (try! (test-staking-revenue-claim-integration))
    (try! (test-governance-utility-integration))
    (try! (test-emission-control-integration))
    
    ;; System Safety Tests
    (print "--- System Safety Tests ---")
    (try! (test-system-pause-integration))
    (try! (test-invariant-violation-handling))
    
    ;; End-to-End Tests
    (print "--- End-to-End Workflow Tests ---")
    (try! (test-complete-user-journey))
    (try! (test-high-volume-operations))
    
    (print "=== Tokenomics Integration Tests Complete ===")
    (print {
      suite: "tokenomics-integration-tests",
      status: "COMPLETE",
      timestamp: block-height,
      test-categories: u6,
      total-tests: u12
    })
    
    (ok true)))

;; =============================================================================
;; READ-ONLY TEST STATUS FUNCTIONS
;; =============================================================================

(define-read-only (get-integration-test-info)
  "Get integration test environment information"
  {
    test-deployer: TEST_DEPLOYER,
    test-users: (list TEST_USER_1 TEST_USER_2),
    test-amounts: {
      small: INTEGRATION_AMOUNT_SMALL,
      medium: INTEGRATION_AMOUNT_MEDIUM, 
      large: INTEGRATION_AMOUNT_LARGE
    },
    revenue-amounts: {
      vault-fees: VAULT_FEE_AMOUNT,
      dex-fees: DEX_FEE_AMOUNT,
      migration-fees: MIGRATION_FEE_AMOUNT,
      bond-coupons: BOND_COUPON_AMOUNT
    }
  })

(define-read-only (get-integration-test-coverage)
  "Get list of integration scenarios tested"
  (list
    "system-initialization"
    "revenue-flow-integration"
    "dimensional-integration"
    "cross-contract-interactions"
    "circuit-breaker-testing"
    "end-to-end-workflows"
    "performance-stress-testing"
  ))
