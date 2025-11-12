;; ===========================================
;; MONITORING TRAIT
;; ===========================================
;; Interface for system monitoring and alerting
;;
;; This trait provides functions to log events, record metrics,
;; and trigger alerts based on predefined conditions.
;;
;; Example usage:
;;   (use-trait monitoring .monitoring-trait.monitoring-trait)
(define-trait monitoring-trait
  (
    ;; Log an event
    ;; @param event-name: name of the event
    ;; @param event-data: data associated with the event
    ;; @return (response bool uint): success flag and error code
    (log-event ((string-ascii 64) (buff 256)) (response bool uint))

    ;; Record a metric
    ;; @param metric-name: name of the metric
    ;; @param metric-value: value of the metric
    ;; @return (response bool uint): success flag and error code
    (record-metric ((string-ascii 64) uint) (response bool uint))

    ;; Trigger an alert
    ;; @param alert-name: name of the alert
    ;; @param alert-message: message for the alert
    ;; @return (response bool uint): success flag and error code
    (trigger-alert ((string-ascii 64) (string-ascii 256)) (response bool uint))

    ;; Get recent events
    ;; @param limit: maximum number of events to retrieve
    ;; @return (response (list 20 (tuple ...)) uint): list of events and error code
    (get-recent-events (uint) (response (list 20 (tuple (name (string-ascii 64)) (data (buff 256)) (timestamp uint))) uint))
  )
)
