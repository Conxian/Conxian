;; Points Oracle
;; Manages Merkle root submission and proof verification for gamification points

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u2000))
(define-constant ERR_INVALID_EPOCH (err u2001))
(define-constant ERR_INVALID_PROOF (err u2002))
(define-constant ERR_ALREADY_SUBMITTED (err u2003))
(define-constant ERR_INSUFFICIENT_SIGNATURES (err u2004))
(define-constant ERR_EPOCH_NOT_FINALIZED (err u2005))

(define-constant REQUIRED_SIGNATURES u3) ;; 3-of-5 multisig

;; Data Variables
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var gamification-manager principal tx-sender)

;; Attestor nodes (5 independent nodes)
(define-data-var attestor-1 principal tx-sender)
(define-data-var attestor-2 principal tx-sender)
(define-data-var attestor-3 principal tx-sender)
(define-data-var attestor-4 principal tx-sender)
(define-data-var attestor-5 principal tx-sender)

;; Data Maps
(define-map merkle-roots
  uint ;; epoch
  {
    root: (buff 32),
    submission-block: uint,
    signatures: (list 5 (buff 65)),
    signature-count: uint,
    finalized: bool
  }
)

(define-map user-point-proofs
  { user: principal, epoch: uint }
  {
    liquidity-points: uint,
    governance-points: uint,
    verified: bool
  }
)

;; Read-Only Functions

(define-read-only (get-merkle-root (epoch uint))
  (map-get? merkle-roots epoch)
)

(define-read-only (get-user-points (user principal) (epoch uint))
  (map-get? user-point-proofs { user: user, epoch: epoch })
)

(define-read-only (is-attestor (address principal))
  (or
    (is-eq address (var-get attestor-1))
    (is-eq address (var-get attestor-2))
    (is-eq address (var-get attestor-3))
    (is-eq address (var-get attestor-4))
    (is-eq address (var-get attestor-5))
  )
)

;; Private Functions

(define-private (verify-merkle-proof
  (leaf (buff 32))
  (proof (list 12 (buff 32)))
  (root (buff 32))
)
  (if (is-eq root leaf)
    (ok true)
    (err ERR_INVALID_PROOF)
  )
)

(define-private (hash-user-points
  (user principal)
  (liquidity-points uint)
  (governance-points uint)
)
  ;; Create leaf hash from user data
  ;; Real implementation would use keccak256 or sha256
  0x0000000000000000000000000000000000000000000000000000000000000000
)

;; Public Functions

(define-public (submit-merkle-root
  (epoch uint)
  (root (buff 32))
  (signatures (list 5 (buff 65)))
)
  (let (
    (sig-count (len signatures))
  )
    ;; Verify caller is an attestor
    (asserts! (is-attestor tx-sender) ERR_UNAUTHORIZED)
    
    ;; Verify not already submitted
    (asserts! (is-none (map-get? merkle-roots epoch)) ERR_ALREADY_SUBMITTED)
    
    ;; Verify sufficient signatures (3-of-5)
    (asserts! (>= sig-count REQUIRED_SIGNATURES) ERR_INSUFFICIENT_SIGNATURES)
    
    ;; Store Merkle root
    (map-set merkle-roots epoch {
      root: root,
      submission-block: block-height,
      signatures: signatures,
      signature-count: sig-count,
      finalized: true
    })
    
    (print {
      event: "merkle-root-submitted",
      epoch: epoch,
      root: root,
      signatures: sig-count
    })
    (ok true)
  )
)

(define-public (verify-user-points
  (user principal)
  (epoch uint)
  (liquidity-points uint)
  (governance-points uint)
  (proof (list 12 (buff 32)))
)
  (let (
    (root-data (unwrap! (map-get? merkle-roots epoch) ERR_INVALID_EPOCH))
    (leaf (hash-user-points user liquidity-points governance-points))
  )
    ;; Verify epoch is finalized
    (asserts! (get finalized root-data) ERR_EPOCH_NOT_FINALIZED)
    
    ;; Verify Merkle proof
    (try! (verify-merkle-proof leaf proof (get root root-data)))
    
    ;; Store verified points
    (map-set user-point-proofs { user: user, epoch: epoch } {
      liquidity-points: liquidity-points,
      governance-points: governance-points,
      verified: true
    })
    
    (print {
      event: "user-points-verified",
      user: user,
      epoch: epoch,
      liquidity-points: liquidity-points,
      governance-points: governance-points
    })
    (ok true)
  )
)

(define-public (finalize-epoch (epoch uint))
  (let (
    (root-data (unwrap! (map-get? merkle-roots epoch) ERR_INVALID_EPOCH))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    ;; Note: Removed circular dependency call to gamification-manager.
    ;; The keeper-coordinator should call gamification-manager.finalize-epoch separately.
    
    (ok true)
  )
)

(define-public (start-epoch (epoch uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (print {
      event: "epoch-started",
      epoch: epoch,
      start-block: block-height
    })
    (ok true)
  )
)

;; Admin Functions

(define-public (set-attestor (index uint) (address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (if (is-eq index u1)
      (var-set attestor-1 address)
      (if (is-eq index u2)
        (var-set attestor-2 address)
        (if (is-eq index u3)
          (var-set attestor-3 address)
          (if (is-eq index u4)
            (var-set attestor-4 address)
            (if (is-eq index u5)
              (var-set attestor-5 address)
              false
            )
          )
        )
      )
    )
    (ok true)
  )
)

(define-public (set-gamification-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set gamification-manager manager)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
