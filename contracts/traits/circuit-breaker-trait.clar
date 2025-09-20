;; Circuit Breaker Trait
;; Defines the standard interface for circuit breakers in the Conxian protocol

(define-trait circuit-breaker-trait
  (
    ;; Check if the circuit is open for a given operation
    (check-circuit-state (operation (string-ascii 64)) (response bool uint))
    
    ;; Record a successful operation
    (record-success (operation (string-ascii 64)) (response bool uint))
    
    ;; Record a failed operation
    (record-failure (operation (string-ascii 64)) (response bool uint))
    
    ;; Get the failure rate for an operation
    (get-failure-rate (operation (string-ascii 64)) (response uint uint))
    
    ;; Get the current state of the circuit
    (get-circuit-state (operation (string-ascii 64)) (response (tuple (state uint) (last-checked uint) (failure-rate uint)) uint))
    
    ;; Manually override the circuit state (admin only)
    (set-circuit-state (operation (string-ascii 64)) (state bool) (response bool uint))
    
    ;; Set the failure threshold (admin only)
    (set-failure-threshold (threshold uint) (response bool uint))
    
    ;; Set the reset timeout (admin only)
    (set-reset-timeout (timeout uint) (response bool uint))
    
    ;; Get the admin address
    (get-admin () (response principal uint))
    
    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool uint))
  )
)
