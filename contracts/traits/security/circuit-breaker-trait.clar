(define-trait circuit-breaker-trait
  (
    ;; ===== Core Circuit Breaker Functions =====

    ;; @notice Check if the circuit is open for any operation
    ;; @return (response bool uint) true if circuit is open, false otherwise
    (is-circuit-open () (response bool (err uint)))

    ;; @notice Check if the circuit is open for a specific operation
    ;; @param operation The operation identifier (max 64 chars)
    ;; @return (response bool uint) true if circuit is open for this operation
    (check-circuit-state (operation (string-ascii 64)) (response bool (err uint)))

    ;; @notice Record a successful operation
    (record-success (operation (string-ascii 64)) (response bool (err uint)))

    ;; @notice Record a failed operation
    (record-failure (operation (string-ascii 64)) (response bool (err uint)))

    ;; @notice Get the failure rate for an operation
    (get-failure-rate (operation (string-ascii 64)) (response uint (err uint)))

    ;; @notice Get the current state of the circuit
    (get-circuit-state (operation (string-ascii 64))
      (response
        (tuple
          (state uint)
          (last-checked uint)
          (failure-rate uint)
          (failure-count uint)
          (success-count uint)
        )
        (err uint)
      )
    )

    ;; ===== Admin Functions =====

    ;; @notice Manually override the circuit state (admin only)
    (set-circuit-state (operation (string-ascii 64)) (state bool) (response bool (err uint)))

    ;; @notice Set the failure threshold (admin only)
    (set-failure-threshold (threshold uint) (response bool (err uint)))

    ;; @notice Set the reset timeout (admin only)
    (set-reset-timeout (timeout uint) (response bool (err uint)))

    ;; @notice Get the admin address
    (get-admin () (response principal (err uint)))

    ;; @notice Transfer admin rights
    (set-admin (new-admin principal) (response bool (err uint)))

    ;; ===== Enhanced Features =====

    ;; @notice Set rate limit for an operation
    (set-rate-limit (operation (string-ascii 64)) (limit uint) (window uint) (response bool (err uint)))

    ;; @notice Get rate limit for an operation
    (get-rate-limit (operation (string-ascii 64))
      (response
        (tuple
          (limit uint)
          (window uint)
          (current uint)
          (reset-time uint)
        )
        (err uint)
      )
    )

    ;; @notice Batch record successes
    (batch-record-success (operations (list 20 (string-ascii 64))) (response bool (err uint)))

    ;; @notice Batch record failures
    (batch-record-failure (operations (list 20 (string-ascii 64))) (response bool (err uint)))

    ;; @notice Get health status
    (get-health-status ()
      (response
        (tuple
          (is_operational bool)
          (total_failure_rate uint)
          (last_checked uint)
          (uptime uint)
          (total_operations uint)
          (failed_operations uint)
        )
        (err uint)
      )
    )

    ;; @notice Set circuit breaker mode
    (set-circuit-mode (mode (optional bool)) (response bool (err uint)))

    ;; @notice Get circuit breaker mode
    (get-circuit-mode () (response (optional bool) (err uint)))

    ;; @notice Emergency shutdown (multi-sig protected)
    (emergency-shutdown () (response bool (err uint)))

    ;; @notice Recover from emergency shutdown (multi-sig protected)
    (recover-from-shutdown () (response bool (err uint)))
  )
)
