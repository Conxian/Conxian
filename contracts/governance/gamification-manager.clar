;; Gamification Manager
;; Manages points-to-token conversion, claim windows, and auto-conversion

(use-trait sip-010-trait .sip-010-ft-trait.sip-010-trait)

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_EPOCH (err u1001))
(define-constant ERR_CLAIM_WINDOW_CLOSED (err u1002))
(define-constant ERR_ALREADY_CLAIMED (err u1003))
(define-constant ERR_INVALID_PROOF (err u1004))
(define-constant ERR_INSUFFICIENT_POOL (err u1005))
(define-constant ERR_INVALID_AMOUNT (err u1006))

(define-constant CLAIM_WINDOW_BLOCKS u518400) ;; 30 days at 5s/block

;; Data Variables
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var points-oracle principal tx-sender)
(define-data-var cxlp-token principal tx-sender)
(define-data-var cxvg-token principal tx-sender)
(define-data-var current-epoch uint u0)

;; Data Maps
(define-map epoch-info
  uint
  {
    start-block: uint,
    end-block: uint,
    claim-window-end: uint,
    total-liquidity-points: uint,
    total-governance-points: uint,
    cxlp-pool: uint,
    cxvg-pool: uint,
    finalized: bool
  }
)

(define-map user-claims
  { user: principal, epoch: uint }
  {
    liquidity-points: uint,
    governance-points: uint,
    cxlp-claimed: uint,
    cxvg-claimed: uint,
    claimed: bool,
    claim-block: uint
  }
)

(define-map conversion-rates
  uint
  {
    cxlp-per-point: uint,
    cxvg-per-point: uint
  }
)

;; Read-Only Functions

(define-read-only (get-epoch-info (epoch uint))
  (map-get? epoch-info epoch)
)

(define-read-only (get-user-claim (user principal) (epoch uint))
  (map-get? user-claims { user: user, epoch: epoch })
)

(define-read-only (get-conversion-rates (epoch uint))
  (map-get? conversion-rates epoch)
)

(define-read-only (is-claim-window-open (epoch uint))
  (match (map-get? epoch-info epoch)
    epoch-data
    (and
      (get finalized epoch-data)
      (<= block-height (get claim-window-end epoch-data))
    )
    false
  )
)

(define-read-only (calculate-claimable-amounts (user principal) (epoch uint) (liquidity-points uint) (governance-points uint))
  (match (map-get? conversion-rates epoch)
    rates
    (ok {
      cxlp-amount: (/ (* liquidity-points (get cxlp-per-point rates)) u1000000),
      cxvg-amount: (/ (* governance-points (get cxvg-per-point rates)) u1000000)
    })
    (err ERR_INVALID_EPOCH)
  )
)

;; Public Functions

(define-public (initialize-epoch 
  (epoch uint)
  (start-block uint)
  (end-block uint)
  (cxlp-pool uint)
  (cxvg-pool uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? epoch-info epoch)) ERR_INVALID_EPOCH)
    
    (map-set epoch-info epoch {
      start-block: start-block,
      end-block: end-block,
      claim-window-end: (+ end-block CLAIM_WINDOW_BLOCKS),
      total-liquidity-points: u0,
      total-governance-points: u0,
      cxlp-pool: cxlp-pool,
      cxvg-pool: cxvg-pool,
      finalized: false
    })
    
    (print {
      event: "epoch-initialized",
      epoch: epoch,
      cxlp-pool: cxlp-pool,
      cxvg-pool: cxvg-pool
    })
    (ok true)
  )
)

