;; conxian-operations-engine.clar
;; Automated operations & resilience governance seat for the Conxian Protocol.
;; Configuration, read-only views, and a first safe execute-vote implementation.

(define-constant ERR_UNAUTHORIZED (err u7000))

;; --- Core Configuration ---

(define-data-var contract-owner principal tx-sender)
(define-data-var proposal-engine principal .proposal-engine)
(define-data-var proposal-registry principal .proposal-registry)
(define-data-var governance-token principal .governance-token)
(define-data-var governance-voting principal .governance-voting)
(define-data-var governance-nft-contract (optional principal) none)
(define-data-var operations-council-token-id (optional uint) none)
(define-data-var metrics-registry (optional principal) none)

(define-map auto-support-proposals uint bool)
(define-map auto-abstain-proposals uint bool)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Public Read-Only Views ---

(define-read-only (get-config)
  {
    contract-owner: (var-get contract-owner),
    proposal-engine: (var-get proposal-engine),
    proposal-registry: (var-get proposal-registry),
    governance-token: (var-get governance-token),
    governance-voting: (var-get governance-voting),
    governance-nft-contract: (var-get governance-nft-contract),
    operations-council-token-id: (var-get operations-council-token-id),
    metrics-registry: (var-get metrics-registry)
  }
)

;; Placeholder policy fields. These will be expanded into structured
;; parameters as the engine is wired to real risk/treasury thresholds.
(define-read-only (get-policy)
  {
    legex-policy: u0,
    devex-policy: u0,
    opex-policy: u0,
    capex-policy: u0,
    invex-policy: u0
  }
)

;; --- Operations Status ---

(define-read-only (get-operations-status)
  (let (
        (health (contract-call? .token-system-coordinator get-system-health))
        (circuit-result (contract-call? .circuit-breaker is-circuit-open))
       )
    (let ((circuit-open (if (is-ok circuit-result)
                            (unwrap-panic circuit-result)
                            false)))
      {
        is-paused: (get is-paused health),
        emergency-mode: (get emergency-mode health),
        total-registered-tokens: (get total-registered-tokens health),
        total-users: (get total-users health),
        coordinator-version: (get coordinator-version health),
        circuit-open: circuit-open,
      }
    )
  )
)

;; Check that an operations council NFT seat is configured. Full ownership
;; verification would require a static NFT contract; for now we require both
;; contract and token-id to be set before allowing automated votes.
(define-private (has-operations-seat)
  (and (is-some (var-get governance-nft-contract))
       (is-some (var-get operations-council-token-id)))
)

;; --- Evaluation & Voting ---

(define-read-only (evaluate-proposal (proposal-id uint))
  (let ((ops (get-operations-status)))
    (if (or (get is-paused ops) (get emergency-mode ops) (get circuit-open ops))
      (ok {
        support: false,
        abstain: true,
        reason-code: u1   ;; SYSTEM_STRESSED
      })
      (let (
            (support-flag (default-to false (map-get? auto-support-proposals proposal-id)))
            (abstain-flag (default-to false (map-get? auto-abstain-proposals proposal-id)))
           )
        (if support-flag
          (ok {
            support: true,
            abstain: false,
            reason-code: u2
          })
          (if abstain-flag
            (ok {
              support: false,
              abstain: true,
              reason-code: u3
            })
            (ok {
              support: false,
              abstain: true,
              reason-code: u0
            })
          )
        )
      )
    )
  )
)

;; First safe execute-vote: only forwards a vote when the system is healthy.
;; The caller supplies support and votes-cast; the engine enforces ops guardrails.
(define-public (execute-vote (proposal-id uint) (support bool) (votes-cast uint))
  (let ((ops (get-operations-status)))
    (if (or (get is-paused ops) (get emergency-mode ops) (get circuit-open ops))
      (ok false)
      (if (not (has-operations-seat))
        (ok false)
        (as-contract (contract-call? .proposal-engine vote proposal-id support votes-cast))
      ))
  )
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-governance-contracts
    (new-proposal-engine principal)
    (new-proposal-registry principal)
    (new-governance-token principal)
    (new-governance-voting principal)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set proposal-engine new-proposal-engine)
    (var-set proposal-registry new-proposal-registry)
    (var-set governance-token new-governance-token)
    (var-set governance-voting new-governance-voting)
    (ok true)
  )
)

(define-public (set-governance-nft
    (nft-contract principal)
    (token-id uint)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set governance-nft-contract (some nft-contract))
    (var-set operations-council-token-id (some token-id))
    (ok true)
  )
)

(define-public (set-metrics-registry (registry principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set metrics-registry (some registry))
    (ok true)
  )
)

(define-public (set-auto-support-proposal (proposal-id uint) (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (if enabled
      (map-set auto-support-proposals proposal-id true)
      (map-delete auto-support-proposals proposal-id)
    )
    (ok true)
  )
)

(define-public (set-auto-abstain-proposal (proposal-id uint) (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (if enabled
      (map-set auto-abstain-proposals proposal-id true)
      (map-delete auto-abstain-proposals proposal-id)
    )
    (ok true)
  )
)
