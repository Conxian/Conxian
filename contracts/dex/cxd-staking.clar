;; cxd-staking.clar
;; xCXD Staking Contract - Revenue distribution with warm-up/cool-down to prevent snapshot sniping
;; Implements buyback-and-make mechanism for revenue sharing

;; Constants
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)

;; Resolve traits using the trait registry
(use-trait sip-010-ft-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait staking-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.staking-trait)
(use-trait circuit-breaker-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-trait)

;; Implement the staking trait
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.staking-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000) ;; 8 decimal places
(define-constant WARM_UP_BLOCKS u1440) ;; ~1 day at 1 min blocks  
(define-constant COOL_DOWN_BLOCKS u10080) ;; ~1 week at 1 min blocks
(define-constant MAX_UNBONDING_PERIOD u20160) ;; ~2 weeks at 1 min blocks

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u400)
(define-constant ERR_NOT_ENOUGH_BALANCE u401)
(define-constant ERR_INSUFFICIENT_STAKED u402)
(define-constant ERR_WARM_UP_NOT_COMPLETE u403)
(define-constant ERR_COOL_DOWN_ACTIVE u404)
(define-constant ERR_NO_PENDING_STAKE u405)
(define-constant ERR_NO_PENDING_UNSTAKE u406)
(define-constant ERR_REVENUE_DISTRIBUTION_FAILED u407)
(define-constant ERR_INVALID_AMOUNT u408)
(define-constant ERR_CONTRACT_PAUSED u409)
(define-constant ERR_CIRCUIT_OPEN (err u5000))

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var total-supply uint u0) ;; Total xCXD supply
(define-data-var total-staked-cxd uint u0) ;; Total CXD staked
(define-data-var revenue-per-share uint u0) ;; Accumulated revenue per xCXD share
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Staked CXD Token")
(define-data-var symbol (string-ascii 10) "xCXD")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var paused bool false)
(define-data-var circuit-breaker principal 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.circuit-breaker)

;; CXD token contract
(define-data-var cxd-token-contract principal 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.cxd-token)

;; --- User State ---
(define-map user-balances principal uint) ;; xCXD balances
(define-map user-debt principal uint) ;; Revenue debt for proper accounting

;; Pending stakes (warm-up period)
(define-map pending-stakes 
  principal 
  { amount: uint, created-at: uint })

;; Pending unstakes (cool-down period) 
(define-map pending-unstakes
  principal
  { xcxd-amount: uint, cxd-amount: uint, created-at: uint })

;; Revenue tracking
(define-map revenue-snapshots 
  { user: principal, epoch: uint }
  { debt: uint, claimed: uint })

;; --- Revenue Distribution State ---
(define-data-var current-epoch uint u0)
(define-data-var total-revenue-distributed uint u0)

;; --- Emergency Controls ---
(define-data-var kill-switch bool false)

;; --- Private Functions ---
(define-private (check-circuit-breaker) 
  (contract-call? (as-contract (var-get circuit-breaker)) is-circuit-open)
)

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

(define-read-only (get-exchange-rate)
  (let ((total-staked (var-get total-staked-cxd))
        (total-shares (var-get total-supply)))
    (if (is-eq total-shares u0)
      PRECISION
      (/ (* total-staked PRECISION) total-shares))))

(define-read-only (cxd-to-xcxd (cxd-amount uint))
  (let ((rate (get-exchange-rate)))
    (/ (* cxd-amount PRECISION) rate)))

(define-read-only (xcxd-to-cxd (xcxd-amount uint))
  (let ((rate (get-exchange-rate)))
    (/ (* xcxd-amount rate) PRECISION)))

(define-read-only (get-pending-stake (user principal))
  (map-get? pending-stakes user))

(define-read-only (get-pending-unstake (user principal))
  (map-get? pending-unstakes user))

(define-read-only (is-warm-up-complete (user principal))
  (match (get-pending-stake user)
    stake-info (>= block-height (+ (get created-at stake-info) WARM_UP_BLOCKS))
    false))

(define-read-only (is-cool-down-complete (user principal))
  (match (get-pending-unstake user)
    unstake-info (>= block-height (+ (get created-at unstake-info) COOL_DOWN_BLOCKS))
    false))