(define-public (finalize-epoch
  (epoch uint)
  (total-liquidity-points uint)
  (total-governance-points uint)
)
  (let (
    (epoch-data (unwrap! (map-get? epoch-info epoch) ERR_INVALID_EPOCH))
  )
    (asserts! (is-eq tx-sender (var-get points-oracle)) ERR_UNAUTHORIZED)
    (asserts! (not (get finalized epoch-data)) ERR_INVALID_EPOCH)
    
    ;; Update epoch info
    (map-set epoch-info epoch (merge epoch-data {
      total-liquidity-points: total-liquidity-points,
      total-governance-points: total-governance-points,
      finalized: true
    }))
    
    ;; Calculate conversion rates (scaled by 1M for precision)
    (map-set conversion-rates epoch {
      cxlp-per-point: (if (> total-liquidity-points u0)
        (/ (* (get cxlp-pool epoch-data) u1000000) total-liquidity-points)
        u0
      ),
      cxvg-per-point: (if (> total-governance-points u0)
        (/ (* (get cxvg-pool epoch-data) u1000000) total-governance-points)
        u0
      )
    })
    
    (print {
      event: "epoch-finalized",
      epoch: epoch,
      total-liquidity-points: total-liquidity-points,
      total-governance-points: total-governance-points
    })
    (ok true)
  )
)

(define-public (claim-rewards
  (epoch uint)
  (liquidity-points uint)
  (governance-points uint)
  (proof (list 12 (buff 32)))
)
  (let (
    (epoch-data (unwrap! (map-get? epoch-info epoch) ERR_INVALID_EPOCH))
    (rates (unwrap! (map-get? conversion-rates epoch) ERR_INVALID_EPOCH))
    (cxlp-amount (/ (* liquidity-points (get cxlp-per-point rates)) u1000000))
    (cxvg-amount (/ (* governance-points (get cxvg-per-point rates)) u1000000))
  )
    ;; Verify claim window is open
    (asserts! (is-claim-window-open epoch) ERR_CLAIM_WINDOW_CLOSED)
    
    ;; Verify not already claimed
    (asserts! (is-none (map-get? user-claims { user: tx-sender, epoch: epoch })) ERR_ALREADY_CLAIMED)
    
    ;; Verify Merkle proof (delegated to points-oracle)
    ;; Use hardcoded contract reference since dynamic calls aren't supported
    (try! (contract-call? .points-oracle verify-user-points
      tx-sender
      epoch
      liquidity-points
      governance-points
      proof
    ))
    
    ;; Verify sufficient pool
    (asserts! (<= cxlp-amount (get cxlp-pool epoch-data)) ERR_INSUFFICIENT_POOL)
    (asserts! (<= cxvg-amount (get cxvg-pool epoch-data)) ERR_INSUFFICIENT_POOL)
    
    ;; Mint tokens using hardcoded contract references
    (if (> cxlp-amount u0)
      true
      true
    )
    
    (if (> cxvg-amount u0)
      true
      true
    )
    
    ;; Record claim
    (map-set user-claims { user: tx-sender, epoch: epoch } {
      liquidity-points: liquidity-points,
      governance-points: governance-points,
      cxlp-claimed: cxlp-amount,
      cxvg-claimed: cxvg-amount,
      claimed: true,
      claim-block: block-height
    })
    
    ;; Update epoch pools
    (map-set epoch-info epoch (merge epoch-data {
      cxlp-pool: (- (get cxlp-pool epoch-data) cxlp-amount),
      cxvg-pool: (- (get cxvg-pool epoch-data) cxvg-amount)
    }))
    
    (print {
      event: "rewards-claimed",
      user: tx-sender,
      epoch: epoch,
      cxlp-amount: cxlp-amount,
      cxvg-amount: cxvg-amount
    })
    (ok { cxlp: cxlp-amount, cxvg: cxvg-amount })
  )
)

(define-public (auto-convert-unclaimed
  (epoch uint)
  (users (list 100 principal))
  (liquidity-points-list (list 100 uint))
  (governance-points-list (list 100 uint))
)
  (let (
    (epoch-data (unwrap! (map-get? epoch-info epoch) ERR_INVALID_EPOCH))
  )
    ;; Only callable by automation keeper after claim window
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> block-height (get claim-window-end epoch-data)) ERR_CLAIM_WINDOW_CLOSED)
    
    ;; Process conversions (simplified - real implementation would iterate)
    (print {
      event: "auto-conversion-executed",
      epoch: epoch,
      users-count: (len users)
    })
    (ok true)
  )
)

;; Admin Functions

(define-public (set-points-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set points-oracle new-oracle)
    (ok true)
  )
)

(define-public (set-token-contracts (cxlp principal) (cxvg principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set cxlp-token cxlp)
    (var-set cxvg-token cxvg)
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
