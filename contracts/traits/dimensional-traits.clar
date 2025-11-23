;; Dimensional Traits - Multi-Dimensional Position Management

;; ===========================================
;; DIMENSIONAL TRAIT (Core Multi-Dimensional Interface)
;; ===========================================
(define-trait dimensional-trait
  (
    (get-position (uint) (response (optional {
      owner: principal,
      asset: principal,
      collateral: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      is-long: bool
    }) uint))
    
    (close-position (uint uint) (response bool uint))
    
    (get-protocol-stats () (response {
      total-positions: uint,
      total-volume: uint,
      total-value-locked: uint
    } uint))
  )
)

;; ===========================================
;; POSITION MANAGER TRAIT
;; ===========================================
(define-trait position-manager-trait
  (
    (open-position (principal uint uint bool (optional uint) (optional uint)) (response uint uint))
    (close-position (uint (optional uint)) (response {collateral-returned: uint, pnl: int} uint))
    (get-position (uint) (response {
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
      is-active: bool
    } uint))
    (update-position (uint (optional uint) (optional uint) (optional uint) (optional uint)) (response bool uint))
  )
)

;; ===========================================
;; COLLATERAL MANAGER TRAIT
;; ===========================================
(define-trait collateral-manager-trait
  (
    (deposit-funds (uint principal) (response bool uint))
    (withdraw-funds (uint principal) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

;; ===========================================
;; FUNDING RATE CALCULATOR TRAIT
;; ===========================================
(define-trait funding-rate-calculator-trait
  (
    (update-funding-rate (principal) (response {
      funding-rate: int, 
      index-price: uint, 
      timestamp: uint, 
      cumulative-funding: int
    } uint))
    
    (apply-funding-to-position (principal uint) (response {
      funding-rate: int, 
      funding-payment: int, 
      new-collateral: uint, 
      timestamp: uint
    } uint))
  )
)
