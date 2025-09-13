;; Conxian DEX Factory - Pool creation and registry with enhanced tokenomics integration
;; Implements access-control-trait and integrates with protocol monitoring

(use-trait access-control-trait traits.access-control-trait)
(use-trait sip10 traits.sip-010-trait)

(impl-trait access-control-trait)

;; ===== Error Codes =====
;; Access Control (1000-1099)
(define-constant ERR_ACCESS_CONTROL_NOT_SET (err u1000))
(define-constant ERR_ALREADY_INITIALIZED (err u1001))
(define-constant ERR_NOT_INITIALIZED (err u1002))
(define-constant ERR_UNAUTHORIZED (err u1003))

;; Pool Management (2000-2099)
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_POOL_NOT_FOUND (err u2003))
(define-constant ERR_INVALID_FEE (err u2004))
(define-constant ERR_INVALID_PARAMS (err u2005))
(define-constant ERR_IMPLEMENTATION_NOT_FOUND (err u2006))

(define-constant MAX_FEE_BPS u1000) ;; 10% max fee
(define-constant MAX_PROTOCOL_FEE_BPS u100) ;; 1% max protocol fee

(define-constant POOL_TYPE_CONSTANT_PRODUCT u1)
(define-constant POOL_TYPE_STABLE u2)
(define-constant POOL_TYPE_WEIGHTED u3)
(define-constant POOL_TYPE_CONCENTRATED u4)

;; Roles
(define-constant ROLE_DEX_ADMIN 0x4445585f41444d494e0000000000000000000000000000000000000000000000)  ;; DEX_ADMIN in hex
(define-constant ROLE_FEE_MANAGER 0x4645455f4d414e41474552000000000000000000000000000000000000000000)  ;; FEE_MANAGER in hex
(define-constant ROLE_POOL_MANAGER 0x504f4f4c5f4d414e414745520000000000000000000000000000000000000000)  ;; POOL_MANAGER in hex

;; ===== Data Variables =====
;; Contract State
(define-data-var initialized bool false)
(define-data-var contract-owner principal tx-sender)
(define-data-var access-contract (optional principal) none)

;; Pool Configuration
(define-data-var pool-count uint u0)
(define-data-var default-fee-bps uint u30) ;; 0.3% default
(define-data-var protocol-fee-bps uint u5) ;; 0.05% protocol fee

;; Maps
(define-map pools 
  {token-a: principal, token-b: principal} 
  principal)

(define-map pool-info 
  principal 
  {token-a: principal, token-b: principal, fee-bps: uint, created-at: uint, pool-type: uint})

(define-map pool-stats 
  principal 
  {total-volume: uint, total-fees: uint, liquidity: uint, last-updated: uint})

(define-map pool-implementations 
  uint 
  {contract: principal, enabled: bool})

;; Read-only functions

(define-read-only (get-pending-owner)
  (ok (var-get pending-owner)))

(define-read-only (get-pool (token-a principal) (token-b principal))
  (let ((normalized-pair (normalize-token-pair token-a token-b)))
    (map-get? pools normalized-pair)))

(define-read-only (get-pool-info (pool principal))
  (map-get? pool-info pool))

(define-read-only (get-pool-count)
  (var-get pool-count))

(define-read-only (get-default-fee)
  (var-get default-fee-bps))

(define-read-only (get-protocol-fee)
  (var-get protocol-fee-bps))

(define-read-only (get-pool-stats (pool principal))
  (default-to {total-volume: u0, total-fees: u0, liquidity: u0, last-updated: u0}
              (map-get? pool-stats pool)))

(define-read-only (get-factory-stats)
  {total-pools: (var-get pool-count),
   default-fee: (var-get default-fee-bps),
   protocol-fee: (var-get protocol-fee-bps)})

(define-read-only (get-pool-implementation (pool-type uint))
  (map-get? pool-implementations pool-type))

