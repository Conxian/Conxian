;; wormhole-handlers.clar
;; Minimal governance and PoR handler stubs for interop testing.

(define-constant ERR_UNAUTHORIZED (err u93021))

(define-data-var admin principal tx-sender)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; Governance handler: accept payload and emit event
(define-public (handle-governance (payload (buff 1024)))
  (begin
    (print { event: "wormhole-governance-handled", size: (len payload), by: tx-sender })
    (ok true)
  )
)

;; PoR attestation handler: accept asset and attestation hash, emit event
(define-public (handle-por-attestation (asset (buff 32)) (attestation (buff 32)))
  (begin
    (print { event: "wormhole-por-handled", asset: asset, att: attestation })
    (ok true)
  )
)
