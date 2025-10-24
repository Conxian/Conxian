;; token-emission-controller.clar
;; Hard-coded emission rails with governance guards to prevent inflation abuse

<<<<<<< Updated upstream
;; --- Trait Imports ---
(use-trait ft-mintable-trait .all-traits.ft-mintable-trait)
=======
(use-trait sip-010-ft-mintable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-mintable-trait)
>>>>>>> Stashed changes

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; Emission limits (annual inflation caps)
(define-constant CXD_MAX_ANNUAL_INFLATION u2000) ;; 2% max annual inflation for CXD
(define-constant CXVG_MAX_ANNUAL_INFLATION u500) ;; 0.5% max for governance token
(define-constant CXLP_MAX_ANNUAL_INFLATION u1000) ;; 1% max for LP token
(define-constant CXTR_MAX_ANNUAL_INFLATION u10000) ;; 10% max for creator token

;; Hard caps per epoch (blocks)
(define-constant EPOCH_BLOCKS u52560) ;; ~1 year at 1 min blocks
(define-constant MAX_SINGLE_MINT_BPS u100) ;; 1% of supply max per mint

;; Governance requirements for changes
(define-constant SUPERMAJORITY_THRESHOLD u6667) ;; 66.67% required
(define-constant TIMELOCK_BLOCKS u20160) ;; ~2 weeks minimum delay
(define-constant EMERGENCY_TIMELOCK u1440) ;; ~1 day for emergency reduction

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u700)
(define-constant ERR_EMISSION_CAP_EXCEEDED u701)
(define-constant ERR_SINGLE_MINT_TOO_LARGE u702)
(define-constant ERR_INVALID_TOKEN u703)
(define-constant ERR_GOVERNANCE_THRESHOLD_NOT_MET u704)
(define-constant ERR_TIMELOCK_ACTIVE u705)
(define-constant ERR_NO_PENDING_CHANGE u706)
(define-constant ERR_TIMELOCK_NOT_ELAPSED u707)
(define-constant ERR_INVALID_PARAMETERS u708)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var governance-contract (optional principal) none)

;; --- Optional Token Contract References (Dependency Injection) ---
(define-data-var cxd-contract (optional principal) none)
(define-data-var cxvg-contract (optional principal) none)
(define-data-var cxlp-contract (optional principal) none)
(define-data-var cxtr-contract (optional principal) none)
(define-data-var system-integration-enabled bool false)
(define-data-var initialization-complete bool false)

;; Current epoch tracking
(define-data-var current-epoch uint u0)
(define-data-var epoch-start-height uint block-height)

;; Emission tracking per token per epoch
(define-map epoch-emissions
  { token: principal, epoch: uint }
  { minted: uint, supply-at-start: uint })

;; Current emission limits (can be changed via governance)
(define-map token-emission-limits
  principal
  { max-annual-bps: uint, max-single-mint-bps: uint })

;; Pending governance changes
(define-map pending-limit-changes
  principal
  {
    new-annual-bps: uint,
    new-single-mint-bps: uint,
    proposed-at: uint,
    timelock-blocks: uint,
    votes-for: uint,
    votes-against: uint,
    total-voting-power: uint,
    executed: bool
  })

(define-data-var next-proposal-id uint u1)

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-governance-contract (governance principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set governance-contract (some governance))
    (ok true)))

;; --- Token Contract Configuration Functions (Dependency Injection) ---
(define-public (set-cxd-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxd-contract (some contract-address))
    (ok true)))

(define-public (set-cxvg-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxvg-contract (some contract-address))
    (ok true)))

(define-public (set-cxlp-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxlp-contract (some contract-address))
    (ok true)))

(define-public (set-cxtr-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxtr-contract (some contract-address))
    (ok true)))

(define-public (enable-system-integration)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled true)
    (ok true)))

