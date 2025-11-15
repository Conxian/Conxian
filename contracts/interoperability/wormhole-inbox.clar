;; wormhole-inbox.clar
;; Minimal Wormhole inbox adapter with idempotency and guardian-set tracking.

(define-constant ERR_UNAUTHORIZED (err u93001))
(define-constant ERR_REPLAY (err u93002))
(define-constant ERR_INVALID_GUARDIAN_SET (err u93003))

;; Admin and guardian-set tracking
(define-data-var admin principal tx-sender)
(define-data-var guardian-set-index uint u0)

;; Processed message ids for idempotency (32-byte ids)
(define-map processed (buff 32) bool)

;; =====================
;; Admin functions
;; =====================

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-guardian-set-index (index uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set guardian-set-index index)
    (ok true)
  )
)

;; =====================
;; Inbox receive function
;; =====================
;; Accepts a relayed message with expected guardian-set index and payload
;; Ensures idempotency via 'processed' map and logs an event

(define-public (receive-message (msg-id (buff 32)) (expected-guardian-index uint) (payload (buff 1024)))
  (begin
    (asserts! (is-eq expected-guardian-index (var-get guardian-set-index)) ERR_INVALID_GUARDIAN_SET)
    (asserts! (is-none (map-get? processed msg-id)) ERR_REPLAY)
    (map-set processed msg-id true)
    (print { event: "wormhole-inbox-received", id: msg-id, guardian: expected-guardian-index, size: (len payload) })
    (ok true)
  )
)

;; Read-only helpers
(define-read-only (is-processed (msg-id (buff 32)))
  (default-to false (map-get? processed msg-id))
)
