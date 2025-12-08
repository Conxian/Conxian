;; allocation-policy.clar
;; Revenue Allocation Policy for Conxian Protocol
;; Implements TREASURY_AND_REVENUE_ROUTER.md

(define-constant ERR_UNAUTHORIZED (err u9100))
(define-constant ERR_INVALID_ALLOCATION (err u9101))

(define-constant BPS_TOTAL u10000) ;; 100%

(define-data-var contract-owner principal tx-sender)

;; Allocation Config
;; Source Tag -> { vault-allocations }
(define-map allocations
  (string-ascii 32)
  {
    treasury: uint,
    guardian: uint,
    risk: uint,
    ops: uint,
    legal: uint,
    grants: uint
  }
)

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

;; @desc Set allocation policy for a revenue source
;; @param source-tag e.g. "DEX_SWAP", "LENDING_INTEREST"
(define-public (set-allocation
    (source-tag (string-ascii 32))
    (treasury uint)
    (guardian uint)
    (risk uint)
    (ops uint)
    (legal uint)
    (grants uint)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    
    ;; Validate sum = 10000
    (asserts! (is-eq (+ treasury guardian risk ops legal grants) BPS_TOTAL) ERR_INVALID_ALLOCATION)
    
    (map-set allocations source-tag {
      treasury: treasury,
      guardian: guardian,
      risk: risk,
      ops: ops,
      legal: legal,
      grants: grants
    })
    
    (print {
      event: "allocation-set",
      source: source-tag,
      treasury: treasury,
      guardian: guardian,
      risk: risk,
      ops: ops,
      legal: legal,
      grants: grants
    })
    (ok true)
  )
)

;; --- Read Only ---

(define-read-only (get-allocation (source-tag (string-ascii 32)))
  (default-to 
    { treasury: u10000, guardian: u0, risk: u0, ops: u0, legal: u0, grants: u0 } ;; Default to Treasury
    (map-get? allocations source-tag)
  )
)
