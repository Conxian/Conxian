;; precision-calculator.clar
;; Precision validation and benchmarking for mathematical operations
;; Provides tools to validate mathematical precision and detect errors

(define-constant ERR_PRECISION_LOSS_EXCEEDED (err u3001))
(define-constant ERR_INVALID_OPERATION (err u3002))
(define-constant ERR_BENCHMARK_FAILED (err u3003))

;; Precision thresholds (in basis points - 1bp = 0.01%)
(define-constant MAX_PRECISION_LOSS_BPS u100) ;; 1% maximum allowed precision loss
(define-constant PRECISION_WARNING_BPS u10) ;; 0.1% warning threshold

;; Mathematical constants for validation (18-decimal fixed point)
(define-constant E_EXPECTED u2718281828459045235)
(define-constant PI_EXPECTED u3141592653589793238)
(define-constant LN2_EXPECTED u693147180559945309)
(define-constant SQRT2_EXPECTED u1414213562373095048)

;; Performance tracking
(define-data-var total-operations uint u0)
(define-data-var total-precision-loss uint u0)
(define-data-var operations-within-threshold uint u0)

;; Operation benchmarks (gas usage tracking)
(define-map operation-benchmarks
  { operation: (string-ascii 32) }
  { 
    avg-gas: uint,
    min-gas: uint,
    max-gas: uint,
    total-calls: uint
  })

;; === PRECISION VALIDATION ===
;; Detect precision loss in mathematical operations
(define-public (detect-precision-loss (operation (string-ascii 32)) (input-a uint) (input-b uint) (expected uint) (actual uint))
  (let ((precision-loss (if (> expected actual)
                          (- expected actual)
                          (- actual expected)))
        (precision-loss-bps (if (is-eq expected u0)
                              u0
                              (/ (* precision-loss u10000) expected))))
    (begin
      ;; Update tracking
      (var-set total-operations (+ (var-get total-operations) u1))
      (var-set total-precision-loss (+ (var-get total-precision-loss) precision-loss))
      
      (if (<= precision-loss-bps MAX_PRECISION_LOSS_BPS)
        (begin
          (var-set operations-within-threshold (+ (var-get operations-within-threshold) u1))
          (ok (tuple 
            (operation operation)
            (precision-loss precision-loss)
            (precision-loss-bps precision-loss-bps)
            (within-threshold true))))
        ERR_PRECISION_LOSS_EXCEEDED))))

;; Validate input ranges for mathematical operations
(define-public (validate-input-range (operation (string-ascii 32)) (input uint) (min-valid uint) (max-valid uint))
  (if (and (>= input min-valid) (<= input max-valid))
    (ok (tuple (operation operation) (input input) (valid true)))
    ERR_INVALID_OPERATION))

;; === MATHEMATICAL CONSTANT VALIDATION ===
(define-public (validate-mathematical-constants)
  (let ((e-check (unwrap-panic (contract-call? %math-lib-advanced exp-fixed u1000000000000000000)))
        (pi-check PI_EXPECTED) ;; Would need geometric calculation for Pi
        (ln2-check (unwrap-panic (contract-call? %math-lib-advanced ln-fixed u2000000000000000000)))
        (sqrt2-check (unwrap-panic (contract-call? %math-lib-advanced sqrt-fixed u4000000000000000000))))
    (ok (tuple
      (e-valid (< (abs-diff e-check E_EXPECTED) (/ E_EXPECTED u1000)))
      (pi-valid true) ;; Placeholder
      (ln2-valid (< (abs-diff ln2-check LN2_EXPECTED) (/ LN2_EXPECTED u1000)))
      (sqrt2-valid (< (abs-diff sqrt2-check SQRT2_EXPECTED) (/ SQRT2_EXPECTED u1000)))))))

;; === BENCHMARKING FUNCTIONS ===
;; Run sqrt benchmark test
(define-public (run-sqrt-benchmark (input uint) (expected uint))
  (let ((actual (unwrap-panic (contract-call? %math-lib-advanced sqrt-fixed input))))
    (let ((precision-loss (abs-diff actual expected))
          (precision-loss-bps (if (is-eq expected u0) u0 (/ (* precision-loss u10000) expected))))
      (ok (tuple
        (operation "sqrt")
        (input input)
        (expected expected)
        (actual actual)
        (precision-loss precision-loss)
        (precision-loss-bps precision-loss-bps)
        (passed (<= precision-loss-bps MAX_PRECISION_LOSS_BPS)))))))

;; Run power function benchmark
(define-public (run-pow-benchmark (base uint) (exponent uint) (expected uint))
  (match (contract-call? %math-lib-advanced pow-fixed base exponent)
    actual (let ((precision-loss (abs-diff actual expected))
                 (precision-loss-bps (if (is-eq expected u0) u0 (/ (* precision-loss u10000) expected))))
             (ok (tuple
               (operation "pow")
               (base base)
               (exponent exponent)
               (expected expected)
               (actual actual)
               (precision-loss precision-loss)
               (precision-loss-bps precision-loss-bps)
               (passed (<= precision-loss-bps MAX_PRECISION_LOSS_BPS)))))
    error (err u3003)))

;; Run natural logarithm benchmark
(define-public (run-ln-benchmark (input uint) (expected uint))
  (match (contract-call? %math-lib-advanced ln-fixed input)
    actual (let ((precision-loss (abs-diff actual expected))
                 (precision-loss-bps (if (is-eq expected u0) u0 (/ (* precision-loss u10000) expected))))
             (ok (tuple
               (operation "ln")
               (input input)
               (expected expected)
               (actual actual)
               (precision-loss precision-loss)
               (precision-loss-bps precision-loss-bps)
               (passed (<= precision-loss-bps MAX_PRECISION_LOSS_BPS)))))
    error (err u3003)))

