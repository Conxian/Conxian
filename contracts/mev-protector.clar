;; mev-protector.clar

;; Implements MEV protection mechanisms

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_COMMITMENT (err u101))
(define-constant ERR_REVEAL_PERIOD_ENDED (err u102))
(define-constant ERR_COMMITMENT_NOT_FOUND (err u103))
(define-constant ERR_INVALID_REVEAL (err u104))
(define-constant ERR_BATCH_NOT_READY (err u105))
(define-constant ERR_SANDWICH_DETECTED (err u106))
(define-constant ERR_COMMITMENT_EXPIRED (err u107))
(define-constant ERR_ALREADY_REVEALED (err u108))

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var next-batch-id uint u0)
(define-data-var next-commitment-id uint u0)
(define-data-var commit-period-blocks uint u10)
(define-data-var reveal-period-blocks uint u10)

;; ===== Data Maps =====
(define-map commitments 
  {commitment-id: uint} 
  {
    hash: (buff 32),
    sender: principal,
    start-block: uint,
    revealed: bool
  })

(define-map batch-orders 
  {batch-id: uint, order-index: uint} 
  {
    sender: principal,
    payload: (buff 128),
    commitment-id: uint
  })

(define-map batch-metadata
  {batch-id: uint}
  {
    order-count: uint,
    start-block: uint,
    executed: bool
  })

;; ===== Private Functions =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (get-batch-order-count (batch-id uint))
  (default-to u0 
    (get order-count (map-get? batch-metadata {batch-id: batch-id}))))

(define-private (increment-batch-order-count (batch-id uint))
  (let ((current-count (get-batch-order-count batch-id)))
    (map-set batch-metadata {batch-id: batch-id}
      (merge 
        (default-to 
          {order-count: u0, start-block: block-height, executed: false}
          (map-get? batch-metadata {batch-id: batch-id}))
        {order-count: (+ current-count u1)}))
    (+ current-count u1)))

;; ===== Public Functions =====
(define-public (commit-order (commitment (buff 32)))
  (let ((id (var-get next-commitment-id)))
    (map-set commitments {commitment-id: id} {
      hash: commitment,
      sender: tx-sender,
      start-block: block-height,
      revealed: false
    })
    (var-set next-commitment-id (+ id u1))
    (ok id)))

(define-public (reveal-order (commitment-id uint) (payload (buff 128)))
  (let ((commitment-data (unwrap! (map-get? commitments {commitment-id: commitment-id}) 
                                   ERR_COMMITMENT_NOT_FOUND)))
    (let ((start-block (get start-block commitment-data))
          (sender (get sender commitment-data))
          (revealed (get revealed commitment-data))
          (commit-end (+ start-block (var-get commit-period-blocks)))
          (reveal-end (+ commit-end (var-get reveal-period-blocks))))
      
      ;; Validate reveal conditions
      (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
      (asserts! (not revealed) ERR_ALREADY_REVEALED)
      (asserts! (>= block-height commit-end) ERR_REVEAL_PERIOD_ENDED)
      (asserts! (< block-height reveal-end) ERR_COMMITMENT_EXPIRED)
      
      ;; Verify commitment hash
      (asserts! (is-eq (sha256 payload) (get hash commitment-data)) ERR_INVALID_REVEAL)
      
      ;; Mark as revealed
      (map-set commitments {commitment-id: commitment-id}
        (merge commitment-data {revealed: true}))
      
      ;; Add to current batch
      (let ((batch-id (calculate-current-batch-id))
            (order-index (increment-batch-order-count batch-id)))
        (map-set batch-orders {
          batch-id: batch-id,
          order-index: (- order-index u1)
        } {
          sender: tx-sender,
          payload: payload,
          commitment-id: commitment-id
        })
        (ok batch-id)))))

(define-public (execute-batch (batch-id uint))
  (begin
    (try! (check-is-owner))
    (asserts! (is-batch-ready-internal batch-id) ERR_BATCH_NOT_READY)
    
    (let ((metadata (unwrap! (map-get? batch-metadata {batch-id: batch-id})
                              ERR_BATCH_NOT_READY)))
      (asserts! (not (get executed metadata)) ERR_BATCH_NOT_READY)
      
      ;; Mark batch as executed
      (map-set batch-metadata {batch-id: batch-id}
        (merge metadata {executed: true}))
      
      (ok true))))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-commit-period (blocks uint))
  (begin
    (try! (check-is-owner))
    (var-set commit-period-blocks blocks)
    (ok true)))

(define-public (set-reveal-period (blocks uint))
  (begin
    (try! (check-is-owner))
    (var-set reveal-period-blocks blocks)
    (ok true)))

;; ===== Read-Only Functions =====
(define-read-only (calculate-current-batch-id)
  (let ((total-period (+ (var-get commit-period-blocks) 
                         (var-get reveal-period-blocks))))
    (/ block-height total-period)))

(define-read-only (get-current-batch-id)
  (ok (calculate-current-batch-id)))

(define-read-only (is-batch-ready-internal (batch-id uint))
  (let ((total-period (+ (var-get commit-period-blocks) 
                         (var-get reveal-period-blocks)))
        (batch-end (* (+ batch-id u1) total-period)))
    (and (>= block-height batch-end)
         (is-some (map-get? batch-metadata {batch-id: batch-id})))))

(define-read-only (is-batch-ready (batch-id uint))
  (ok (is-batch-ready-internal batch-id)))

(define-read-only (get-batch-info (batch-id uint))
  (ok (map-get? batch-metadata {batch-id: batch-id})))

(define-read-only (get-commitment (commitment-id uint))
  (ok (map-get? commitments {commitment-id: commitment-id})))

(define-read-only (get-batch-order (batch-id uint) (order-index uint))
  (ok (map-get? batch-orders {batch-id: batch-id, order-index: order-index})))

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner)))

(define-read-only (get-periods)
  (ok {
    commit-period: (var-get commit-period-blocks),
    reveal-period: (var-get reveal-period-blocks)
  }))