;; Private helper functions
(define-private (normalize-token-pair (token-a principal) (token-b principal))
  ;; Simple principal comparison using buff conversion
  (let ((token-a-buff (unwrap-panic (principal-destruct? token-a)))
        (token-b-buff (unwrap-panic (principal-destruct? token-b))))
    (if (< (get hash-bytes token-a-buff) (get hash-bytes token-b-buff))
        {token-a: token-a, token-b: token-b}
        {token-a: token-b, token-b: token-a})))

(define-private (valid-pool-type? (pool-type uint))
  (or (is-eq pool-type POOL_TYPE_CONSTANT_PRODUCT)
      (is-eq pool-type POOL_TYPE_STABLE)
      (is-eq pool-type POOL_TYPE_WEIGHTED)
      (is-eq pool-type POOL_TYPE_CONCENTRATED)))

(define-private (get-implementation-contract (pool-type uint))
  (match (map-get? pool-implementations pool-type)
    impl-info (if (get enabled impl-info)
                  (ok (get contract impl-info))
                  ERR_IMPLEMENTATION_NOT_FOUND)
    ERR_IMPLEMENTATION_NOT_FOUND))

;; Access control - ownable-trait implementation
(define-public (only-owner-guard)
  (if (is-eq tx-sender (var-get owner))
    (ok true)
    (err u6001)))  ;; ERR_UNAUTHORIZED

(define-read-only (get-owner)
  (ok (var-get owner)))

(define-read-only (is-owner (user principal))
  (ok (is-eq user (var-get owner))))

(define-private (only-owner)
  (ok (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)))

;; Core factory;; Pool creation
(define-public (create-pool 
  (pool-type uint) 
  (token-a principal) 
  (token-b principal) 
  (fee uint) 
  (sqrt-price-upper uint) 
  (sqrt-price-lower uint) 
  (tick-spacing uint))
  (let (
      (sender tx-sender)
      (token-pair (if (<= (principal-ucmp token-a token-b) 0)
                    {token-a: token-a, token-b: token-b}
                    {token-b: token-b, token-a: token-a}))
    )
    (begin
      (asserts! (contract-call? .access-control has-role ROLE_POOL_MANAGER (as-contract tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (is-none (map-get? pools token-pair)) ERR_POOL_EXISTS)
      (asserts! (not (is-eq token-a token-b)) ERR_INVALID_TOKENS)
      
      (let ((pool-principal (contract-call? .dex-pool deploy 
        { 
          token-a: (get token-a token-pair), 
          token-b: (get token-b token-pair),
          fee: fee,
          sqrt-price-upper: sqrt-price-upper,
          sqrt-price-lower: sqrt-price-lower,
          tick-spacing: tick-spacing
        })))
        
        (map-set pools token-pair pool-principal)
        (map-set pool-info pool-principal {
          token-a: (get token-a token-pair),
          token-b: (get token-b token-pair),
          fee-bps: fee,
          created-at: block-height,
          pool-type: pool-type
        })
        (map-set pool-stats pool-principal {
          total-volume: u0,
          total-fees: u0,
          liquidity: u0,
          last-updated: block-height
        })
        (var-set pool-count (+ (var-get pool-count) u1))
        (print {event: "pool-created", pool: pool-principal, token-a: (get token-a token-pair), token-b: (get token-b token-pair)})
        (ok pool-principal)
      )
    )
  )
)

(define-public (register-pool-implementation (pool-type uint) (implementation principal))
  (begin
    (try! (only-owner))
    (asserts! (valid-pool-type? pool-type) ERR_INVALID_PARAMS)
    (map-set pool-implementations pool-type 
             {contract: implementation, enabled: true})
    (ok true)))

(define-public (toggle-implementation (pool-type uint) (enabled bool))
  (begin
    (try! (only-owner))
    (match (map-get? pool-implementations pool-type)
      impl-info (begin
                  (map-set pool-implementations pool-type 
                           {contract: (get contract impl-info), enabled: enabled})
                  (ok true))
      ERR_IMPLEMENTATION_NOT_FOUND)))

(define-public (recommend-pool (token-a principal) (token-b principal) (amount uint))
  (match (get-pool token-a token-b)
    pool (let ((stats (get-pool-stats pool)))
           (ok {pool: pool, 
                liquidity: (get liquidity stats),
                estimated-slippage: u100})) ;; Simplified calculation
    ERR_POOL_NOT_FOUND))

(define-public (update-pool-stats (pool principal) (volume uint) (fees uint) (liquidity uint))
  (let ((current-stats (get-pool-stats pool)))
    (map-set pool-stats pool 
             {total-volume: (+ (get total-volume current-stats) volume),
              total-fees: (+ (get total-fees current-stats) fees),
              liquidity: liquidity,
              last-updated: block-height})
    (ok true)))

;; Ownership management
(define-public (set-pending-owner (new-owner principal))
  (begin
    (try! (only-owner-guard))
    (var-set pending-owner (some new-owner))
    (print {event: "ownership-transfer-initiated", 
            current-owner: (var-get owner),
            pending-owner: new-owner})
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (only-owner))
    (var-set pending-owner (some new-owner))
    (print {event: "ownership-transfer-initiated", 
            current-owner: (var-get owner),
            pending-owner: new-owner})
    (ok true)))

(define-public (accept-ownership)
  (match (var-get pending-owner)
    pending (if (is-eq tx-sender pending)
                (begin
                  (var-set owner pending)
                  (var-set pending-owner none)
                  (print {event: "ownership-transferred", new-owner: pending})
                  (ok true))
                ERR_UNAUTHORIZED)
    ERR_UNAUTHORIZED))

(define-public (renounce-ownership)
  (begin
    (try! (only-owner-guard))
    (var-set owner SP000000000000000000002Q6VF78)
    (var-set pending-owner none)
    (print {event: "ownership-renounced"})
    (ok true)))

;; Fee management functions
(define-public (set-fee (new-fee uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (or 
      (is-eq tx-sender (var-get contract-owner))
      (unwrap! (has-role ROLE_FEE_MANAGER tx-sender) (err ERR_UNAUTHORIZED))
    ) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee MAX_FEE_BPS) ERR_INVALID_FEE)
    (var-set default-fee-bps new-fee)
    (print {event: "fee-updated", new-fee: new-fee})
    (ok true)))

