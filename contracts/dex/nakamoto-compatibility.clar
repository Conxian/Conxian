;; nakamoto-compatibility.clar
;; Nakamoto Upgrade Compatibility Module for Conxian Protocol
;; Provides fast block timing, Bitcoin finality detection, and enhanced security

;; 
;; CONSTANTS AND ERROR CODES
;; 

(define-constant ERR_NOT_AUTHORIZED (err u2000))
(define-constant ERR_BITCOIN_REORG_DETECTED (err u2001))
(define-constant ERR_INSUFFICIENT_FINALITY (err u2002))
(define-constant ERR_MEV_DETECTED (err u2003))
(define-constant ERR_FRONT_RUN_DETECTED (err u2004))
(define-constant ERR_PRICE_UPDATE_TOO_SOON (err u2005))

;; Nakamoto timing constants (3-5 second blocks)
(define-constant NAKAMOTO_BLOCKS_PER_MINUTE u12)        ;; 5s blocks = 12/min
(define-constant NAKAMOTO_BLOCKS_PER_HOUR u720)         ;; 60 * 12
(define-constant NAKAMOTO_BLOCKS_PER_WEEK u120960)      ;; 7 * 17280

;; Bitcoin finality and security parameters
(define-constant BITCOIN_FINALITY_DEPTH u100)           ;; ~17 hours Bitcoin confirmations
(define-constant BITCOIN_REORG_THRESHOLD u6)            ;; Max acceptable reorg depth
(define-constant MEV_PROTECTION_WINDOW u12)             ;; 1 minute protection window

;; Migration and staking parameters optimized for Nakamoto
(define-constant NAKAMOTO_EPOCH_LENGTH u120960)         ;; 1 week
(define-constant NAKAMOTO_REWARD_FREQUENCY u2880)       ;; 4 hours (was weekly)
(define-constant NAKAMOTO_MIGRATION_WINDOW u725760)     ;; 42 days
(define-constant NAKAMOTO_WARMUP_PERIOD u2880)          ;; 4 hours (was 2 weeks)
(define-constant NAKAMOTO_COOLDOWN_PERIOD u8640)        ;; 12 hours (was 2 weeks)

;; Oracle parameters for fast blocks
(define-constant NAKAMOTO_ORACLE_STALE_THRESHOLD u17280)  ;; 24 hours (was u144)
(define-constant NAKAMOTO_PRICE_UPDATE_MIN_INTERVAL u720) ;; 1 hour min between updates

;; Migration timing bands optimized for Nakamoto
(define-constant NAKAMOTO_MIGRATION_BAND_1_END u120960)  ;; Week 1: 110% rate
(define-constant NAKAMOTO_MIGRATION_BAND_2_END u241920)  ;; Week 2: 108% rate
(define-constant NAKAMOTO_MIGRATION_BAND_3_END u518400)  ;; Week 3-4: 105% rate

;; 
;; STATE
;; 

(define-data-var contract-owner principal 'SP000000000000000000002Q6VF78)
(define-data-var nakamoto-activated bool false)
(define-data-var bitcoin-finality-enabled bool false)
(define-data-var mev-protection-enabled bool true)

(define-map bitcoin-finality-cache
  { block-height: uint }
  {
    burn-block-at-height: uint,
    is-finalized: bool,
    cached-at-block: uint
  }
)

;; Track potential MEV/front-running per caller per block
(define-map transaction-timing
  { block-height: uint, caller: principal }
  {
    transaction-count: uint,
    first-seen-block: uint,
    suspicious-pattern: bool
  }
)

;; 
;; HELPERS
;; 

(define-private (only-owner)
  (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
)

(define-read-only (is-nakamoto-active)
  (var-get nakamoto-activated)
)

;; 
;; NAKAMOTO TIMING FUNCTIONS
;; 

(define-read-only (get-blocks-per-time-unit (unit (string-ascii 10)))
  (if (is-nakamoto-active)
      (cond
        ((is-eq unit "minute") NAKAMOTO_BLOCKS_PER_MINUTE)
        ((is-eq unit "hour")   NAKAMOTO_BLOCKS_PER_HOUR)
        ((is-eq unit "day")    NAKAMOTO_BLOCKS_PER_DAY)
        ((is-eq unit "week")   NAKAMOTO_BLOCKS_PER_WEEK)
        u0
      )
      ;; Legacy Stacks timing (~10-minute blocks)
      (cond
        ((is-eq unit "minute") u0)     ;; Less than 1 block per minute
        ((is-eq unit "hour")   u6)
        ((is-eq unit "day")    u144)
        ((is-eq unit "week")   u1008)
        u0
      )
  )
)

(define-read-only (convert-legacy-timing (legacy-blocks uint))
  (if (is-nakamoto-active)
      (* legacy-blocks u120)     ;; Nakamoto blocks are ~120x more frequent
      legacy-blocks
  )
)

(define-read-only (get-epoch-length)
  (if (is-nakamoto-active) NAKAMOTO_EPOCH_LENGTH u1008)  ;; Legacy ~1 week
)

(define-read-only (get-reward-frequency)
  (if (is-nakamoto-active) NAKAMOTO_REWARD_FREQUENCY u1008)  ;; Legacy weekly
)

(define-read-only (get-oracle-stale-threshold)
  (if (is-nakamoto-active) NAKAMOTO_ORACLE_STALE_THRESHOLD u144) ;; Legacy 24h
)

;; 
;; BITCOIN FINALITY FUNCTIONS
;; 

(define-read-only (get-bitcoin-finality-depth)
  BITCOIN_FINALITY_DEPTH
)

(define-private (cache-bitcoin-finality (s-block-height uint))
  (let (
        (current-burn-height burn-block-height)
        (is-final (>= (- burn-block-height s-block-height) BITCOIN_FINALITY_DEPTH))
       )
    (map-set bitcoin-finality-cache
      { block-height: s-block-height }
      {
        burn-block-at-height: current-burn-height,
        is-finalized: is-final,
        cached-at-block: s-block-height
      }
    )
    is-final
  )
)

(define-read-only (is-bitcoin-finalized (s-block-height uint))
  (if (var-get bitcoin-finality-enabled)
    (>= block-height (+ s-block-height BITCOIN_FINALITY_BLOCKS))
    true))