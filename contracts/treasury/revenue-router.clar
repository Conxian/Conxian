;; revenue-router.clar
;; Central Revenue Router for Conxian Protocol
;; Implements TREASURY_AND_REVENUE_ROUTER.md

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u9200))
(define-constant ERR_INVALID_AMOUNT (err u9201))

;; Vault IDs (Must match conxian-vaults.clar)
(define-constant VAULT_TREASURY u1)
(define-constant VAULT_GUARDIAN_REWARDS u2)
(define-constant VAULT_RISK_RESERVE u3)
(define-constant VAULT_OPS_LABS u4)
(define-constant VAULT_LEGAL_BOUNTIES u5)
(define-constant VAULT_GRANTS u6)

(define-constant BPS_TOTAL u10000)

(define-data-var contract-owner principal tx-sender)

;; --- Authorization ---

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Admin ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Core Routing ---

;; @desc Route protocol fees to vaults based on policy
;; @param asset-trait The token contract
;; @param amount Total fee amount
;; @param source-tag Source of fee (e.g. "DEX_SWAP")
(define-public (route-fee
    (asset-trait <sip-010-ft-trait>)
    (amount uint)
    (source-tag (string-ascii 32))
  )
  (let (
      ;; 1. Get Allocation Policy
      (policy (contract-call? .allocation-policy get-allocation source-tag))
      ;; 2. Calculate Splits
      (treasury-share (/ (* amount (get treasury policy)) BPS_TOTAL))
      (guardian-share (/ (* amount (get guardian policy)) BPS_TOTAL))
      (risk-share (/ (* amount (get risk policy)) BPS_TOTAL))
      (ops-share (/ (* amount (get ops policy)) BPS_TOTAL))
      (legal-share (/ (* amount (get legal policy)) BPS_TOTAL))
      (grants-share (/ (* amount (get grants policy)) BPS_TOTAL))
      ;; 3. Handle dust (add to treasury)
      (total-distributed (+ treasury-share
        (+ guardian-share
          (+ risk-share (+ ops-share (+ legal-share grants-share)))
        )))
      (dust (- amount total-distributed))
      (final-treasury (+ treasury-share dust))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; 4. Pull funds from sender to this contract
    (try! (contract-call? asset-trait transfer amount tx-sender (as-contract tx-sender)
      none
    ))

    ;; 5. Deposit to Vaults (as-contract to approve transfers from router)
    (as-contract (begin
      (if (> final-treasury u0)
        (try! (contract-call? .conxian-vaults deposit VAULT_TREASURY asset-trait
          final-treasury
        ))
        false
      )
      (if (> guardian-share u0)
        (try! (contract-call? .conxian-vaults deposit VAULT_GUARDIAN_REWARDS
          asset-trait guardian-share
        ))
        false
      )
      (if (> risk-share u0)
        (try! (contract-call? .conxian-vaults deposit VAULT_RISK_RESERVE asset-trait
          risk-share
        ))
        false
      )
      (if (> ops-share u0)
        (try! (contract-call? .conxian-vaults deposit VAULT_OPS_LABS asset-trait
          ops-share
        ))
        false
      )
      (if (> legal-share u0)
        (try! (contract-call? .conxian-vaults deposit VAULT_LEGAL_BOUNTIES asset-trait
          legal-share
        ))
        false
      )
      (if (> grants-share u0)
        (try! (contract-call? .conxian-vaults deposit VAULT_GRANTS asset-trait
          grants-share
        ))
        false
      )
      (ok true)
    ))
  )
)