(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
    (asserts! (or 
      (is-eq tx-sender (var-get contract-owner))
      (unwrap! (has-role ROLE_FEE_MANAGER tx-sender) (err ERR_UNAUTHORIZED))
    ) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee MAX_PROTOCOL_FEE_BPS) ERR_INVALID_FEE)
    (var-set protocol-fee-bps new-fee)
    (print {event: "protocol-fee-updated", new-fee: new-fee})
    (ok true)))

;; Emergency functions
(define-public (pause-pool (pool principal))
  (begin
    (try! (only-owner))
    (print {event: "pool-paused", pool: pool})
    (ok true)))

(define-public (unpause-pool (pool principal))
  (begin
    (try! (only-owner))
    (print {event: "pool-unpaused", pool: pool})
    (ok true)))

;; ===== Access Control Helpers =====
(define-private (has-role (role (buff 32)) (who principal))
  (match (var-get access-contract)
    access-principal (contract-call? access-principal has-role role who)
    (err ERR_ACCESS_CONTROL_NOT_SET)
  )
)

(define-private (only-owner (sender principal))
  (asserts! (is-eq sender (var-get contract-owner)) ERR_UNAUTHORIZED)
  (ok true)
)

;; ===== Initialization =====
(define-public (initialize (owner principal) (access-principal principal))
  (begin
    (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
    (var-set contract-owner owner)
    (var-set access-contract (some access-principal))
    
    ;; Initialize default implementations
    (map-set pool-implementations POOL_TYPE_CONSTANT_PRODUCT 
             {contract: .dex-pool, enabled: true})
    
    (var-set initialized true)
    (ok true)
  )
)

;; ===== Contract Management =====
(define-public (set-access-contract (contract principal))
  (begin
    (try! (only-owner tx-sender))
    (var-set access-contract (some contract))
    (ok true)
  )
)



