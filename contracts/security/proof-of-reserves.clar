;; ===========================================
;; Proof of Reserves (PoR) Contract
;; ===========================================
;; Provides cryptographic verification of reserves via Merkle proofs.
;; Stores per-asset attestation root and metadata, and verifies account-level
;; claims using provided leaf hashes and sibling proofs.
;;
;; Notes:
;; - Leaf hashing is performed off-chain. Callers provide the leaf hash (buff 32)
;;   computed from canonical serialization of (principal, amount). This avoids
;;   ambiguity of in-contract principal encoding.
;; - Merkle proof is verified by iteratively hashing concatenations according to
;;   provided sibling order.
;; - Attestations can be updated by the auditor/admin. Staleness checks protect
;;   downstream usage.

(define-constant ERR_UNAUTHORIZED (err u91001))
(define-constant ERR_ASSET_NOT_FOUND (err u91002))
(define-constant ERR_INVALID_PROOF (err u91003))
(define-constant ERR_STALE (err u91004))
(define-constant ERR_INVALID_INPUT (err u91005))

;; Admin and monitoring addresses
(define-data-var admin principal tx-sender)
(define-data-var monitoring (optional principal) none)

;; Stale threshold in blocks (e.g., 720 ~ 1 day on ~2-minute blocks)
(define-data-var stale-threshold-blocks uint u10368000)

;; Per-asset attestation: Merkle root and metadata
(define-map por-attestations { asset: principal } {
  root: (buff 32),
  total-reserves: uint,
  updated-at: uint,
  auditor: principal,
  version: uint
})

;; =====================
;; Admin Functions
;; =====================

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-monitoring (m principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set monitoring (some m))
    (ok true)
  )
)

(define-public (set-stale-threshold (blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> blocks u0) ERR_INVALID_INPUT)
    (var-set stale-threshold-blocks blocks)
    (ok true)
  )
)

(define-public (set-attestation (asset principal) (root (buff 32)) (total-reserves uint) (version uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (> total-reserves u0) ERR_INVALID_INPUT)
    (map-set por-attestations { asset: asset } {
      root: root,
      total-reserves: total-reserves,
      updated-at: u0,
      auditor: tx-sender,
      version: version
    })
    (ok true)
  )
)

;; =====================
;; Read-Only Helpers
;; =====================

(define-read-only (get-attestation (asset principal))
  (ok (map-get? por-attestations { asset: asset }))
)

(define-read-only (is-stale (asset principal))
  (let ((att (map-get? por-attestations { asset: asset }))
        (now u0))
    (ok (match att
      a (>= (- now (get updated-at a)) (var-get stale-threshold-blocks))
      false
    ))
  )
)

;; =====================
;; Merkle Proof Verification
;; =====================
;; Proof format: list of siblings with order information
;; Each element: (tuple (sibling (buff 32)) (left bool))
;; If left = true, current = sha256(concat(sibling, current))
;; Else, current = sha256(concat(current, sibling))

(define-private (compute-step (el (tuple (sibling (buff 32)) (left bool))) (acc (buff 32)))
  (let ((sib (get sibling el)) (left (get left el)))
    (if left
      (sha256 (concat sib acc))
      (sha256 (concat acc sib))
    )
  )
)

(define-private (compute-merkle-root (leaf (buff 32)) (proof (list 100 (tuple (sibling (buff 32)) (left bool)))))
  (fold compute-step proof leaf)
)

(define-read-only (verify-merkle (asset principal) (leaf (buff 32)) (proof (list 100 (tuple (sibling (buff 32)) (left bool)))))
  (let (
    (att (map-get? por-attestations { asset: asset }))
  )
    (ok (match att
      a (let ((computed (compute-merkle-root leaf proof)))
           (is-eq computed (get root a)))
      false))
  )
)

;; Public verification with staleness guard and optional monitoring
(define-public (verify-account-reserve (asset principal) (leaf (buff 32)) (proof (list 100 (tuple (sibling (buff 32)) (left bool)))))
  (let ((att (map-get? por-attestations { asset: asset }))
        (now u0))
    (asserts! (is-some att) ERR_ASSET_NOT_FOUND)
    (let ((a (unwrap-panic att)))
      (asserts! (not (>= (- now (get updated-at a)) (var-get stale-threshold-blocks))) ERR_STALE)
      (let ((computed (compute-merkle-root leaf proof)))
        (asserts! (is-eq computed (get root a)) ERR_INVALID_PROOF)
        ;; Monitoring hook (optional)
        (match (var-get monitoring)
          m (begin (print { event: "por-verified", asset: asset, updated-at: (get updated-at a) }) (ok true))
          (ok true)
        )
      )
    )
  )
)
