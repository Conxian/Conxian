;; ===========================================
;; CONXIAN PROTOCOL - CENTRALIZED TRAIT DEFINITIONS
;; ===========================================
;;
;; This file serves as the single source of truth for all trait definitions
;; in the Conxian protocol. All contracts should reference traits from this file
;; to ensure consistency and avoid duplication.
;;
;; USAGE:
;; (use-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.<trait-name>)
;;
;; ===========================================
;; CORE TRAITS
;; ===========================================

(define-trait sip-010-ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

(define-trait sip-009-nft-trait
  (
    (transfer (principal principal uint (optional (buff 34))) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    (get-last-token-id () (response uint uint))
    (get-token-by-index (principal uint) (response (optional uint) uint))
  )
)

(define-trait access-control-trait
  (
    (has-role (principal (string-ascii 32)) (response bool uint))
    (grant-role (principal (string-ascii 32)) (response bool uint))
    (revoke-role (principal (string-ascii 32)) (response bool uint))
    (only-role ((string-ascii 32)) (response bool uint))
    (only-roles ((list 10 (string-ascii 32))) (response bool uint))
  )
)

(define-trait pausable-trait
  (
    (pause () (response bool uint))
    (unpause () (response bool uint))
    (paused () (response bool uint))
  )
)

(define-trait ownable-trait
  (
    (get-owner () (response principal uint))
    (transfer-ownership (principal) (response bool uint))
    (renounce-ownership () (response bool uint))
  )
)

(define-trait circuit-breaker-trait
  (
    (check-circuit-state ((string-ascii 32)) (response uint uint))
    (record-success ((string-ascii 32)) (response uint uint))
    (record-failure ((string-ascii 32)) (response uint uint))
  )
)

(define-trait standard-constants-trait
  (
    (get-precision () (response uint uint))
    (get-percent-100 () (response uint uint))
    (get-max-uint64 () (response uint uint))
  )
)

(define-trait vault-trait
  (
    (deposit (uint principal) (response uint uint))
    (withdraw (uint principal) (response uint uint))
    (get-vault-tvl () (response uint uint))
    (get-share-value () (response uint uint))
  )
)

(define-trait vault-admin-trait
  (
    (set-fee-rate (uint) (response bool uint))
    (set-fee-recipient (principal) (response bool uint))
    (set-strategy (principal) (response bool uint))
    (harvest () (response uint uint))
  )
)

(define-trait strategy-trait
  (
    (harvest () (response uint uint))
    (withdraw (uint) (response uint uint))
    (deposit (uint) (response uint uint))
    (balance-of () (response uint uint))
  )
)

(define-trait staking-trait
  (
    (stake (uint) (response uint uint))
    (unstake (uint) (response uint uint))
    (get-staked-balance (principal) (response uint uint))
    (get-total-staked () (response uint uint))
  )
)

(define-trait dao-trait
  (
    (has-voting-power (address principal) (response bool uint))
    (get-voting-power (address principal) (response uint uint))
    (get-total-voting-power () (response uint uint))
    (delegate (delegatee principal) (response bool uint))
    (undelegate () (response bool uint))
    (execute-proposal (proposal-id uint) (response bool uint))
    (vote (proposal-id uint) (support bool) (response bool uint))
    (get-proposal (proposal-id uint)
      (response {
        id: uint,
        proposer: principal,
        start-block: uint,
        end-block: uint,
        for-votes: uint,
        against-votes: uint,
        executed: bool,
        canceled: bool
      } uint)
    )
  )
)

(define-trait liquidation-trait
  (
    (can-liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
    ) (response bool uint)
    (liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
      (max-collateral-amount uint)
    ) (response (tuple (debt-repaid uint) (collateral-seized uint)) uint)
    (liquidate-multiple-positions
      (positions (list 10 (tuple
        (borrower principal)
        (debt-asset principal)
        (collateral-asset principal)
        (debt-amount uint)
      )))
    ) (response (tuple (success-count uint) (total-debt-repaid uint) (total-collateral-seized uint)) uint)
    (calculate-liquidation-amounts
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
    ) (response (tuple
        (max-debt-repayable uint)
        (collateral-to-seize uint)
        (liquidation-incentive uint)
        (debt-value uint)
        (collateral-value uint)
      ) uint)
    (emergency-liquidate
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
    ) (response bool uint)
  )
)

(define-trait monitoring-trait
  (
    (log-event (component (string-ascii 32))
               (event-type (string-ascii 32))
               (severity uint)
               (message (string-ascii 256))
               (data (optional {}))
               (response bool uint))
    (get-events (component (string-ascii 32))
                (limit uint)
                (offset uint)
                (response (list 100 (tuple (id uint)
                                         (event-type (string-ascii 32))
                                         (severity uint)
                                         (message (string-ascii 256))
                                         (block-height uint)
                                         (data (optional {}))))
                         uint))
    (get-event (event-id uint)
               (response (tuple (id uint)
                              (component (string-ascii 32))
                              (event-type (string-ascii 32))
                              (severity uint)
                              (message (string-ascii 256))
                              (block-height uint)
                              (data (optional {})))
                        uint))
    (get-health-status (component (string-ascii 32))
                      (response (tuple (status uint)
                                     (last-updated uint)
                                     (uptime uint)
                                     (error-count uint)
                                     (warning-count uint))
                               uint))
    (set-alert-threshold (component (string-ascii 32))
                         (alert-type (string-ascii 32))
                         (threshold uint)
                         (response bool uint))
    (get-admin () (response principal uint))
    (set-admin (new-admin principal) (response bool uint))
  )
)

(define-trait oracle-trait
  (
    (get-price (principal) (response uint uint))
    (update-price (principal uint) (response bool uint))
    (get-last-updated (principal) (response uint uint))
  )
)

(define-trait dim-registry-trait
  (
    (update-weight (uint uint) (response uint uint))
  )
)

(define-trait dimensional-oracle-trait
  (
    (update-weights ((list 10 {dim-id: uint, new-wt: uint})) (response bool uint))
  )
)

(define-trait audit-registry-trait
  (
    (submit-audit
      (contract-address principal)
      (audit-hash (string-ascii 64))
      (report-uri (string-utf8 256))
      (response uint uint)
    )
    (vote (audit-id uint) (approve bool) (response bool uint))
    (finalize-audit (audit-id uint) (response bool uint))
    (get-audit (audit-id uint)
      (response {
        contract-address: principal,
        audit-hash: (string-ascii 64),
        auditor: principal,
        report-uri: (string-utf8 256),
        timestamp: uint,
        status: {
          status: (string-ascii 20),
          reason: (optional (string-utf8 500))
        },
        votes: {
          for: uint,
          against: uint,
          voters: (list 100 principal)
        },
        voting-ends: uint
      } uint)
    )
    (get-audit-status (audit-id uint)
      (response {
        status: (string-ascii 20),
        reason: (optional (string-utf8 500))
      } uint)
    )
    (get-audit-votes (audit-id uint)
      (response {
        for: uint,
        against: uint,
        voters: (list 100 principal)
      } uint)
    )
    (set-voting-period (blocks uint) (response bool uint))
    (emergency-pause-audit (audit-id uint) (reason (string-utf8 500)) (response bool uint))
  )
)
