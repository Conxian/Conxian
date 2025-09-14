;; Test DAO governance functions
(contract-call? .dao-governance get-proposal u1)

;; Test treasury functions  
(contract-call? .treasury get-treasury-balance)
(contract-call? .treasury get-treasury-summary)

;; Test bounty system
(contract-call? .bounty-system get-bounty u1)

;; Test token functions
(contract-call? .cxvg-token get-total-supply)
(contract-call? .CXVG get-total-supply)

;; Test registry
(contract-call? .registry get-count)

