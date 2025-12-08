;; DeFi Traits
;; Defines standard interfaces for tokens, pools, vaults, and oracles.
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; ===========================================
;; FEE MANAGER TRAIT
;; ===========================================
(define-trait fee-manager-trait (
  (get-fee-rate ((string-ascii 32)) (response uint uint))
  (get-effective-fee-rate (principal (string-ascii 32)) (response uint uint))
  (route-fees (<sip-010-ft-trait> uint bool (string-ascii 32)) (response uint uint))
))

;; ===========================================
;; HOOK TRAIT
;; ===========================================
(define-trait hook-trait (
  (on-action ((string-ascii 32) principal uint principal (optional uint)) (response bool uint))
))

;; ===========================================
;; POOL DEPLOYER TRAIT
;; ===========================================
(define-trait pool-deployer-trait (
  (deploy-and-initialize
    (principal principal)
    (response principal uint)
  )
))

;; ===========================================
;; POOL FACTORY TRAIT
;; ===========================================
(define-trait pool-factory-trait (
  (create-pool
    (<sip-010-ft-trait> <sip-010-ft-trait> (optional (string-ascii 64)) uint (optional {
      tick-spacing: uint,
      initial-price: uint,
    }))
    (response principal uint)
  )
))

;; ===========================================
;; FACTORY TRAIT
;; ===========================================
(define-trait factory-trait (
  (create-pool
    (<sip-010-ft-trait> <sip-010-ft-trait> (optional (string-ascii 64)) uint (optional {
      tick-spacing: uint,
      initial-price: uint,
    }))
    (response principal uint)
  )
  (register-pool-implementation
    ((string-ascii 64) principal)
    (response bool uint)
  )
  (register-pool-type
    ((string-ascii 64) (string-ascii 32) (string-ascii 128) bool)
    (response bool uint)
  )
  (set-default-pool-type
    ((string-ascii 64))
    (response bool uint)
  )
  (get-pool
    (principal principal)
    (response (optional principal) uint)
  )
  (get-pool-type
    (principal)
    (response (optional (string-ascii 64)) uint)
  )
  (get-pool-implementation
    ((string-ascii 64))
    (response (optional principal) uint)
  )
  (get-pool-info
    (principal)
    (
      response       (optional {
      token-a: principal,
      token-b: principal,
      fee-bps: uint,
      created-at: uint,
      additional-params: (optional {
        tick-spacing: uint,
        initial-price: uint,
      }),
    })
      uint
    )
  )
  (get-pool-count
    ()
    (response uint uint)
  )
  (get-default-pool-type
    ()
    (response (string-ascii 64) uint)
  )
))

;; ===========================================
;; VAULT TRAIT
;; ===========================================
(define-trait vault-trait (
  (deposit
    (principal uint)
    (response uint uint)
  )
  (withdraw
    (principal uint)
    (response uint uint)
  )
  (complete-withdrawal
    (principal)
    (response uint uint)
  )
  (wrap-btc
    (uint (buff 32))
    (response uint uint)
  )
  (unwrap-to-btc
    (uint (buff 64))
    (response uint uint)
  )
  (allocate-to-strategy
    (principal uint)
    (response bool uint)
  )
  (harvest-yield
    (principal)
    (response uint uint)
  )
  (get-vault-stats
    ()
    (
      response       {
      total-sbtc: uint,
      total-shares: uint,
      total-yield: uint,
      share-price: uint,
      paused: bool,
    }
      uint
    )
  )
))

;; ===========================================
;; POOL TRAIT
;; ===========================================
(define-trait pool-trait (
  (swap
    (uint <sip-010-ft-trait> <sip-010-ft-trait>)
    (response uint uint)
  )
  (add-liquidity
    (uint uint <sip-010-ft-trait> <sip-010-ft-trait>)
    (response uint uint)
  )
  (remove-liquidity
    (uint <sip-010-ft-trait> <sip-010-ft-trait>)
    (
      response       {
      amount0: uint,
      amount1: uint,
    }
      uint
    )
  )
  (get-reserves
    ()
    (
      response       {
      reserve0: uint,
      reserve1: uint,
    }
      uint
    )
  )
))

;; ===========================================
;; FLASH LOAN TRAIT
;; ===========================================
(define-trait flash-loan-trait (
  (execute-loan
    (principal uint (optional (buff 1024)))
    (response bool uint)
  )
))
;; ===========================================
;; SIP-009 NFT TRAIT
;; ===========================================
(use-trait sip-009-nft-trait .sip-standards.sip-009-nft-trait)

;; ===========================================
;; STRATEGY TRAIT
;; ===========================================
(define-trait strategy-trait (
  (get-apy () (response uint uint))
  (get-risk-score () (response uint uint))
  (get-total-value-locked () (response uint uint))
  (invest (uint) (response uint uint))
  (divest (uint) (response uint uint))
))

;; ===========================================
;; MONITORING DASHBOARD TRAIT
;; ===========================================
(define-trait monitoring-dashboard-trait (
  (record-metric ((string-ascii 64) uint uint) (response bool uint))
  (trigger-alert ((string-ascii 64) (string-ascii 64) uint uint uint) (response bool uint))
))
