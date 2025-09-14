;; Conxian Manual Testing Commands
;; Copy and paste these into clarinet console for interactive testing

;; === BASIC CONTRACT VERIFICATION ===

;; Traits and interfaces
;; - sip-010-trait is an interface (not directly callable). Implemented by tokenized-bond and mock-token.

;; === MOCK TOKEN (SIP-010) ===

;; Verify token metadata and state
(contract-call .mock-token get-name)
(contract-call .mock-token get-symbol)
(contract-call .mock-token get-decimals)
(contract-call .mock-token get-total-supply)
;; Example: set token URI (public, no auth in mock)
(contract-call? .mock-token set-token-uri (some "https://example.com/mock.json"))

;; === TOKENIZED BOND (SIP-010) ===

;; Read-only queries
(contract-call .tokenized-bond get-name)
(contract-call .tokenized-bond get-symbol)
(contract-call .tokenized-bond get-decimals)
(contract-call .tokenized-bond get-total-supply)
(contract-call .tokenized-bond get-payment-token-contract)
;; Example issuance (must be called by contract owner)
;; name, symbol, decimals, initial-supply, maturity-in-blocks, coupon-rate-scaled, frequency-in-blocks, face-value, payment-token-address
(contract-call? .tokenized-bond issue-bond "Conxian Bond 2025" "B25" u6 u1000000 u10000 u144 u1000 .mock-token)
;; Claim coupons (requires bond issued and periods elapsed)
(contract-call? .tokenized-bond claim-coupons .mock-token)
;; Redeem at maturity (after maturity block)
(contract-call? .tokenized-bond redeem-at-maturity .mock-token)

;; === DIMENSIONAL REGISTRY ===

;; Read an existing dimension weight (if registered)
(contract-call .dim-registry get-dimension-weight u1)
;; Register a new dimension (owner only)
(contract-call? .dim-registry register-dimension u1 u100)
;; Update a dimension weight (oracle principal only)
(contract-call? .dim-registry update-weight u1 u110)

;; === INTEGRATION TESTS ===

;; Tokenized bond flow (simulated)
;; 1. Issue bond as deployer (see above)
;; 2. Transfer bond tokens (example):
;;    (contract-call? .tokenized-bond transfer u100 tx-sender 'ST1J2... none)
;; 3. After some blocks, claim coupons using mock token:
;;    (contract-call? .tokenized-bond claim-coupons .mock-token)
;; 4. After maturity, redeem principal + final coupon:
;;    (contract-call? .tokenized-bond redeem-at-maturity .mock-token)

;; Dimensional registry flow
;; 1. (contract-call? .dim-registry register-dimension u42 u100) ; as owner
;; 2. (contract-call? .dim-registry update-weight u42 u125)      ; as oracle
;; 3. (contract-call .dim-registry get-dimension-weight u42)

;; Notes:
;; - Use the accounts defined in Clarinet.toml (e.g., deployer, wallet_1) when switching tx-sender.
;; - Some calls require specific authorization (contract owner or oracle) and will fail otherwise.

