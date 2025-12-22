;; Early LP Funder & Long-term User Rewards
;; @desc Tracks and rewards early supporters with opex contribution options

(define-constant EARLY_LP_THRESHOLD u100) ;; First 100 LPs
(define-constant YEAR_IN_BLOCKS u756864000) ;; ~365 days (144 blocks/day)
(define-constant OPEX_SPLIT_DEFAULT u30) ;; 30% default opex contribution

;; Track early LPs
(define-map early-lp-funders
  principal
  {
    lp-id: uint,
    first-deposit-block: uint,
    total-contributed: uint,
    opex-split-percentage: uint, ;; 0-100
    rewards-earned: uint
  }
)

(define-data-var early-lp-count uint u0)

;; Track long-term users (1+ year)
(define-map long-term-users
  principal
  {
    first-interaction: uint,
    total-epochs: uint,
    engagement-score: uint, ;; 0-100 based on activity
    opex-contribution-enabled: bool,
    opex-split-percentage: uint
  }
)

;; Register early LP funder
(define-public (register-early-lp (amount uint))
  (let (
    (current-count (var-get early-lp-count))
  )
    (asserts! (< current-count EARLY_LP_THRESHOLD) (err u403))
    
    (map-set early-lp-funders tx-sender {
      lp-id: current-count,
      first-deposit-block: block-height,
      total-contributed: amount,
      opex-split-percentage: OPEX_SPLIT_DEFAULT,
      rewards-earned: u0
    })
    
    (var-set early-lp-count (+ current-count u1))
    (ok current-count)
  )
)

;; Set opex contribution split
(define-public (set-opex-split (percentage uint))
  (begin
    (asserts! (<= percentage u100) (err u400))
    
    ;; Update for early LPs
    (match (map-get? early-lp-funders tx-sender)
      lp-data (begin
        (map-set early-lp-funders tx-sender (merge lp-data {opex-split-percentage: percentage}))
        (ok true))
      ;; Update for long-term users
      (match (map-get? long-term-users tx-sender)
        user-data (begin
          (map-set long-term-users tx-sender (merge user-data {opex-split-percentage: percentage}))
          (ok true))
        (err u404))
    )
  )
)

;; Distribute rewards with auto-split to opex
(define-public (distribute-rewards (user principal) (total-reward uint))
  (let (
    (split-pct (get-user-opex-split user))
    (opex-contribution (/ (* total-reward split-pct) u100))
    (user-portion (- total-reward opex-contribution))
  )
    ;; Send user portion
    (try! (contract-call? .cxd-token transfer user-portion (as-contract tx-sender) user none))
    
    ;; Send opex portion to treasury
    (try! (contract-call? .cxd-token transfer opex-contribution (as-contract tx-sender) .treasury-manager none))
    
    ;; Record contribution
    (print {
      event: "reward-distribution",
      user: user,
      total: total-reward,
      user-portion: user-portion,
      opex-contribution: opex-contribution
    })
    
    (ok true)
  )
)

;; Get user's opex split percentage
(define-read-only (get-user-opex-split (user principal))
  (match (map-get? early-lp-funders user)
    lp-data (get opex-split-percentage lp-data)
    (match (map-get? long-term-users user)
      user-data (get opex-split-percentage user-data)
      OPEX_SPLIT_DEFAULT))
)

;; Check if user qualifies as long-term (1+ year)
(define-read-only (is-long-term-user (user principal))
  (match (map-get? long-term-users user)
    data (>= (- block-height (get first-interaction data)) YEAR_IN_BLOCKS)
    false)
)

;; Calculate engagement score
(define-read-only (calculate-engagement-score (user principal))
  (match (map-get? long-term-users user)
    data
    (let (
      (blocks-active (- block-height (get first-interaction data)))
      (epochs (get total-epochs data))
      (consistency (if (> blocks-active u0)
                      (/ (* epochs u100) (/ blocks-active YEAR_IN_BLOCKS))
                      u0))
    )
      (if (> consistency u100) u100 consistency))
    u0)
)