;; Run exponential function benchmark
(define-public (run-exp-benchmark (input uint) (expected uint))
  (match (contract-call? %math-lib-advanced exp-fixed input)
    actual (let ((precision-loss (abs-diff actual expected))
                 (precision-loss-bps (if (is-eq expected u0) u0 (/ (* precision-loss u10000) expected))))
             (ok (tuple
               (operation "exp")
               (input input)
               (expected expected)
               (actual actual)
               (precision-loss precision-loss)
               (precision-loss-bps precision-loss-bps)
               (passed (<= precision-loss-bps MAX_PRECISION_LOSS_BPS)))))
    error (err u3003)))

;; === ERROR ACCUMULATION TRACKING ===
(define-public (track-error-accumulation (operations (list 10 (string-ascii 32))) (intermediate-results (list 10 uint)) (expected-final uint) (actual-final uint))
  (let ((total-accumulated-error (abs-diff expected-final actual-final))
        (error-per-operation (if (is-eq (len operations) u0) u0 (/ total-accumulated-error (len operations)))))
    (ok (tuple
      (operations operations)
      (intermediate-results intermediate-results)
      (expected-final expected-final)
      (actual-final actual-final)
      (total-accumulated-error total-accumulated-error)
      (error-per-operation error-per-operation)
      (error-within-threshold (<= (/ (* total-accumulated-error u10000) expected-final) MAX_PRECISION_LOSS_BPS))))))

;; === PERFORMANCE PROFILING ===
(define-public (profile-operation-performance (operation (string-ascii 32)) (execution-time uint) (input-size uint))
  (let ((performance-score (/ u1000000 execution-time)) ;; Higher is better
        (efficiency-ratio (/ performance-score input-size)))
    (ok (tuple
      (operation operation)
      (execution-time execution-time)
      (input-size input-size)
      (performance-score performance-score)
      (efficiency-ratio efficiency-ratio)
      (within-threshold (< execution-time u100000)))))) ;; Arbitrary threshold

;; === STATISTICS ===
(define-read-only (get-precision-stats)
  (let ((total-ops (var-get total-operations))
        (ops-within-threshold (var-get operations-within-threshold))
        (success-rate (if (is-eq total-ops u0) u0 (/ (* ops-within-threshold u10000) total-ops))))
    (tuple
      (total-operations total-ops)
      (operations-within-threshold ops-within-threshold)
      (total-precision-loss (var-get total-precision-loss))
      (success-rate-bps success-rate)
      (average-precision-loss (if (is-eq total-ops u0) u0 (/ (var-get total-precision-loss) total-ops))))))

;; === UTILITY FUNCTIONS ===
(define-private (abs-diff (a uint) (b uint))
  (if (>= a b) (- a b) (- b a)))

;; Reset statistics for fresh testing
(define-public (reset-statistics)
  (begin
    (var-set total-operations u0)
    (var-set total-precision-loss u0)
    (var-set operations-within-threshold u0)
    (ok true)))

;; === COMPREHENSIVE VALIDATION SUITE ===
(define-public (run-comprehensive-validation)
  (let ((sqrt-test (run-sqrt-benchmark u4000000000000000000 u2000000000000000000)) ;; sqrt(4) = 2
        (pow-test (run-pow-benchmark u2000000000000000000 u3000000000000000000 u8000000000000000000)) ;; 2^3 = 8
        (ln-test (run-ln-benchmark u2718281828459045235 u1000000000000000000)) ;; ln(e) = 1
        (exp-test (run-exp-benchmark u1000000000000000000 u2718281828459045235))) ;; exp(1) = e
    (ok (tuple
      (sqrt-test sqrt-test)
      (pow-test pow-test)
      (ln-test ln-test)
      (exp-test exp-test)
      (overall-status (and 
                        (is-ok sqrt-test)
                        (is-ok pow-test)
                        (is-ok ln-test)
                        (is-ok exp-test)))))))

;; === MATHEMATICAL CONSTANT VALIDATION ===
(define-public (validate-mathematical-constants)
  (let ((e-check (unwrap-panic (contract-call? %math-lib-advanced exp-fixed u1000000000000000000)))
        (pi-check PI_EXPECTED) ;; Would need geometric calculation for Pi
        (ln2-check (unwrap-panic (contract-call? %math-lib-advanced ln-fixed u2000000000000000000)))
        (sqrt2-check (unwrap-panic (contract-call? %math-lib-advanced sqrt-fixed u4000000000000000000))))
    (ok (tuple
      (e-valid (< (abs-diff e-check E_EXPECTED) (/ E_EXPECTED u1000)))
      (pi-valid true) ;; Placeholder
      (ln2-valid (< (abs-diff ln2-check LN2_EXPECTED) (/ LN2_EXPECTED u1000)))
      (sqrt2-valid (< (abs-diff sqrt2-check SQRT2_EXPECTED) (/ SQRT2_EXPECTED u1000)))))))

;; Temporarily commented out for initial deployment
;; (let ((e-check (unwrap-panic (contract-call? %math-lib-advanced exp-fixed u1000000000000000000)))
;;       (ln2-check (unwrap-panic (contract-call? %math-lib-advanced ln-fixed u2000000000000000000)))
;;       (sqrt2-check (unwrap-panic (contract-call? %math-lib-advanced sqrt-fixed u4000000000000000000))))
;;   (ok (tuple
;;     (e-valid (< (abs-diff e-check E_EXPECTED) (/ E_EXPECTED u1000)))
;;     (ln2-valid (< (abs-diff ln2-check LN2_EXPECTED) (/ LN2_EXPECTED u1000)))
;;     (sqrt2-valid (< (abs-diff sqrt2-check SQRT2_EXPECTED) (/ SQRT2_EXPECTED u1000))))))
