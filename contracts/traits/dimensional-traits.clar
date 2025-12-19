;; Dimensional Traits - Multi-Dimensional Position Management

;; ===========================================
;; DIMENSIONAL TRAIT (Core Multi-Dimensional Interface)
;; ===========================================
(define-trait dimensional-trait (
  (get-position
    (uint)
    (
      response       (optional {
      owner: principal,
      asset: principal,
      collateral: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      is-long: bool,
      funding-rate: int,
      last-updated: uint,
      stop-loss: (optional uint),
      take-profit: (optional uint),
      is-active: bool,
    })
      uint
    )
  )
  (close-position
    (uint uint)
    (response bool uint)
  )
  (liquidate-position
    (uint principal)
    (
      response       {
      collateral-returned: uint,
      reward: uint,
    }
      uint
    )
  )
  (get-protocol-stats
    ()
    (
      response       {
      total-positions: uint,
      total-volume: uint,
      total-value-locked: uint,
    }
      uint
    )
  )
))

;; ===========================================
;; POSITION MANAGER TRAIT
;; ===========================================
(define-trait position-manager-trait (
  (open-position
    (principal uint uint bool (optional uint) (optional uint))
    (response uint uint)
  )
  (close-position
    (uint (optional uint))
    (
      response       {
      collateral-returned: uint,
      pnl: int,
    }
      uint
    )
  )
  (get-position
    (uint)
    (
      response       {
      owner: principal,
      asset: principal,
      collateral: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      is-long: bool,
      funding-rate: int,
      last-updated: uint,
      stop-loss: (optional uint),
      take-profit: (optional uint),
      is-active: bool,
    }
      uint
    )
  )
  (update-position
    (uint (optional uint) (optional uint) (optional uint) (optional uint))
    (response bool uint)
  )
))

;; ===========================================
;; COLLATERAL MANAGER TRAIT
;; ===========================================
(define-trait collateral-manager-trait (
  (deposit-funds
    (uint principal)
    (response bool uint)
  )
  (withdraw-funds
    (uint principal)
    (response bool uint)
  )
  (get-balance
    (principal)
    (response uint uint)
  )
))

;; ===========================================
;; FUNDING RATE CALCULATOR TRAIT
;; ===========================================
(define-trait funding-rate-calculator-trait (
  (update-funding-rate
    (principal)
    (
      response       {
      funding-rate: int,
      index-price: uint,
      timestamp: uint,
      cumulative-funding: int,
    }
      uint
    )
  )
  (apply-funding-to-position
    (principal uint)
    (
      response       {
      funding-rate: int,
      funding-payment: int,
      new-collateral: uint,
      timestamp: uint,
    }
      uint
    )
  )
))

;; DIMENSIONAL ENGINE TRAIT
;; ===========================================
(define-trait dimensional-engine-trait (
  (update-position
    (uint (optional uint) (optional uint) (optional uint) (optional uint) <position-manager-trait>)
    (response bool uint)
  )
  (get-position
    (uint)
    (
      response       {
      asset: principal,
      entry-price: uint,
    }
      uint
    )
  )
))

;; ===========================================
;; LENDING POOL TRAIT (minimal)
;; ===========================================
(define-trait lending-pool-trait (
  (get-health-factor
    (principal)
    (response uint uint)
  )
  (update-position
    (principal uint)
    (response bool uint)
  )
  (get-liquidation-amounts
    (principal principal principal uint)
    (response { collateral-to-seize: uint } uint)
  )
  (liquidate
    (principal principal principal uint uint)
    (response bool uint)
  )
))

;; DLC manager trait
(define-trait dlc-manager-trait (
  (register-dlc
    ((buff 32) uint principal uint)
    (response bool uint)
  )
  (close-dlc
    ((buff 32))
    (response bool uint)
  )
  (liquidate-dlc
    ((buff 32))
    (response bool uint)
  )
  (get-dlc-info
    ((buff 32))
    (
      response       (optional {
      owner: principal,
      value-locked: uint,
      loan-id: uint,
      status: (string-ascii 20),
      closing-price: (optional uint),
    })
      uint
    )
  )
))
;; Risk manager trait
(define-trait risk-manager-trait (
  (set-risk-parameters
    (uint uint uint)
    (response bool uint)
  )
  (set-liquidation-rewards
    (uint uint)
    (response bool uint)
  )
  (calculate-liquidation-price
    ({
      entry-price: uint,
      leverage: uint,
      is-long: bool,
    })
    (response uint uint)
  )
))

;; Liquidation trait
(define-trait liquidation-trait (
  (can-liquidate-position
    (principal principal principal <lending-pool-trait>)
    (response bool uint)
  )
  (liquidate-position
    (principal principal principal uint uint <lending-pool-trait>)
    (response bool uint)
  )
))