;; Initialize emission limits (staged setup after contract configuration)
(define-public (initialize-emission-limits)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (var-get system-integration-enabled) (err ERR_UNAUTHORIZED))
    
    ;; Set initial limits for configured contracts
    (match (var-get cxd-contract)
      cxd-addr (map-set token-emission-limits cxd-addr
        { max-annual-bps: CXD_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
      true)
    
    (match (var-get cxvg-contract)
      cxvg-addr (map-set token-emission-limits cxvg-addr
        { max-annual-bps: CXVG_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
      true)
    
    (match (var-get cxlp-contract)
      cxlp-addr (map-set token-emission-limits cxlp-addr
        { max-annual-bps: CXLP_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
      true)
    
    (match (var-get cxtr-contract)
      cxtr-addr (map-set token-emission-limits cxtr-addr
        { max-annual-bps: CXTR_MAX_ANNUAL_INFLATION, max-single-mint-bps: MAX_SINGLE_MINT_BPS })
      true)
    
    (var-set initialization-complete true)
    (ok true)))

(define-public (complete-initialization)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (var-get cxd-contract)) (err ERR_INVALID_PARAMETERS))
    (asserts! (is-some (var-get cxvg-contract)) (err ERR_INVALID_PARAMETERS))
    (try! (initialize-emission-limits))
    (ok true)))

;; --- Emission Control Functions ---

;; Check if new epoch should start
(define-private (maybe-advance-epoch)
  (let ((current-epoch-num (var-get current-epoch))
        (epoch-start (var-get epoch-start-height)))
    (if (>= (- block-height epoch-start) EPOCH_BLOCKS)
      (begin
        (var-set current-epoch (+ current-epoch-num u1))
        (var-set epoch-start-height block-height)
        true)
      false)))

;; Get current token supply
(define-private (get-token-supply (token-contract principal))
  (match (var-get cxd-contract)
    cxd-addr (if (is-eq token-contract cxd-addr) u1000000000
      (match (var-get cxvg-contract)
        cxvg-addr (if (is-eq token-contract cxvg-addr) u500000000
          (match (var-get cxlp-contract)
            cxlp-addr (if (is-eq token-contract cxlp-addr) u200000000
              (match (var-get cxtr-contract)
                cxtr-addr (if (is-eq token-contract cxtr-addr) u100000000 u0)
                u0))
            u0))
        u0))
    u0))

;; Authorized mint with emission controls
<<<<<<< Updated upstream
(define-public (controlled-mint (token-contract <ft-mintable-trait>) (recipient principal) (amount uint))
=======
(define-public (controlled-mint (token-contract <sip-010-ft-mintable-trait>) (recipient principal) (amount uint))
>>>>>>> Stashed changes
  (let ((token-principal (contract-of token-contract))
        (current-epoch-num (var-get current-epoch)))
    (begin
      ;; Only governance or owner can mint
      (asserts! (or (is-eq tx-sender (var-get contract-owner))
                   (is-some (var-get governance-contract)))
               (err ERR_UNAUTHORIZED))
      
      ;; Validate token is supported
      (let ((limits (unwrap! (map-get? token-emission-limits token-principal) (err ERR_INVALID_TOKEN))))
        
        ;; Advance epoch if needed
        (maybe-advance-epoch)
        
        ;; Get current supply and epoch data
        (let ((current-supply (get-token-supply token-principal))
              (epoch-data (default-to { minted: u0, supply-at-start: current-supply }
                                     (map-get? epoch-emissions { token: token-principal, epoch: current-epoch-num })))
              (annual-cap (/ (* (get supply-at-start epoch-data) (get max-annual-bps limits)) u10000))
              (single-mint-cap (/ (* current-supply (get max-single-mint-bps limits)) u10000)))
          
          ;; Check single mint limit
          (asserts! (<= amount single-mint-cap) (err ERR_SINGLE_MINT_TOO_LARGE))
          
          ;; Check annual emission cap
          (asserts! (<= (+ (get minted epoch-data) amount) annual-cap) (err ERR_EMISSION_CAP_EXCEEDED))
          
          ;; Execute mint
          (try! (as-contract (contract-call? token-contract mint amount recipient)))
          
          ;; Update epoch emissions
          (map-set epoch-emissions { token: token-principal, epoch: current-epoch-num }
            {
              minted: (+ (get minted epoch-data) amount),
              supply-at-start: (get supply-at-start epoch-data)
            })
          
          (ok { amount: amount, epoch: current-epoch-num, remaining-cap: (- annual-cap (+ (get minted epoch-data) amount)) }))))))

;; --- Governance Functions ---

;; Propose emission limit changes (requires governance)
(define-public (propose-limit-change (token-contract principal) (new-annual-bps uint) (new-single-mint-bps uint) (is-emergency bool))
  (let ((governance (unwrap! (var-get governance-contract) (err ERR_UNAUTHORIZED)))
        (timelock (if is-emergency EMERGENCY_TIMELOCK TIMELOCK_BLOCKS)))
    (begin
      (asserts! (is-eq tx-sender governance) (err ERR_UNAUTHORIZED))
      (asserts! (and (<= new-annual-bps u20000) (<= new-single-mint-bps u1000)) (err ERR_INVALID_PARAMETERS))
      
      ;; Store pending change
      (map-set pending-limit-changes token-contract
        {
          new-annual-bps: new-annual-bps,
          new-single-mint-bps: new-single-mint-bps,
          proposed-at: block-height,
          timelock-blocks: timelock,
          votes-for: u0,
          votes-against: u0,
          total-voting-power: u0,
          executed: false
        })
      
      (ok true))))

;; Vote on emission limit changes (called by CXVG utility contract)
(define-public (vote-on-limit-change (token-contract principal) (support bool) (voting-power uint))
  (match (map-get? pending-limit-changes token-contract)
    change-info
    (begin
      (asserts! (not (get executed change-info)) (err ERR_NO_PENDING_CHANGE))
      
      (let ((updated-info
              (if support
                (merge change-info
                  { votes-for: (+ (get votes-for change-info) voting-power),
                   total-voting-power: (+ (get total-voting-power change-info) voting-power) })
                (merge change-info
                  { votes-against: (+ (get votes-against change-info) voting-power),
                   total-voting-power: (+ (get total-voting-power change-info) voting-power) }))))
        
        (map-set pending-limit-changes token-contract updated-info)
        (ok true)))
    (err ERR_NO_PENDING_CHANGE)))

;; Execute emission limit change after timelock and supermajority
(define-public (execute-limit-change (token-contract principal))
  (match (map-get? pending-limit-changes token-contract)
    change-info
    (begin
      (asserts! (not (get executed change-info)) (err ERR_NO_PENDING_CHANGE))
      (asserts! (>= block-height (+ (get proposed-at change-info) (get timelock-blocks change-info))) (err ERR_TIMELOCK_NOT_ELAPSED))
      
      ;; Check supermajority requirement
      (let ((support-ratio (if (> (get total-voting-power change-info) u0)
                            (/ (* (get votes-for change-info) u10000) (get total-voting-power change-info))
                            u0)))
        (asserts! (>= support-ratio SUPERMAJORITY_THRESHOLD) (err ERR_GOVERNANCE_THRESHOLD_NOT_MET))
        
        ;; Update emission limits
        (map-set token-emission-limits token-contract
          {
            max-annual-bps: (get new-annual-bps change-info),
            max-single-mint-bps: (get new-single-mint-bps change-info)
          })
        
        ;; Mark as executed
        (map-set pending-limit-changes token-contract
          (merge change-info { executed: true }))
        
        (ok true)))
    (err ERR_NO_PENDING_CHANGE)))

;; --- Emergency Functions ---

;; Emergency reduction of emission limits (no voting required, shorter timelock)
(define-public (emergency-reduce-limits (token-contract principal) (new-annual-bps uint) (new-single-mint-bps uint))
  (let ((current-limits (unwrap! (map-get? token-emission-limits token-contract) (err ERR_INVALID_TOKEN))))
    (begin
      (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
      
      ;; Can only reduce, not increase
      (asserts! (and (<= new-annual-bps (get max-annual-bps current-limits))
                     (<= new-single-mint-bps (get max-single-mint-bps current-limits)))
               (err ERR_INVALID_AMOUNT))

      ;; Update the limits immediately (emergency)
      (map-set token-emission-limits token-contract
        (merge current-limits {
          max-annual-bps: new-annual-bps,
          max-single-mint-bps: new-single-mint-bps,
          last-updated: block-height
        }))

      (print {
        event: "emergency-limits-reduced",
        token: token-contract,
        new-annual-bps: new-annual-bps,
        new-single-mint-bps: new-single-mint-bps
      })

      (ok true)
    )
  )
)