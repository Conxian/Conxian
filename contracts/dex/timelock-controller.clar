;; Timelock Controller
;; Implements the time-delayed execution functionality specified in AIP-7

(use-trait access-control-trait .access-control-trait)
(use-trait standard-constants-trait .standard-constants-trait)

(define-constant MIN_DELAY u86400)  ;; 24 hours in seconds
(define-constant MAX_DELAY u2592000)  ;; 30 days in seconds

(define-data-var admin principal tx-sender)
(define-data-var minDelay uint MIN_DELAY)
(define-data-var operations (list {id: uint, target: principal, value: uint, data: (buff 1024), predecessor: (optional uint), delay: uint} ) (list))
(define-data-var operationIds (list uint) (list))
(define-data-var operationStatus (map uint bool) (map))

;; Operation status
(define-constant OP_UNSET 0x00)
(define-constant OP_PENDING 0x01)
(define-constant OP_DONE 0x02)
(define-constant OP_CANCELED 0x03)

(impl-trait .access-control-trait)

;; ===== Core Functions =====

(define-public (schedule 
    (target principal) 
    (value uint) 
    (data (buff 1024)) 
    (predecessor (optional uint)) 
    (delay uint)
    (description (string-utf8 500))
  )
  (let (
      (caller tx-sender)
      (current-block block-height)
      (operation-id (+ (var-get currentId) u1))
      (timestamp (+ current-block delay))
    )
    ;; Input validation
    (asserts! (>= delay (var-get minDelay)) (err u1001))  ;; ERR_DELAY_TOO_SHORT
    (asserts! (<= delay MAX_DELAY) (err u1002))  ;; ERR_DELAY_TOO_LONG
    
    ;; Create operation
    (var-set operations (append (var-get operations) (list {
      id: operation-id,
      target: target,
      value: value,
      data: data,
      predecessor: predecessor,
      delay: delay,
      timestamp: timestamp,
      description: description,
      proposer: caller,
      approvals: (list),
      status: OP_PENDING
    })))
    
    ;; Update operation IDs
    (var-set operationIds (append (var-get operationIds) (list operation-id)))
    
    ;; Update status
    (map-set operationStatus operation-id OP_PENDING)
    
    ;; Emit event
    (print {
      event: "operation-scheduled",
      operation-id: operation-id,
      target: target,
      timestamp: timestamp,
      description: description
    })
    
    (ok operation-id)
  )
)

(define-public (execute (operation-id uint))
  (let (
      (operation (unwrap! (get-operation operation-id) (err u1003)))  ;; ERR_OPERATION_NOT_FOUND
      (current-time block-height)
    )
    ;; Check operation status
    (asserts! (is-eq (get status operation) OP_PENDING) (err u1004))  ;; ERR_OPERATION_NOT_PENDING
    
    ;; Check timestamp
    (asserts! (>= current-time (get timestamp operation)) (err u1005))  ;; ERR_OPERATION_NOT_READY
    
    ;; Check predecessor if exists
    (match (get predecessor operation) 
      p (
        (asserts! (unwrap! (is-operation-done p) (err u1006)) (err u1007))  ;; ERR_PREDECESSOR_NOT_DONE
      )
      (ok true)
    )
    
    ;; Mark as done before execution to prevent reentrancy
    (map-set operationStatus operation-id OP_DONE)
    
    ;; Execute the operation
    (let ((result (contract-call? 
      (get target operation) 
      (get value operation) 
      (get data operation)
    )))
      (match result
        (ok success) (ok success)
        (err error) (begin
          ;; Revert status on failure
          (map-set operationStatus operation-id OP_PENDING)
          (err error)
        )
      )
    )
  )
)

(define-public (cancel (operation-id uint))
  (let (
      (operation (unwrap! (get-operation operation-id) (err u1003)))  ;; ERR_OPERATION_NOT_FOUND
    )
    ;; Only admin or proposer can cancel
    (asserts! (or 
      (is-eq tx-sender (var-get admin))
      (is-eq tx-sender (get proposer operation))
    ) (err u1008))  ;; ERR_UNAUTHORIZED
    
    ;; Can only cancel pending operations
    (asserts! (is-eq (get status operation) OP_PENDING) (err u1009))  ;; ERR_CANNOT_CANCEL
    
    ;; Update status
    (map-set operationStatus operation-id OP_CANCELED)
    
    ;; Emit event
    (print {
      event: "operation-canceled",
      operation-id: operation-id,
      by: tx-sender
    })
    
    (ok true)
  )
)

;; ===== View Functions =====

(define-read-only (get-min-delay)
  (ok (var-get minDelay))
)

(define-read-only (get-operation (operation-id uint))
  (let ((operation (filter (
    lambda ((op {id: uint, target: principal, value: uint, data: (buff 1024), predecessor: (optional uint), delay: uint})) 
    (is-eq (get id op) operation-id)
  ) (var-get operations))))
    (match operation
      (list op) (ok op)
      (err e) (err u1003)  ;; ERR_OPERATION_NOT_FOUND
    )
  )
)

(define-read-only (is-operation-pending (operation-id uint))
  (ok (is-eq (unwrap! (map-get? operationStatus operation-id) OP_UNSET) OP_PENDING))
)

(define-read-only (is-operation-done (operation-id uint))
  (ok (is-eq (unwrap! (map-get? operationStatus operation-id) OP_UNSET) OP_DONE))
)

;; ===== Admin Functions =====

(define-public (update-min-delay (new-delay uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1008))  ;; ERR_UNAUTHORIZED
    (asserts! (>= new-delay MIN_DELAY) (err u1001))  ;; ERR_DELAY_TOO_SHORT
    (asserts! (<= new-delay MAX_DELAY) (err u1002))  ;; ERR_DELAY_TOO_LONG
    
    (var-set minDelay new-delay)
    (ok true)
  )
)

;; ===== Helper Functions =====

(define-private (get-operation-index (operation-id uint))
  (let ((find-index (lambda ((op {id: uint, target: principal, value: uint, data: (buff 1024), predecessor: (optional uint), delay: uint}) (i uint))
    (if (is-eq (get id op) operation-id)
      (some i)
      none
    )
  )))
    (fold find-index (var-get operations) 0)
  )
)
