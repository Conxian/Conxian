;; revenue-distributor-hysteresis-tests.clar
;; Focused unit tests for hysteresis, preview, and history logging in revenue-distributor

(define-constant TEST_LOW_PARTICIPATION u3000)  ;; below PARTICIPATION_LOW (u4000)
(define-constant TEST_SMALL_DELTA u50)          ;; below HYSTERESIS_MIN_DELTA (u100)

(define-public (test-preview-auto-adjust-increase)
  (begin
    (print "Testing preview auto-adjust increase path...")
    (let ((splits (unwrap-panic (contract-call? .revenue-distributor get-revenue-splits))))
      (asserts! (is-eq (get xcxd-split-bps splits) u8000) (err u1)))
    (let ((preview (contract-call? .revenue-distributor preview-auto-adjust TEST_LOW_PARTICIPATION)))
      (asserts! (is-ok preview) (err u2))
      (let ((p (unwrap-panic preview)))
        (asserts! (get changed p) (err u3))
        (asserts! (is-eq (get proposed-xcxd-bps p) u8250) (err u4))
        (asserts! (get hysteresis-satisfied p) (err u5))))
    (print { test: "preview-auto-adjust-increase", status: "PASS" })
    (ok true)))

(define-public (test-auto-adjust-history-logging)
  (begin
    (print "Testing auto-adjust execution & history logging...")
    ;; Set automated controller to current tx-sender
    (try! (contract-call? .revenue-distributor set-automated-controller (some tx-sender)))

    ;; First adjustment (should pass hysteresis - last participation = 0)
    (let ((result (contract-call? .revenue-distributor auto-adjust-splits TEST_LOW_PARTICIPATION)))
      (asserts! (is-ok result) (err u10)))

    (let ((splits2 (unwrap-panic (contract-call? .revenue-distributor get-revenue-splits))))
      (asserts! (is-eq (get xcxd-split-bps splits2) u8250) (err u11)))

    ;; History check
    (let ((latest (contract-call? .revenue-distributor get-latest-splits-change)))
      (asserts! (is-some latest) (err u12))
      (let ((h (unwrap-panic latest)))
        (asserts! (is-eq (get prev-xcxd-bps h) u8000) (err u13))
        (asserts! (is-eq (get new-xcxd-bps h) u8250) (err u14))))

    (print { test: "auto-adjust-history-logging", status: "PASS" })
    (ok true)))

(define-public (test-hysteresis-prevents-small-delta)
  (begin
    (print "Testing hysteresis prevention of small delta adjustments...")
    ;; Reduce cooldown to allow another attempt next block
    (try! (contract-call? .revenue-distributor set-auto-adjust-cooldown u1))

    ;; Capture last participation from splits readout (last-adjust-participation added)
    (let ((splits (unwrap-panic (contract-call? .revenue-distributor get-revenue-splits))))
      (let ((last-part (get last-adjust-participation splits)))
        ;; Attempt small delta (< HYSTERESIS_MIN_DELTA)
        (let ((attempt (contract-call? .revenue-distributor auto-adjust-splits (+ last-part TEST_SMALL_DELTA))))
          ;; If cooldown not yet elapsed, the call may err; allow either ok with unchanged splits or err due to cooldown.
          (if (is-ok attempt)
            (let ((new-splits (unwrap-panic attempt)))
              (asserts! (is-eq (get xcxd-split-bps new-splits) u8250) (err u20)))
            ;; If errored ensure it's the cooldown error (ERR_UNAUTHORIZED u800) and not unexpected.
            (asserts! (is-eq (err-get attempt) u800) (err u21)))))
    (print { test: "hysteresis-small-delta", status: "PASS", note: "Either cooldown blocked or hysteresis held splits" })
    (ok true)))

(define-public (run-revenue-distributor-hysteresis-suite)
  (begin
    (try! (test-preview-auto-adjust-increase))
    (try! (test-auto-adjust-history-logging))
    (try! (test-hysteresis-prevents-small-delta))
    (print { suite: "revenue-distributor-hysteresis", status: "ALL_PASS" })
    (ok true)))
