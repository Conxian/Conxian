;; Predictive Scaling System Contract
;; Provides intelligent scaling predictions based on transaction patterns,
;; historical data analysis, and proactive resource allocation

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_PARAMS (err u400))
(define-constant ERR_PREDICTION_NOT_FOUND (err u404))
(define-constant ERR_MODEL_NOT_TRAINED (err u503))
(define-constant ERR_INSUFFICIENT_DATA (err u422))

;; Prediction confidence levels
(define-constant CONFIDENCE_LOW u0)
(define-constant CONFIDENCE_MEDIUM u1)
(define-constant CONFIDENCE_HIGH u2)

;; Scaling directions
(define-constant SCALE_DOWN u0)
(define-constant SCALE_MAINTAIN u1)
(define-constant SCALE_UP u2)

;; Time horizon for predictions
(define-constant HORIZON_SHORT u300)  ;; 5 minutes
(define-constant HORIZON_MEDIUM u1800) ;; 30 minutes
(define-constant HORIZON_LONG u3600)   ;; 1 hour

;; Configuration
(define-data-var contract-owner principal tx-sender)
(define-data-var prediction-enabled bool true)
(define-data-var min-confidence-threshold uint u1) ;; Minimum MEDIUM confidence
(define-data-var scaling-sensitivity uint u150)    ;; 150% threshold for scaling decisions

;; Historical transaction patterns
(define-map transaction-patterns
  { time-window: uint, pattern-id: uint }
  {
    avg-tps: uint,
    peak-tps: uint,
    transaction-count: uint,
    avg-gas-usage: uint,
    error-rate: uint,
    timestamp: uint
  }
)

;; Scaling predictions
(define-map scaling-predictions
  { prediction-id: (string-ascii 64) }
  {
    predicted-tps: uint,
    confidence-level: uint,
    scaling-recommendation: uint,
    target-capacity: uint,
    prediction-horizon: uint,
    created-at: uint,
    expires-at: uint,
    accuracy-score: uint
  }
)

;; Resource utilization metrics
(define-map resource-metrics
  { resource-type: (string-ascii 32), time-window: uint }
  {
    current-usage: uint,
    predicted-usage: uint,
    capacity-limit: uint,
    utilization-percentage: uint,
    trend-direction: uint
  }
)

;; Prediction model parameters
(define-map model-parameters
  { model-name: (string-ascii 64) }
  {
    learning-rate: uint,
    decay-factor: uint,
    window-size: uint,
    accuracy-threshold: uint,
    last-trained: uint,
    training-samples: uint
  }
)

;; Scaling actions history
(define-map scaling-actions
  { action-id: uint }
  {
    triggered-by-prediction: (string-ascii 64),
    scaling-decision: uint,
    previous-capacity: uint,
    new-capacity: uint,
    execution-time: uint,
    effectiveness-score: uint
  }
)

;; Global scaling statistics
(define-data-var total-predictions uint u0)
(define-data-var successful-predictions uint u0)
(define-data-var total-scaling-actions uint u0)
(define-data-var prediction-accuracy-score uint u0)

;; === OWNER FUNCTIONS ===

(define-public (only-owner-guard)
  (if (is-eq tx-sender (var-get contract-owner))
    (ok true)
    (err u401)))  ;; ERR_UNAUTHORIZED

(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (only-owner-guard))
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (configure-prediction-settings (enabled bool) (confidence-thresh uint) (sensitivity uint))
  (begin
    (try! (only-owner-guard))
    (asserts! (and (<= confidence-thresh CONFIDENCE_HIGH) (> sensitivity u100)) ERR_INVALID_PARAMS)
    (var-set prediction-enabled enabled)
    (ok true)))

;; === DATA COLLECTION ===

