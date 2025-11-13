;; ===========================================
;; DIMENSIONAL TRAITS MODULE
;; ===========================================
;; Multi-dimensional DeFi specific traits
;; Optimized for complex position management

;; ===========================================
;; DIMENSIONAL TRAIT
;; ===========================================
(define-trait dimensional-trait
  (
    (get-position (uint) (response (optional {
      owner: principal,
      asset: principal,
      collateral: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      is-long: bool
    }) uint))
    (close-position (uint uint) (response bool uint))
    (get-protocol-stats () (response {
      total-positions: uint,
      total-volume: uint,
      total-value-locked: uint
    } uint))
  )
)

;; ===========================================
;; DIMENSIONAL REGISTRY TRAIT
;; ===========================================
(define-trait dim-registry-trait
  (
    (register-node (principal {type: (string-ascii 32), metadata: (optional (string-utf8 256))}) (response uint uint))
    (get-node (uint) (response (optional {
      principal: principal,
      type: (string-ascii 32),
      metadata: (optional (string-utf8 256)),
      active: bool
    }) uint))
    (update-node-status (uint bool) (response bool uint))
  )
)