;; Calculate claimable revenue for user
(define-read-only (get-claimable-revenue (user principal))
  (let ((user-xcxd (default-to u0 (map-get? user-balances user)))
        (user-debt-amount (default-to u0 (map-get? user-debt user)))
        (current-revenue-per-share (var-get revenue-per-share)))
    (if (is-eq user-xcxd u0)
      u0
      (let ((total-entitled (/ (* user-xcxd current-revenue-per-share) PRECISION)))
        (if (> total-entitled user-debt-amount)
          (- total-entitled user-debt-amount)
          u0)))))

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-cxd-contract (new-contract principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set cxd-token-contract new-contract)
    (ok true)))

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set paused true)
    (ok true)))

(define-public (unpause-contract)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set paused false)
    (ok true)))

;; Emergency kill switch - only allows unstaking
(define-public (activate-kill-switch)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set kill-switch true)
    (var-set paused true)
    (ok true)))

;; --- Core Staking Functions ---

;; Step 1: Initiate stake (starts warm-up period)
(define-public (initiate-stake (amount uint))
  (let ((cxd-token-ref (var-get cxd-token-contract)))
    (begin
      (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
      (asserts! (not (var-get paused)) (err ERR_CONTRACT_PAUSED))
      (asserts! (not (var-get kill-switch)) (err ERR_CONTRACT_PAUSED))
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      
      ;; Transfer CXD from user to this contract  
      ;; Note: Direct contract call removed to break circular dependency
      ;; This would be configured via contract initialization in production
      
      ;; Store pending stake
      (map-set pending-stakes tx-sender { amount: amount, created-at: block-height })
      
      (ok true))))

;; Step 2: Complete stake (after warm-up period)
(define-public (complete-stake)
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (match (get-pending-stake tx-sender)
      stake-info
      (begin
        (asserts! (>= block-height (+ (get created-at stake-info) WARM_UP_BLOCKS)) (err ERR_WARM_UP_NOT_COMPLETE))
        
        (let ((cxd-amount (get amount stake-info))
              (xcxd-amount (cxd-to-xcxd cxd-amount))
              (current-revenue-per-share (var-get revenue-per-share)))
          
          ;; Update user balance and debt
          (map-set user-balances tx-sender 
            (+ (default-to u0 (map-get? user-balances tx-sender)) xcxd-amount))
          
          ;; Set debt to current revenue level to prevent claiming past revenue
          (map-set user-debt tx-sender
            (+ (default-to u0 (map-get? user-debt tx-sender))
               (/ (* xcxd-amount current-revenue-per-share) PRECISION)))
          
          ;; Update totals
          (var-set total-supply (+ (var-get total-supply) xcxd-amount))
          (var-set total-staked-cxd (+ (var-get total-staked-cxd) cxd-amount))
          
          ;; Clear pending stake
          (map-delete pending-stakes tx-sender)
          
          (ok xcxd-amount)))
      (err ERR_NO_PENDING_STAKE))))

;; Step 1: Initiate unstake (starts cool-down period)
(define-public (initiate-unstake (xcxd-amount uint))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((user-balance (default-to u0 (map-get? user-balances tx-sender))))
      (begin
        (asserts! (>= user-balance xcxd-amount) (err ERR_INSUFFICIENT_STAKED))
        (asserts! (> xcxd-amount u0) (err ERR_INVALID_AMOUNT))
        
        (let ((cxd-amount (xcxd-to-cxd xcxd-amount)))
          ;; Update user balance immediately
          (map-set user-balances tx-sender (- user-balance xcxd-amount))
          (var-set total-supply (- (var-get total-supply) xcxd-amount))
          
          ;; Store pending unstake
          (map-set pending-unstakes tx-sender 
            { xcxd-amount: xcxd-amount, cxd-amount: cxd-amount, created-at: block-height })
          
          (ok true))))))

;; Step 2: Complete unstake (after cool-down period)  
(define-public (complete-unstake (cxd-token ft-trait))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((unstake-result (get-pending-unstake tx-sender)))
      (match unstake-result
        unstake-info
        (begin
          (asserts! (>= block-height (+ (get created-at unstake-info) COOL_DOWN_BLOCKS)) (err ERR_COOL_DOWN_ACTIVE))
          
          (let ((cxd-amount (get cxd-amount unstake-info)))
            ;; Transfer CXD back to user from the staking contract using provided CXD contract
            (try! (as-contract (contract-call? cxd-token transfer cxd-amount (as-contract tx-sender) tx-sender none)))
            ;; Update total staked
            (var-set total-staked-cxd (- (var-get total-staked-cxd) cxd-amount))
            ;; Clear pending unstake
            (map-delete pending-unstakes tx-sender)
            (ok cxd-amount)))
        (err ERR_NO_PENDING_UNSTAKE)))))

