;; Cross-Chain & Bitcoin Traits - DLC and Bitcoin Integration

;; ===========================================
;; DLC MANAGER TRAIT (Discreet Log Contracts)
;; ===========================================
(define-trait dlc-manager-trait
  (
    ;; Register DLC with Bitcoin finality validation
    (register-dlc ((buff 32) uint principal uint) (response bool uint))
    
    ;; Close DLC normally (repayment/expiry)
    (close-dlc ((buff 32)) (response bool uint))
    
    ;; Liquidate DLC (force close)
    (liquidate-dlc ((buff 32)) (response bool uint))
    
    ;; Get DLC details
    (get-dlc-info ((buff 32)) (response (optional {
      owner: principal,
      value-locked: uint,
      loan-id: uint,
      status: (string-ascii 20),
      closing-price: (optional uint)
    }) uint))
  )
)

;; ===========================================
;; BITCOIN BRIDGE TRAIT
;; ===========================================
(define-trait btc-bridge-trait
  (
    (deposit-btc (uint (buff 32)) (response uint uint))
    (withdraw-btc (uint (buff 128)) (response bool uint))
    (get-btc-balance (principal) (response uint uint))
    (validate-btc-finality (uint) (response bool uint))
  )
)

;; ===========================================
;; CROSS-CHAIN VERIFIER TRAIT
;; ===========================================
(define-trait cross-chain-verifier-trait
  (
    (verify-cross-chain-tx ((buff 32) (buff 1024)) (response bool uint))
    (get-burn-block-confirmation-count (uint) (response uint uint))
  )
)

;; ===========================================
;; SBTC INTEGRATION TRAIT
;; ===========================================
(define-trait sbtc-trait
  (
    (mint-sbtc (uint (buff 32)) (response uint uint))
    (burn-sbtc (uint) (response (buff 128) uint))
    (get-sbtc-supply () (response uint uint))
  )
)
