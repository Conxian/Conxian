;; DeFi Primitives Traits
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; ===========================================
;; POOL TRAIT (AMM Pool Interface)
;; ===========================================
(define-trait pool-trait (
  (swap
    (principal principal uint uint uint)
    (response uint uint)
  )
  (add-liquidity
    (uint uint uint uint principal)
    (response uint uint)
  )
  (remove-liquidity
    (uint uint uint principal)
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
  (get-token0
    ()
    (response principal uint)
  )
  (get-token1
    ()
    (response principal uint)
  )
))

;; ===========================================
;; POOL FACTORY TRAIT
;; ===========================================
(define-trait pool-factory-trait (
  (create-pool
    (principal principal uint)
    (response principal uint)
  )
  (get-pool
    (principal principal)
    (response (optional principal) uint)
  )
  (get-all-pools
    ()
    (response (list 1000 principal) uint)
  )
))

;; ===========================================
;; ROUTER TRAIT (Multi-hop Swapping)
;; ===========================================
(define-trait router-trait (
  (swap-exact-tokens-for-tokens
    (uint uint (list 10 principal) (list 10 principal) principal uint)
    (response uint uint)
  )
  (add-liquidity-with-router
    (principal principal uint uint uint uint principal uint)
    (
      response       {
      amountA: uint,
      amountB: uint,
      liquidity: uint,
    }
      uint
    )
  )
))

;; ===========================================
;; CONCENTRATED LIQUIDITY POOL TRAIT (Uniswap V3 style)
;; ===========================================
(define-trait concentrated-liquidity-trait (
  (mint
    (principal int int uint uint principal uint)
    (response uint uint)
  )
  (burn
    (uint)
    (
      response       {
      amount0: uint,
      amount1: uint,
    }
      uint
    )
  )
  (collect
    (uint principal)
    (
      response       {
      amount0: uint,
      amount1: uint,
    }
      uint
    )
  )
  (swap
    (principal bool uint uint uint principal)
    (
      response       {
      amount0: int,
      amount1: int,
    }
      uint
    )
  )
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
;; LENDING POOL TRAIT
;; ===========================================
(define-trait lending-pool-trait (
  (supply
    (<sip-010-ft-trait> uint)
    (response bool uint)
  )
  (withdraw
    (<sip-010-ft-trait> uint)
    (response bool uint)
  )
  (borrow
    (<sip-010-ft-trait> uint)
    (response bool uint)
  )
  (repay
    (<sip-010-ft-trait> uint)
    (response bool uint)
  )
  (get-health-factor
    (principal)
    (response uint uint)
  )
  (liquidate
    (principal principal <sip-010-ft-trait> <sip-010-ft-trait> uint)
    (
      response       {
      repaid: uint,
      seized: uint,
    }
      uint
    )
  )
))

;; ===========================================
;; INTEREST RATE MODEL TRAIT
;; ===========================================
(define-trait interest-rate-model-trait (
  (accrue-interest
    (principal)
    (
      response       {
      total-cash: uint,
      total-borrows: uint,
      total-supplies: uint,
      borrow-index: uint,
      supply-index: uint,
      last-update-block: uint,
    }
      uint
    )
  )
  (initialize-market
    (principal)
    (response bool uint)
  )
  (update-market-state
    (principal int int)
    (response bool uint)
  )
))