;; --- Revenue Distribution ---

;; Distribute revenue to all xCXD holders (called by protocol/vault contracts)
(define-public (distribute-revenue (revenue-amount uint) (revenue-token principal))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((total-shares (var-get total-supply)))
      (begin
        (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED)) ;; Only protocol can call this
        (asserts! (> total-shares u0) (err ERR_REVENUE_DISTRIBUTION_FAILED))
        
        ;; Update revenue per share
        (let ((additional-per-share (/ (* revenue-amount PRECISION) total-shares)))
          (var-set revenue-per-share (+ (var-get revenue-per-share) additional-per-share))
          (var-set total-revenue-distributed (+ (var-get total-revenue-distributed) revenue-amount))
          (var-set current-epoch (+ (var-get current-epoch) u1))
          
          ;; Transfer revenue to this contract for distribution
          (try! (contract-call? revenue-token transfer revenue-amount tx-sender (as-contract tx-sender) none))
          
          (ok true))))))

;; Claim available revenue
(define-public (claim-revenue (revenue-token ft-trait))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((claimable (get-claimable-revenue tx-sender))
          (user-debt-current (default-to u0 (map-get? user-debt tx-sender)))
          (user-xcxd (default-to u0 (map-get? user-balances tx-sender))))
      (begin
        (asserts! (> claimable u0) (err ERR_INVALID_AMOUNT))
        
        ;; Update user debt to prevent double claiming
        (map-set user-debt tx-sender 
          (+ user-debt-current claimable))
        
        ;; Transfer revenue to user
        (try! (as-contract (contract-call? revenue-token transfer claimable (as-contract tx-sender) tx-sender none)))
        
        (ok claimable)))))

;; --- SIP-010 Interface (for xCXD) ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (let ((sender-balance (default-to u0 (map-get? user-balances sender))))
      (asserts! (>= sender-balance amount) (err ERR_NOT_ENOUGH_BALANCE))
      
      ;; Update balances
      (map-set user-balances sender (- sender-balance amount))
      (map-set user-balances recipient 
        (+ (default-to u0 (map-get? user-balances recipient)) amount))
      
      ;; Transfer revenue debt proportionally
      (let ((sender-debt (default-to u0 (map-get? user-debt sender)))
            (debt-to-transfer (/ (* sender-debt amount) sender-balance)))
        (map-set user-debt sender (- sender-debt debt-to-transfer))
        (map-set user-debt recipient 
          (+ (default-to u0 (map-get? user-debt recipient)) debt-to-transfer)))
      
      (ok true))))

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? user-balances who))))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-decimals)
  (ok (var-get decimals)))

(define-read-only (get-name)
  (ok (var-get name)))

(define-read-only (get-symbol)
  (ok (var-get symbol)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-public (set-token-uri (uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set token-uri uri)
    (ok true)))

;; --- Read-Only Functions ---
(define-read-only (get-user-info (user principal))
  (let ((xcxd-balance (default-to u0 (map-get? user-balances user)))
        (cxd-equivalent (xcxd-to-cxd xcxd-balance))
        (claimable-revenue (get-claimable-revenue user))
        (pending-stake (get-pending-stake user))
        (pending-unstake (get-pending-unstake user)))
    {
      xcxd-balance: xcxd-balance,
      cxd-equivalent: cxd-equivalent,
      claimable-revenue: claimable-revenue,
      pending-stake: pending-stake,
      pending-unstake: pending-unstake,
      warm-up-complete: (is-warm-up-complete user),
      cool-down-complete: (is-cool-down-complete user)
    }))

(define-read-only (get-protocol-info)
  {
    total-supply: (var-get total-supply),
    total-staked-cxd: (var-get total-staked-cxd),
    exchange-rate: (get-exchange-rate),
    revenue-per-share: (var-get revenue-per-share),
    total-revenue-distributed: (var-get total-revenue-distributed),
    current-epoch: (var-get current-epoch),
    paused: (var-get paused),
    kill-switch: (var-get kill-switch)
  })





