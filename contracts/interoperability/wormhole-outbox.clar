;; wormhole-outbox.clar
;; Minimal Wormhole outbox adapter to record outbound intents for relayers.

(define-constant ERR_UNAUTHORIZED (err u93011))

;; Admin
(define-data-var admin principal tx-sender)

;; Intent id sequence
(define-data-var next-intent-id uint u1)

;; Outbound intents registry
(define-map intents uint {
  dest-chain: (string-ascii 16),
  dest-address: (buff 32),
  payload-size: uint,
  created-by: principal
})

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; Emit an outbound intent; relayers can pick this up
(define-public (emit-intent (dest-chain (string-ascii 16)) (dest-address (buff 32)) (payload (buff 1024)))
  (let ((id (var-get next-intent-id))
        (size (len payload)))
    (begin
      (map-set intents id {
        dest-chain: dest-chain,
        dest-address: dest-address,
        payload-size: size,
        created-by: tx-sender
      })
      (var-set next-intent-id (+ id u1))
      (print { event: "wormhole-outbox-intent", id: id, chain: dest-chain, size: size })
      (ok id)
    )
  )
)

;; Read-only
(define-read-only (get-intent (id uint))
  (map-get? intents id)
)
