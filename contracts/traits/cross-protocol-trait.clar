;; ===========================================
;; CROSS-PROTOCOL INTEGRATION TRAIT
;; ===========================================
;; Interface for cross-protocol integrations and yield optimization
;;
;; This trait provides functions for integrating with external DeFi protocols
;; and optimizing yield across multiple platforms.
;;
;; Example usage:
;;   (use-trait cross-protocol .cross-protocol-trait.cross-protocol-trait)
(define-trait cross-protocol-trait
  (
    ;; Register external protocol integration
    ;; @param protocol-name: name of external protocol
    ;; @param protocol-contract: external protocol contract principal
    ;; @param protocol-type: type of protocol (lending, dex, yield, etc.)
    ;; @return (response bool uint): success flag and error code
    (register-protocol ((string-ascii 32) principal (string-ascii 20)) (response bool uint))
    
    ;; Deposit to external protocol
    ;; @param protocol-name: target protocol name
    ;; @param token: token to deposit
    ;; @param amount: amount to deposit
    ;; @param user: user principal
    ;; @return (response uint uint): external position ID and error code
    (deposit-to-protocol ((string-ascii 32) principal uint principal) (response uint uint))
    
    ;; Withdraw from external protocol
    ;; @param protocol-name: source protocol name
    ;; @param external-position-id: external position identifier
    ;; @param amount: amount to withdraw
    ;; @param user: user principal
    ;; @return (response uint uint): withdrawn amount and error code
    (withdraw-from-protocol ((string-ascii 32) uint uint principal) (response uint uint))
    
    ;; Claim rewards from external protocol
    ;; @param protocol-name: source protocol name
    ;; @param external-position-id: external position identifier
    ;; @param user: user principal
    ;; @return (response (list 10 (tuple (token principal) (amount uint))) uint): rewards and error code
    (claim-rewards ((string-ascii 32) uint principal) (response (list 10 (tuple (token principal) (amount uint))) uint))
    
    ;; Get optimal allocation across protocols
    ;; @param token: token to allocate
    ;; @param total-amount: total amount to allocate
    ;; @param risk-level: user risk preference (1-10)
    ;; @param time-horizon: investment time horizon in blocks
    ;; @return (response (list 10 (tuple (protocol (string-ascii 32)) (allocation uint) (expected-apr uint))) uint): optimal allocation and error code
    (get-optimal-allocation (principal uint uint uint) (response (list 10 (tuple (protocol (string-ascii 32)) (allocation uint) (expected-apr uint))) uint))
    
    ;; Rebalance allocations across protocols
    ;; @param user: user principal
    ;; @param rebalancing-strategy: strategy to use for rebalancing
    ;; @param max-slippage: maximum acceptable slippage in basis points
    ;; @return (response bool uint): success flag and error code
    (rebalance-allocations (principal (string-ascii 20) uint) (response bool uint))
    
    ;; Get protocol information
    ;; @param protocol-name: protocol name
    ;; @return (response (tuple ...) uint): protocol info and error code
    (get-protocol-info ((string-ascii 32)) (response (tuple 
      (contract principal)
      (protocol-type (string-ascii 20))
      (tvl uint)
      (apr uint)
      (risk-score uint)
      (is-active bool)
      (last-updated uint)
    ) uint))
    
    ;; Get user cross-protocol positions
    ;; @param user: user principal
    ;; @return (response (list 20 (tuple ...)) uint): user positions and error code
    (get-user-positions (principal) (response (list 20 (tuple 
      (protocol (string-ascii 32))
      (external-position-id uint)
      (token principal)
      (amount uint)
      (unclaimed-rewards uint)
      (last-claim uint)
    )) uint))
    
    ;; Calculate cross-protocol yield
    ;; @param user: user principal
    ;; @param time-period: time period for calculation in blocks
    ;; @return (response uint uint): total yield and error code
    (calculate-cross-yield (principal uint) (response uint uint))
    
    ;; Emergency withdrawal from all protocols
    ;; @param user: user principal
    ;; @param emergency-reason: reason for emergency withdrawal
    ;; @return (response (list 10 (tuple (protocol (string-ascii 32)) (amount uint))) uint): withdrawn amounts and error code
    (emergency-withdraw-all (principal (string-ascii 50)) (response (list 10 (tuple (protocol (string-ascii 32)) (amount uint))) uint))
    
    ;; Set protocol risk parameters
    ;; @param protocol-name: protocol name
    ;; @param risk-score: risk score (1-100)
    ;; @param max-allocation: maximum allocation percentage
    ;; @param is-active: protocol active status
    ;; @return (response bool uint): success flag and error code
    (set-protocol-risk-params ((string-ascii 32) uint uint bool) (response bool uint))
  )
)