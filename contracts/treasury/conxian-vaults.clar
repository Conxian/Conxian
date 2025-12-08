;; conxian-vaults.clar
;; Central Vault System for Conxian Protocol
;; Implements TREASURY_AND_REVENUE_ROUTER.md

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u9001))
(define-constant ERR_INVALID_VAULT (err u9002))
(define-constant ERR_ASSET_NOT_ALLOWED (err u9003))

;; Vault IDs
(define-constant VAULT_TREASURY u1)
(define-constant VAULT_GUARDIAN_REWARDS u2)
(define-constant VAULT_RISK_RESERVE u3)
(define-constant VAULT_OPS_LABS u4)
(define-constant VAULT_LEGAL_BOUNTIES u5)
(define-constant VAULT_GRANTS u6)

;; Roles
(define-data-var contract-owner principal tx-sender)
(define-map authorized-spenders { vault-id: uint, spender: principal } bool)

;; Vault Balances: (vault-id, asset) -> amount
(define-map vault-balances 
  { vault-id: uint, asset: principal } 
  uint
)

;; --- Authorization ---

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized-spender (vault-id uint) (spender principal))
  (default-to false (map-get? authorized-spenders { vault-id: vault-id, spender: spender }))
)

;; --- Admin ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-authorized-spender (vault-id uint) (spender principal) (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (map-set authorized-spenders { vault-id: vault-id, spender: spender } enabled)
    (ok true)
  )
)

;; --- Core Vault Functions ---

;; @desc Deposit assets into a specific vault
;; @param vault-id Destination vault
;; @param asset-trait The token contract
;; @param amount Amount to deposit
(define-public (deposit
    (vault-id uint)
    (asset-trait <sip-010-ft-trait>)
    (amount uint)
  )
  (let (
    (asset-contract (contract-of asset-trait))
    (current-bal (default-to u0 (map-get? vault-balances { vault-id: vault-id, asset: asset-contract })))
  )
    ;; Transfer tokens from sender to this contract
    (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update ledger
    (map-set vault-balances { vault-id: vault-id, asset: asset-contract } (+ current-bal amount))
    
    (print {
      event: "deposit",
      vault-id: vault-id,
      asset: asset-contract,
      amount: amount
    })
    (ok true)
  )
)

;; @desc Withdraw assets from a vault (Requires authorization)
;; @param vault-id Source vault
;; @param asset-trait The token contract
;; @param amount Amount to withdraw
;; @param recipient Recipient address
(define-public (withdraw
    (vault-id uint)
    (asset-trait <sip-010-ft-trait>)
    (amount uint)
    (recipient principal)
  )
  (let (
    (asset-contract (contract-of asset-trait))
    (current-bal (default-to u0 (map-get? vault-balances { vault-id: vault-id, asset: asset-contract })))
  )
    ;; Check Authorization
    (asserts! (or (is-contract-owner) (is-authorized-spender vault-id tx-sender)) ERR_UNAUTHORIZED)
    
    ;; Check Balance
    (asserts! (>= current-bal amount) ERR_INSUFFICIENT_BALANCE)
    
    ;; Update ledger
    (map-set vault-balances { vault-id: vault-id, asset: asset-contract } (- current-bal amount))
    
    ;; Transfer tokens to recipient
    (as-contract (try! (contract-call? asset-trait transfer amount tx-sender recipient none)))
    
    (print {
      event: "withdraw",
      vault-id: vault-id,
      asset: asset-contract,
      amount: amount,
      recipient: recipient,
      spender: tx-sender
    })
    (ok true)
  )
)

;; @desc Internal transfer between vaults (Accounting only)
(define-public (transfer-vault-to-vault
    (from-vault-id uint)
    (to-vault-id uint)
    (asset principal)
    (amount uint)
  )
  (let (
    (src-bal (default-to u0 (map-get? vault-balances { vault-id: from-vault-id, asset: asset })))
    (dst-bal (default-to u0 (map-get? vault-balances { vault-id: to-vault-id, asset: asset })))
  )
    (asserts! (or (is-contract-owner) (is-authorized-spender from-vault-id tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (>= src-bal amount) ERR_INSUFFICIENT_BALANCE)
    
    (map-set vault-balances { vault-id: from-vault-id, asset: asset } (- src-bal amount))
    (map-set vault-balances { vault-id: to-vault-id, asset: asset } (+ dst-bal amount))
    
    (print {
      event: "vault-transfer",
      from-vault: from-vault-id,
      to-vault: to-vault-id,
      asset: asset,
      amount: amount
    })
    (ok true)
  )
)

;; --- Read Only ---

(define-read-only (get-vault-balance (vault-id uint) (asset principal))
  (default-to u0 (map-get? vault-balances { vault-id: vault-id, asset: asset }))
)
