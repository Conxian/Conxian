

;; monitoring-dashboard.clar

;; Provides read-only functions for system monitoring and health checks

;; ===== Constants =====(define-constant ERR_UNAUTHORIZED (err u100))

;; ===== Data Variables =====(define-data-var contract-owner principal tx-sender)

;; ===== Read-Only Functions =====(define-read-only (get-system-health)  (ok {    status: "operational",    block-height: block-height,    last-checked: block-height,    uptime: u100, 

;; Placeholder, would require more complex tracking    total-transactions: u0, 

;; Placeholder, would require global counter    failed-transactions: u0 

;; Placeholder, would require global counter  }))
(define-read-only (get-contract-owner)  (ok (var-get contract-owner)))
(define-public (set-contract-owner (new-owner principal))  (begin    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)    (var-set contract-owner new-owner)    (ok true)  ))