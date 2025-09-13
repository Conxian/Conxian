;; monitor-trait.clar
;; Trait definition for protocol invariant monitor contracts

(define-trait monitor-trait
  (
    ;; System health checks
    (is-system-operational () (response bool uint))
    (is-protocol-paused () (response bool uint))
    (check-system-health () (response bool uint))
    
    ;; Contract registration
    (register-contract (principal (string-ascii 50)) (response bool uint))
    (is-contract-registered (principal) (response bool uint))
    
    ;; System control
    (pause-system () (response bool uint))
    (unpause-system () (response bool uint))
    
    ;; Violation reporting
    (report-invariant-violation (principal (string-ascii 50) uint) (response bool uint))
    (get-system-status () (response {paused: bool, monitoring-active: bool, last-check: uint} uint))
  )
)




