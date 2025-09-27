;; cxlp-migration-queue.clar
;; Intent queue system for CXLP to CXD migration with pro-rata settlement
;; Prevents FCFS races and enables fair distribution based on duration-weighted requests
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait access-control-trait .all-traits.access-control-trait)
(use-trait cxlp-migration-queue-trait .all-traits.cxlp-migration-queue-trait)
(use-trait ft-mintable .all-traits.ft-mintable-trait)

(impl-trait .all-traits.cxlp-migration-queue-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; Migration bands with multipliers
(define-constant BAND0 u10000) ;; 1.00x
(define-constant BAND1 u12500) ;; 1.25x  
(define-constant BAND2 u15000) ;; 1.50x
(define-constant BAND3 u20000) ;; 2.00x

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u500)
(define-constant ERR_MIGRATION_NOT_SET u501)
(define-constant ERR_MIGRATION_NOT_STARTED u502)
(define-constant ERR_INVALID_EPOCH u503)
(define-constant ERR_EPOCH_NOT_ACTIVE u504)
(define-constant ERR_EPOCH_SETTLED u505)
(define-constant ERR_NO_INTENT_FOUND u506)
(define-constant ERR_INSUFFICIENT_BALANCE u507)
(define-constant ERR_INVALID_AMOUNT u508)
(define-constant ERR_CONTRACT_MISMATCH u509)
(define-constant ERR_ZERO_WEIGHT u510)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var cxlp-contract principal 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.cxlp-token')
(define-data-var cxd-contract principal 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.cxd-token')

;; Migration configuration
(define-data-var migration-start-height uint u0)
(define-data-var epoch-length uint u1440) ;; ~1 day in blocks
(define-data-var current-epoch uint u0)
(define-data-var epoch-cap uint u1000000) ;; CXD cap per epoch

;; Intent collection window (blocks before settlement)
(define-data-var intent-window uint u144) ;; ~2.4 hours

;; --- Epoch State ---
(define-map epoch-info
  { epoch: uint }
  { 
    start-height: uint,
    end-height: uint,
    intent-deadline: uint,
    total-cxlp-requested: uint,
    total-weight: uint,
    settled: bool,
    actual-cxd-minted: uint
  })

;; --- User Intents ---
(define-map user-intents
  { epoch: uint, user: principal }
  { 
    cxlp-amount: uint,
    duration-held: uint, 
    weight: uint,
    cxd-allocation: uint,
    claimed: bool
  })

;; --- User Duration Tracking ---
(define-map user-duration-tracking
  principal
  { balance-since: uint, last-transfer: uint })

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-contracts (cxlp principal) (cxd principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxlp-contract cxlp)
    (var-set cxd-contract cxd)
    (ok true)))

(define-public (configure-migration (start-height uint) (epoch-len uint) (cap uint) (window uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set migration-start-height start-height)
    (var-set epoch-length epoch-len)
    (var-set epoch-cap cap)
    (var-set intent-window window)
    (ok true)))

;; --- Core Logic ---

;; Calculate current epoch based on block height
(define-read-only (get-current-epoch)
  (let ((start (var-get migration-start-height))
        (len (var-get epoch-length)))
    (if (or (is-eq start u0) (< block-height start))
      (ok u0)
      (ok (/ (- block-height start) len)))))

;; Get band and multiplier based on duration
(define-read-only (get-band-multiplier (duration-blocks uint))
  (let ((epoch-len (var-get epoch-length)))
    (if (< duration-blocks epoch-len)
      BAND0
      (if (< duration-blocks (* epoch-len u2))
        BAND1  
        (if (< duration-blocks (* epoch-len u4))
          BAND2
          BAND3)))))

;; Calculate weight based on amount and duration
(define-read-only (calculate-weight (cxlp-amount uint) (duration uint))
  (let ((base-weight cxlp-amount)
        (duration-multiplier (get-band-multiplier duration)))
    (/ (* base-weight duration-multiplier) u10000)))

;; Get users duration held (blocks since last balance change)
(define-read-only (get-user-duration (user principal))
  (match (map-get? user-duration-tracking user)
    tracking-info 
    (- block-height (get balance-since tracking-info))
    u0))

;; --- Intent Management ---