(define-public (record-transaction-pattern (time-window uint) (pattern-id uint) (tps uint) (peak-tps uint) (tx-count uint) (gas-usage uint) (error-rate uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (if (var-get prediction-enabled)
      (begin
        (map-set transaction-patterns
          { time-window: time-window, pattern-id: pattern-id }
          {
            avg-tps: tps,
            peak-tps: peak-tps,
            transaction-count: tx-count,
            avg-gas-usage: gas-usage,
            error-rate: error-rate,
            timestamp: current-time
          }
        )
        (ok true)
      )
      (ok false)
    )
  )
)

(define-public (update-resource-metrics (resource-type (string-ascii 32)) (current-usage uint) (predicted-usage uint) (capacity-limit uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (time-window (/ current-time u300)) ;; 5-minute windows
    (utilization (if (> capacity-limit u0)
                    (/ (* current-usage u100) capacity-limit)
                    u0))
    (trend (if (> predicted-usage current-usage) SCALE_UP
             (if (< predicted-usage current-usage) SCALE_DOWN SCALE_MAINTAIN)))
  )
    (map-set resource-metrics
      { resource-type: resource-type, time-window: time-window }
      {
        current-usage: current-usage,
        predicted-usage: predicted-usage,
        capacity-limit: capacity-limit,
        utilization-percentage: utilization,
        trend-direction: trend
      }
    )
    (ok true)
  )
)

;; === PREDICTION ENGINE ===

(define-public (generate-scaling-prediction (prediction-id (string-ascii 64)) (horizon uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    ;; Simplified prediction logic - in reality this would use ML models
    (predicted-tps (+ u1000 (* (/ horizon u300) u100))) ;; Simple linear prediction
    (confidence (if (>= horizon HORIZON_LONG) CONFIDENCE_HIGH
                  (if (>= horizon HORIZON_MEDIUM) CONFIDENCE_MEDIUM CONFIDENCE_LOW)))
    (scaling-rec (if (> predicted-tps u2000) SCALE_UP
                   (if (< predicted-tps u500) SCALE_DOWN SCALE_MAINTAIN)))
    (target-cap (+ predicted-tps (* predicted-tps u20 (/ u100)))) ;; 20% buffer
  )
    (if (var-get prediction-enabled)
      (begin
        (map-set scaling-predictions
          { prediction-id: prediction-id }
          {
            predicted-tps: predicted-tps,
            confidence-level: confidence,
            scaling-recommendation: scaling-rec,
            target-capacity: target-cap,
            prediction-horizon: horizon,
            created-at: current-time,
            expires-at: (+ current-time horizon),
            accuracy-score: u0 ;; Will be updated after validation
          }
        )
        (var-set total-predictions (+ (var-get total-predictions) u1))
        (ok scaling-rec)
      )
      (ok SCALE_MAINTAIN)
    )
  )
)

(define-public (validate-prediction-accuracy (prediction-id (string-ascii 64)) (actual-tps uint))
  (let (
    (prediction (unwrap! (map-get? scaling-predictions { prediction-id: prediction-id }) ERR_PREDICTION_NOT_FOUND))
    (predicted-tps (get predicted-tps prediction))
    (accuracy (if (> predicted-tps actual-tps)
                (- u100 (/ (* (- predicted-tps actual-tps) u100) predicted-tps))
                (- u100 (/ (* (- actual-tps predicted-tps) u100) actual-tps))))
  )
    ;; Update prediction with accuracy score
    (map-set scaling-predictions
      { prediction-id: prediction-id }
      (merge prediction { accuracy-score: accuracy })
    )
    
    ;; Update global accuracy metrics
    (if (>= accuracy u80) ;; Consider 80%+ as successful
      (var-set successful-predictions (+ (var-get successful-predictions) u1))
      true
    )
    
    ;; Update overall accuracy score
    (let (
      (total (var-get total-predictions))
      (successful (var-get successful-predictions))
    )
      (if (> total u0)
        (var-set prediction-accuracy-score (/ (* successful u100) total))
        (var-set prediction-accuracy-score u0)
      )
    )
    (ok accuracy)
  )
)

;; === SCALING ACTIONS ===

(define-public (execute-scaling-action (prediction-id (string-ascii 64)) (current-capacity uint))
  (begin
    (try! (only-owner-guard))
    (let (
      (prediction (unwrap! (map-get? scaling-predictions { prediction-id: prediction-id }) ERR_PREDICTION_NOT_FOUND))
      (action-id (var-get total-scaling-actions))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
      (asserts! (>= (get confidence-level prediction) (var-get min-confidence-threshold)) ERR_INSUFFICIENT_DATA)
      
      (map-set scaling-actions
        { action-id: action-id }
        {
          triggered-by-prediction: prediction-id,
          scaling-decision: (get scaling-recommendation prediction),
          previous-capacity: current-capacity,
          new-capacity: (get target-capacity prediction),
          execution-time: current-time,
          effectiveness-score: u0 ;; Will be updated later
        }
      )
      
      (var-set total-scaling-actions (+ (var-get total-scaling-actions) u1))
      (ok (get target-capacity prediction))
    )
  )
)

(define-public (update-scaling-effectiveness (action-id uint) (effectiveness-score uint))
  (begin
    (try! (only-owner-guard))
    (let (
      (action (unwrap! (map-get? scaling-actions { action-id: action-id }) ERR_PREDICTION_NOT_FOUND))
    )
      (map-set scaling-actions
        { action-id: action-id }
        (merge action { effectiveness-score: effectiveness-score })
      )
      (ok true)
    )
  )
)

;; === MODEL MANAGEMENT ===

(define-public (train-prediction-model (model-name (string-ascii 64)) (learning-rate uint) (window-size uint))
  (begin
    (try! (only-owner-guard))
    (let (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
      (map-set model-parameters
        { model-name: model-name }
        {
          learning-rate: learning-rate,
          decay-factor: u95, ;; 95% decay factor
          window-size: window-size,
          accuracy-threshold: u80,
          last-trained: current-time,
          training-samples: u100 ;; Simulate training samples
        }
      )
      (ok true)
    )
  )
)

;; === PROACTIVE SCALING ===

(define-public (trigger-proactive-scaling (resource-type (string-ascii 32)) (urgency-level uint))
  (begin
    (try! (only-owner-guard))
    ;; Generate immediate scaling prediction based on resource pressure
    (let (
      (prediction-id "proactive-scale")
      (horizon (if (>= urgency-level u2) HORIZON_SHORT HORIZON_MEDIUM))
    )
      (let ((prediction-result (unwrap-panic (generate-scaling-prediction prediction-id horizon))))
        prediction-result)
      (ok true)
    )
  )
)

;; === READ-ONLY FUNCTIONS ===

(define-read-only (get-owner)
  (var-get contract-owner)
)

(define-read-only (get-scaling-prediction (prediction-id (string-ascii 64)))
  (map-get? scaling-predictions { prediction-id: prediction-id })
)

(define-read-only (get-transaction-pattern (time-window uint) (pattern-id uint))
  (map-get? transaction-patterns { time-window: time-window, pattern-id: pattern-id })
)

(define-read-only (get-resource-metrics (resource-type (string-ascii 32)) (time-window uint))
  (map-get? resource-metrics { resource-type: resource-type, time-window: time-window })
)

(define-read-only (get-model-parameters (model-name (string-ascii 64)))
  (map-get? model-parameters { model-name: model-name })
)

(define-read-only (get-scaling-action (action-id uint))
  (map-get? scaling-actions { action-id: action-id })
)

(define-read-only (get-prediction-statistics)
  {
    total-predictions: (var-get total-predictions),
    successful-predictions: (var-get successful-predictions),
    total-scaling-actions: (var-get total-scaling-actions),
    prediction-accuracy-score: (var-get prediction-accuracy-score),
    prediction-enabled: (var-get prediction-enabled),
    min-confidence-threshold: (var-get min-confidence-threshold),
    scaling-sensitivity: (var-get scaling-sensitivity)
  }
)

(define-read-only (calculate-scaling-confidence (predicted-tps uint) (current-tps uint))
  (let (
    (difference (if (> predicted-tps current-tps)
                   (- predicted-tps current-tps)
                   (- current-tps predicted-tps)))
    (variance-percentage (if (> current-tps u0)
                          (/ (* difference u100) current-tps)
                          u100))
  )
    (if (<= variance-percentage u10) CONFIDENCE_HIGH
      (if (<= variance-percentage u25) CONFIDENCE_MEDIUM CONFIDENCE_LOW))
  )
)

(define-read-only (is-scaling-recommended (resource-type (string-ascii 32)))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (time-window (/ current-time u300))
    (metrics (map-get? resource-metrics { resource-type: resource-type, time-window: time-window }))
  )
    (match metrics
      some-metrics 
      (> (get utilization-percentage some-metrics) (var-get scaling-sensitivity))
      false
    )
  )
)

(define-read-only (get-system-scaling-status)
  (let (
    (total-actions (var-get total-scaling-actions))
    (accuracy (var-get prediction-accuracy-score))
  )
    {
      scaling-active: (var-get prediction-enabled),
      total-scaling-events: total-actions,
      prediction-accuracy: accuracy,
      system-health: (if (and (var-get prediction-enabled) (>= accuracy u75)) "healthy" "degraded")
    }
  )
)




