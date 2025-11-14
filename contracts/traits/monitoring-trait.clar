;; ===========================================
;; MONITORING TRAIT
;; ===========================================
;; @desc Interface for system monitoring and alerting.
;; This trait provides functions to log events, record metrics,
;; and trigger alerts based on predefined conditions.
;;
;; @example
;; (use-trait monitoring .monitoring-trait.monitoring-trait)
(define-trait monitoring-trait
  (
    ;; @desc Log an event.
    ;; @param event-name: The name of the event.
    ;; @param event-data: The data associated with the event.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (log-event ((string-ascii 64) (buff 256)) (response bool uint))

    ;; @desc Record a metric.
    ;; @param metric-name: The name of the metric.
    ;; @param metric-value: The value of the metric.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (record-metric ((string-ascii 64) uint) (response bool uint))

    ;; @desc Trigger an alert.
    ;; @param alert-name: The name of the alert.
    ;; @param alert-message: The message for the alert.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (trigger-alert ((string-ascii 64) (string-ascii 256)) (response bool uint))

    ;; @desc Get recent events.
    ;; @param limit: The maximum number of events to retrieve.
    ;; @returns (response (list 20 (tuple ...)) uint): A list of the recent events, or an error code.
    (get-recent-events (uint) (response (list 20 (tuple (name (string-ascii 64)) (data (buff 256)) (timestamp uint))) uint))
  )
)
