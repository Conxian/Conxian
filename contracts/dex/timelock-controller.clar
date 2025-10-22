;; Timelock Controller
;; Implements the time-delayed execution functionality specified in AIP-7

;; Constants
(define-constant MIN_DELAY u86400)  ;; 24 hours in seconds
(define-constant MAX_DELAY u2592000)  ;; 30 days in seconds

;; Operation status
(define-constant OP_UNSET u0)
(define-constant OP_PENDING u1)
(define-constant OP_DONE u2)
(define-constant OP_CANCELED u3)

;; Error codes
(define-constant ERR_DELAY_TOO_SHORT (err u1001))
(define-constant ERR_DELAY_TOO_LONG (err u1002))
(define-constant ERR_OPERATION_NOT_FOUND (err u1003))
(define-constant ERR_OPERATION_NOT_PENDING (err u1004))
(define-constant ERR_OPERATION_NOT_READY (err u1005))
(define-constant ERR_PREDECESSOR_NOT_FOUND (err u1006))
(define-constant ERR_PREDECESSOR_NOT_DONE (err u1007))
(define-constant ERR_UNAUTHORIZED (err u1008))
(define-constant ERR_CANNOT_CANCEL (err u1009))
(define-constant ERR_EXECUTION_FAILED (err u1010))

;; Data variables
(define-data-var admin principal tx-sender)
(define-data-var minDelay uint MIN_DELAY)
(define-data-var currentId uint u0)

;; Data maps
(define-map operations uint {
  target: principal,
  value: uint,
  data: (buff 1024),
  predecessor: (optional uint),
  timestamp: uint,
  description: (string-utf8 500),
  proposer: principal,
  status: uint
})

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
    (asserts! (>= delay (var-get minDelay)) ERR_DELAY_TOO_SHORT)
    (asserts! (<= delay MAX_DELAY) ERR_DELAY_TOO_LONG)
    
    ;; Create operation
    (map-set operations operation-id {
      target: target,
      value: value,
      data: data,
      predecessor: predecessor,
      timestamp: timestamp,
      description: description,
      proposer: caller,
      status: OP_PENDING
    })
    
    ;; Update current ID
    (var-set currentId operation-id)
    
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
      (operation (unwrap! (map-get? operations operation-id) ERR_OPERATION_NOT_FOUND))
      (current-time block-height)
    )
    ;; Check operation status
    (asserts! (is-eq (get status operation) OP_PENDING) ERR_OPERATION_NOT_PENDING)
    
    ;; Check timestamp
    (asserts! (>= current-time (get timestamp operation)) ERR_OPERATION_NOT_READY)
    
    ;; Check predecessor if exists
    (match (get predecessor operation)
      pred-id (asserts! (unwrap! (is-operation-done pred-id) ERR_PREDECESSOR_NOT_FOUND) ERR_PREDECESSOR_NOT_DONE)
      true
    )
    
    ;; Mark as done before execution to prevent reentrancy
    (map-set operations operation-id (merge operation { status: OP_DONE }))
    
    ;; Emit event
    (print {
      event: "operation-executed",
      operation-id: operation-id,
      target: (get target operation)
    })
    
    (ok true)
  )
)

(define-public (cancel (operation-id uint))
  (let (
      (operation (unwrap! (map-get? operations operation-id) ERR_OPERATION_NOT_FOUND))
    )
    ;; Only admin or proposer can cancel
    (asserts! (or 
      (is-eq tx-sender (var-get admin))
      (is-eq tx-sender (get proposer operation))
    ) ERR_UNAUTHORIZED)
    
    ;; Can only cancel pending operations
    (asserts! (is-eq (get status operation) OP_PENDING) ERR_CANNOT_CANCEL)
    
    ;; Update status
    (map-set operations operation-id (merge operation { status: OP_CANCELED }))
    
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
  (ok (unwrap! (map-get? operations operation-id) ERR_OPERATION_NOT_FOUND))
)

(define-read-only (is-operation-pending (operation-id uint))
  (match (map-get? operations operation-id)
    operation (ok (is-eq (get status operation) OP_PENDING))
    (ok false)
  )
)

(define-read-only (is-operation-done (operation-id uint))
  (match (map-get? operations operation-id)
    operation (ok (is-eq (get status operation) OP_DONE))
    (ok false)
  )
)

(define-read-only (is-operation-canceled (operation-id uint))
  (match (map-get? operations operation-id)
    operation (ok (is-eq (get status operation) OP_CANCELED))
    (ok false)
  )
)

(define-read-only (get-operation-status (operation-id uint))
  (match (map-get? operations operation-id)
    operation (ok (get status operation))
    (ok OP_UNSET)
  )
)

;; ===== Admin Functions =====

(define-public (update-min-delay (new-delay uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (>= new-delay MIN_DELAY) ERR_DELAY_TOO_SHORT)
    (asserts! (<= new-delay MAX_DELAY) ERR_DELAY_TOO_LONG)
    
    (var-set minDelay new-delay)
    
    (print {
      event: "min-delay-updated",
      old-delay: (var-get minDelay),
      new-delay: new-delay
    })
    
    (ok true)
  )
)

(define-public (update-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    
    (var-set admin new-admin)
    
    (print {
      event: "admin-updated",
      old-admin: tx-sender,
      new-admin: new-admin
    })
    
    (ok true)
  )
)

(define-read-only (get-admin)
  (ok (var-get admin))
)