;; Submit intent for current epoch
(define-public (submit-intent (cxlp-amount uint))
  (let ((current-epoch-num (unwrap! (get-current-epoch) (err ERR_MIGRATION_NOT_STARTED)))
        (user-duration (get-user-duration tx-sender)))
    (begin
      (asserts! (> cxlp-amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (>= current-epoch-num u1) (err ERR_MIGRATION_NOT_STARTED))
      
      ;; Ensure epoch is active for intents
      (let ((epoch-start (+ (var-get migration-start-height) (* current-epoch-num (var-get epoch-length))))
            (intent-deadline (- (+ epoch-start (var-get epoch-length)) (var-get intent-window))))
        
        (asserts! (<= block-height intent-deadline) (err ERR_EPOCH_NOT_ACTIVE))
        
        ;; Check user has sufficient CXLP balance
        (let ((user-balance (unwrap! (contract-call? (var-get cxlp-contract) get-balance tx-sender) (err ERR_INSUFFICIENT_BALANCE))))
            (asserts! (>= user-balance cxlp-amount) (err ERR_INSUFFICIENT_BALANCE))
            
            ;; Calculate weight for this intent
            (let ((weight (calculate-weight cxlp-amount user-duration)))
              
              ;; Store user intent
              (map-set user-intents 
                { epoch: current-epoch-num, user: tx-sender }
                {
                  cxlp-amount: cxlp-amount,
                  duration-held: user-duration,
                  weight: weight,
                  cxd-allocation: u0,
                  claimed: false
                })
              
              ;; Update epoch totals
              (let ((current-epoch-info (default-to 
                      { start-height: epoch-start, end-height: (+ epoch-start (var-get epoch-length)), 
                        intent-deadline: intent-deadline, total-cxlp-requested: u0, total-weight: u0, 
                        settled: false, actual-cxd-minted: u0 }
                      (map-get? epoch-info { epoch: current-epoch-num }))))
                
                (map-set epoch-info 
                  { epoch: current-epoch-num }
                  (merge current-epoch-info
                    {
                      total-cxlp-requested: (+ (get total-cxlp-requested current-epoch-info) cxlp-amount),
                      total-weight: (+ (get total-weight current-epoch-info) weight)
                    }))
                
                (ok { epoch: current-epoch-num, weight: weight, duration: user-duration }))))))))

;; Settle epoch with pro-rata allocation
(define-public (settle-epoch (epoch uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    
    (match (map-get? epoch-info { epoch: epoch })
      epoch-data
      (begin
        (asserts! (not (get settled epoch-data)) (err ERR_EPOCH_SETTLED))
        (asserts! (> block-height (get end-height epoch-data)) (err ERR_EPOCH_NOT_ACTIVE))
        
        (let ((total-weight (get total-weight epoch-data))
              (epoch-cap-amount (var-get epoch-cap)))
          
          (asserts! (> total-weight u0) (err ERR_ZERO_WEIGHT))
          
          ;; Mark epoch as settled
          (map-set epoch-info 
            { epoch: epoch }
            (merge epoch-data { settled: true, actual-cxd-minted: epoch-cap-amount }))
          
          (ok { epoch: epoch, total-weight: total-weight, cxd-available: epoch-cap-amount })))
      (err ERR_INVALID_EPOCH))))

;; Claim CXD allocation for settled epoch
(define-public (claim-allocation (epoch uint) (cxd-token <ft-mintable>))
  (match (map-get? user-intents { epoch: epoch, user: tx-sender })
    user-intent
    (begin
      (asserts! (not (get claimed user-intent)) (err ERR_NO_INTENT_FOUND))
      
      (match (map-get? epoch-info { epoch: epoch })
        epoch-data
        (begin
          (asserts! (get settled epoch-data) (err ERR_EPOCH_NOT_ACTIVE))
          (asserts! (is-eq (contract-of cxd-token) (var-get cxd-contract)) (err ERR_CONTRACT_MISMATCH))
          
          ;; Calculate pro-rata allocation
          (let ((user-weight (get weight user-intent))
                (total-weight (get total-weight epoch-data))
                (total-cxd (get actual-cxd-minted epoch-data))
                (user-cxlp (get cxlp-amount user-intent))
                (pro-rata-cxd (/ (* user-weight total-cxd) total-weight)))
            
            ;; Burn CXLP from user
            (try! (contract-call? (var-get cxlp-contract) transfer user-cxlp tx-sender (as-contract tx-sender) none))
            (try! (as-contract (contract-call? (var-get cxlp-contract) burn user-cxlp)))
            
            ;; Mint CXD to user
            (try! (as-contract (contract-call? cxd-token mint tx-sender pro-rata-cxd)))
            
            ;; Mark as claimed
            (map-set user-intents
              { epoch: epoch, user: tx-sender }
              (merge user-intent { cxd-allocation: pro-rata-cxd, claimed: true }))
            
            (ok { cxlp-burned: user-cxlp, cxd-received: pro-rata-cxd, weight: user-weight })))
        (err ERR_INVALID_EPOCH)))
    (err ERR_NO_INTENT_FOUND)))

;; --- Duration Tracking Hooks ---

;; Called by CXLP token on transfers to reset duration tracking
(define-public (on-cxlp-transfer (from principal) (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get cxlp-contract)) (err ERR_UNAUTHORIZED))
    
    ;; Reset duration tracking for recipient
    (map-set user-duration-tracking to 
      { balance-since: block-height, last-transfer: block-height })
    
    (ok true)))

;; Initialize duration tracking for new users
(define-public (initialize-duration-tracking (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get cxlp-contract)) (err ERR_UNAUTHORIZED))
    (map-set user-duration-tracking user
      { balance-since: block-height, last-transfer: block-height })
    (ok true)))

;; --- Read-Only Functions ---

(define-read-only (get-epoch-info (epoch uint))
  (map-get? epoch-info { epoch: epoch }))

(define-read-only (get-user-intent (epoch uint) (user principal))
  (map-get? user-intents { epoch: epoch, user: user }))

(define-read-only (get-user-duration-info (user principal))
  (let ((tracking (map-get? user-duration-tracking user))
        (current-duration (get-user-duration user)))
    {
      tracking-info: tracking,
      current-duration: current-duration,
      current-band: (get-band-multiplier current-duration)
    }))

(define-read-only (calculate-potential-weight (user principal) (cxlp-amount uint))
  (let ((duration (get-user-duration user)))
    (calculate-weight cxlp-amount duration)))

(define-read-only (get-migration-info)
  {
    migration-start: (var-get migration-start-height),
    epoch-length: (var-get epoch-length),
    current-epoch: (unwrap-panic (get-current-epoch)),
    epoch-cap: (var-get epoch-cap),
    intent-window: (var-get intent-window),
    cxlp-contract: (var-get cxlp-contract),
    cxd-contract: (var-get cxd-contract)
  })

