;; revenue-distributor.clar
;;
;; Core revenue distribution system for the Conxian protocol
;; Handles automated distribution of protocol fees across the 5-token ecosystem
;;
;; Revenue Split:
;; - 80% to xCXD stakers
;; - 15% to treasury
;; - 5% to insurance reserve

(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait access-control-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.access-control-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_DISTRIBUTION_FAILED (err u103))
(define-constant ERR_INVALID_TOKEN (err u104))
(define-constant ERR_SYSTEM_PAUSED (err u105))

;; Constants
(define-constant REVENUE_SPLIT_STAKERS u8000) ;; 80% in basis points
(define-constant REVENUE_SPLIT_TREASURY u1500) ;; 15% in basis points
(define-constant REVENUE_SPLIT_INSURANCE u500)  ;; 5% in basis points
(define-constant BASIS_POINTS u10000)
(define-constant DISTRIBUTION_INTERVAL u1440) ;; ~1 day in blocks

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)
(define-data-var treasury-address principal tx-sender)
(define-data-var insurance-address principal tx-sender)
(define-data-var last-distribution uint u0)
(define-data-var total-revenue-distributed uint u0)

;; Revenue tracking maps
(define-map token-revenue principal uint) ;; token -> accumulated revenue
(define-map revenue-sources principal
  {
    source-type: (string-ascii 32),
    total-collected: uint,
    last-updated: uint
  }
)

(define-map distribution-history uint
  {
    timestamp: uint,
    total-amount: uint,
    stakers-amount: uint,
    treasury-amount: uint,
    insurance-amount: uint,
    token: principal
  }
)

;; Multi-source revenue aggregation
(define-map fee-types (string-ascii 32)
  {
    is-active: bool,
    collection-contract: principal,
    distribution-weight: uint
  }
)

;; Read-only functions
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-treasury-address)
  (var-get treasury-address)
)

(define-read-only (get-insurance-address)
  (var-get insurance-address)
)

(define-read-only (get-last-distribution)
  (var-get last-distribution)
)

(define-read-only (get-token-revenue (token principal))
  (default-to u0 (map-get? token-revenue token))
)

(define-read-only (get-total-revenue-distributed)
  (var-get total-revenue-distributed)
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (when-not-paused)
  (asserts! (not (var-get paused)) ERR_SYSTEM_PAUSED)
)

(define-private (calculate-distribution-amounts (total-amount uint))
  {
    stakers: (/ (* total-amount REVENUE_SPLIT_STAKERS) BASIS_POINTS),
    treasury: (/ (* total-amount REVENUE_SPLIT_TREASURY) BASIS_POINTS),
    insurance: (/ (* total-amount REVENUE_SPLIT_INSURANCE) BASIS_POINTS)
  }
)

(define-private (distribute-to-stakers (token principal) (amount uint))
  ;; Integration with CXD staking system
  (try! (as-contract (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.cxd-staking distribute-rewards amount)))
  (ok true)
)

(define-private (distribute-to-treasury (token principal) (amount uint))
  ;; Transfer to treasury address
  (try! (contract-call? token transfer amount tx-sender (var-get treasury-address) none))
  (ok true)
)

(define-private (distribute-to-insurance (token principal) (amount uint))
  ;; Transfer to insurance address
  (try! (contract-call? token transfer amount tx-sender (var-get insurance-address) none))
  (ok true)
)

;; Core revenue distribution function
(define-public (distribute-revenue (token principal) (amount uint))
  (let (
    (current-revenue (get-token-revenue token))
    (distribution-amounts (calculate-distribution-amounts amount))
    (distribution-id (+ stacks-block-height current-revenue))
  )
    (begin
      (when-not-paused)
      (asserts! (> amount u0) ERR_INVALID_AMOUNT)

      (map-set token-revenue token (+ current-revenue amount))

      ;; Record distribution
      (map-set distribution-history distribution-id
        {
          timestamp: stacks-block-height,
          total-amount: amount,
          stakers-amount: (get stakers distribution-amounts),
          treasury-amount: (get treasury distribution-amounts),
          insurance-amount: (get insurance distribution-amounts),
          token: token
        }
      )

      (try! (distribute-to-treasury token (get treasury distribution-amounts)))
      (try! (distribute-to-insurance token (get insurance distribution-amounts)))

      ;; Update global tracking
      (var-set total-revenue-distributed (+ (var-get total-revenue-distributed) amount))
      (var-set last-distribution stacks-block-height)

      (ok distribution-id)
    )
  )
)
;; Batch revenue distribution for multiple tokens
(define-public (distribute-multi-token-revenue (distributions (list 10 (tuple (token principal) (amount uint)))))
  (let ((results (map distribute-single-revenue distributions)))
    (begin
      (when-not-paused)
      (asserts! (> (len distributions) u0) ERR_INVALID_AMOUNT)
      (asserts! (<= (len distributions) u10) ERR_INVALID_AMOUNT)

      (ok (len distributions))
    )
  )
)

(define-private (distribute-single-revenue (distribution (tuple (token principal) (amount uint))))
  (distribute-revenue (get token distribution) (get amount distribution))
)

;; Register new fee source
(define-public (register-fee-source (source-type (string-ascii 32)) (collection-contract principal) (weight uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (when-not-paused)

    (map-set fee-types source-type
      {
        is-active: true,
        collection-contract: collection-contract,
        distribution-weight: weight
      }
    )
    (ok true)
  )
)

;; Update fee source configuration
(define-public (update-fee-source (source-type (string-ascii 32)) (is-active bool) (weight uint))
  (let ((current-source (unwrap-panic (map-get? fee-types source-type))))
    (begin
      (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
      (when-not-paused)

      (map-set fee-types source-type
        (merge current-source
          {
            is-active: is-active,
            distribution-weight: weight
          }
        )
      )
      (ok true)
    )
  )
)

;; Emergency functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (emergency-resume)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

;; Admin functions
(define-public (set-treasury-address (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set treasury-address new-treasury)
    (ok true)
  )
)

(define-public (set-insurance-address (new-insurance principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set insurance-address new-insurance)
    (ok true)
  )
)

;; System health and reporting
(define-read-only (get-system-health)
  {
    is-paused: (var-get paused),
    total-revenue-distributed: (var-get total-revenue-distributed),
    last-distribution: (var-get last-distribution),
    treasury-address: (var-get treasury-address),
    insurance-address: (var-get insurance-address),
    active-fee-sources: (len (map fee-types))
  }
)

(define-read-only (get-distribution-history (distribution-id uint))
  (map-get? distribution-history distribution-id)
)

(define-read-only (get-fee-source (source-type (string-ascii 32)))
  (map-get? fee-types source-type)
)

;; Buyback and make mechanism
(define-public (trigger-buyback-and-make (token principal) (buyback-amount uint))
  (let ((revenue-available (get-token-revenue token)))
    (begin
      (when-not-paused)
      (asserts! (>= revenue-available buyback-amount) ERR_INSUFFICIENT_BALANCE)

      ;; Execute buyback logic here
      ;; This would integrate with DEX for token purchases

      (ok buyback-amount)
    )
  )
)
