;; Core Protocol Traits - Production Module

;; ===========================================
;; UPGRADEABLE TRAIT
;; ===========================================
(define-trait upgradeable-trait
  (
    (upgrade-contract (principal) (response bool uint))
    (get-implementation () (response principal uint))
  )
)

;; ===========================================
;; REVENUE DISTRIBUTOR TRAIT
;; ===========================================
(define-trait revenue-distributor-trait
  (
    (report-revenue (principal uint principal) (response bool uint))
  )
)

;; ===========================================
;; TOKEN COORDINATOR TRAIT
;; ===========================================
(define-trait token-coordinator-trait
  (
    (on-dimensional-yield (uint uint uint) (response bool uint))
  )
)
