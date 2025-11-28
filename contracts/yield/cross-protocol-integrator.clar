;; cross-protocol-integrator.clar
;; Integrates with other DeFi protocols.

(define-constant ERR_UNAUTHORIZED (err u10000))
(define-constant ERR_PROTOCOL_NOT_FOUND (err u10001))

(define-map protocols { protocol-id: uint } {
  name: (string-ascii 32),
  contract: principal,
  is-active: bool
})

(define-public (add-protocol (name (string-ascii 32)) (contract principal))
  (begin
    (asserts! (is-eq tx-sender .admin) ERR_UNAUTHORIZED)
    (let ((protocol-id (var-get next-protocol-id)))
      (map-set protocols { protocol-id: protocol-id } { name: name, contract: contract, is-active: true })
      (var-set next-protocol-id (+ protocol-id u1))
    )
    (ok true)
  )
)

(define-public (set-protocol-status (protocol-id uint) (is-active bool))
  (begin
    (asserts! (is-eq tx-sender .admin) ERR_UNAUTHORIZED)
    (let ((protocol (unwrap! (map-get? protocols { protocol-id: protocol-id }) ERR_PROTOCOL_NOT_FOUND)))
      (map-set protocols { protocol-id: protocol-id } (merge protocol { is-active: is-active }))
    )
    (ok true)
  )
)

(define-read-only (get-apy (protocol-id uint) (asset principal))
  ;; In a real implementation, this would call out to the protocol's contract to get the current APY for the given asset.
  ;; For now, we'll just return a placeholder.
  (ok u500)
)
