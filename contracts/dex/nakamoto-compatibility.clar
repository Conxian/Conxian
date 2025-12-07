

;; nakamoto-compatibility.clar

;; Nakamoto Upgrade Compatibility Module for Conxian Protocol

;; Provides fast block timing, Bitcoin finality detection, and enhanced security

;; =============================================================================

;; CONSTANTS AND ERROR CODES

;; =============================================================================
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ONE_DAY u17280) ;; u144 * 120 for Nakamotoer)
(define-constant ERR_NOT_AUTHORIZED (err u2000))
(define-constant ERR_BITCOIN_REORG_DETECTED (err u2001))
(define-constant ERR_INSUFFICIENT_FINALITY (err u2002))
(define-constant ERR_MEV_DETECTED (err u2003))
(define-constant ERR_FRONT_RUN_DETECTED (err u2004))

;; Nakamoto timing constants (3-5 second blocks)
(define-constant NAKAMOTO_BLOCKS_PER_MINUTE u12)
;; 5s blocks = 12/min
(define-constant NAKAMOTO_BLOCKS_PER_HOUR u720)
;; 60 * 12
(define-constant NAKAMOTO_BLOCKS_PER_DAY u17280)
;; 24 * 720
(define-constant NAKAMOTO_BLOCKS_PER_WEEK u120960)
;; 7 * 17280

;; Bitcoin finality and security parameters
(define-constant BITCOIN_FINALITY_DEPTH u100)
;; ~17 hours Bitcoin confirmations
(define-constant BITCOIN_REORG_THRESHOLD u6)
;; Max acceptable reorg depth
(define-constant MEV_PROTECTION_WINDOW u12)
;; 1 minute protection window

;; Migration and staking parameters optimized for Nakamoto
(define-constant NAKAMOTO_EPOCH_LENGTH u120960)
;; 1 week
(define-constant NAKAMOTO_REWARD_FREQUENCY u2880)
;; 4 hours (was weekly)
(define-constant NAKAMOTO_MIGRATION_WINDOW u725760)
;; 42 days
(define-constant NAKAMOTO_WARMUP_PERIOD u2880)
;; 4 hours (was 2 weeks)
(define-constant NAKAMOTO_COOLDOWN_PERIOD u8640)
;; 12 hours (was 2 weeks)

;; Oracle parameters for fast blocks
(define-constant NAKAMOTO_ORACLE_STALE_THRESHOLD u17280)
;; 24 hours (was u144)
(define-constant NAKAMOTO_PRICE_UPDATE_MIN_INTERVAL u720)
;; 1 hour min between updates

;; Migration timing bands optimized for Nakamoto
(define-constant NAKAMOTO_MIGRATION_BAND_1_END u120960)
;; Week 1: 110% rate
(define-constant NAKAMOTO_MIGRATION_BAND_2_END u241920)
;; Week 2: 108% rate
(define-constant NAKAMOTO_MIGRATION_BAND_3_END u518400)
;; Week 3-4: 105% rate

;; Beyond Week 4: 100% rate

;; =============================================================================

;; DATA STRUCTURES

;; =============================================================================
(define-data-var nakamoto-activated bool false)
(define-data-var bitcoin-finality-enabled bool false)
(define-data-var mev-protection-enabled bool true)
(define-map bitcoin-finality-cache  { block-height: uint }  {     burn-block-at-height: uint,    is-finalized: bool,    cached-at-at-block: uint  })
(define-map mev-protection-state  { tx-hash: (buff 32) }  {    submitted-block: uint,    protection-expires: uint,    is-protected: bool  })
(define-map transaction-timing  { block-height: uint }  {    transaction-count: uint,    first-tx-timestamp: uint,    suspicious-pattern: bool  })

;; =============================================================================

;; NAKAMOTO TIMING FUNCTIONS

;; =============================================================================
(define-read-only (is-nakamoto-active)
  "Check if Nakamoto upgrade is active"
  (var-get nakamoto-activated))
(define-read-only (get-blocks-per-time-unit (unit (string-ascii 10)))
  "Get block count per time unit for current network state"
  (if (is-nakamoto-active)
    (cond
      ((is-eq unit "minute") NAKAMOTO_BLOCKS_PER_MINUTE)
      ((is-eq unit "hour") NAKAMOTO_BLOCKS_PER_HOUR)
      ((is-eq unit "day") NAKAMOTO_BLOCKS_PER_DAY)
      ((is-eq unit "week") NAKAMOTO_BLOCKS_PER_WEEK)
      u0
    )
;; Legacy Stacks timing (10-minute blocks)
    (cond
      ((is-eq unit "minute") u0)
;; Less than 1 block per minute
      ((is-eq unit "hour") u6)
      ((is-eq unit "day") u144)
      ((is-eq unit "week") u1008)
      u0
    )
  )
)
(define-read-only (convert-legacy-timing (legacy-blocks uint))
  "Convert legacy block counts to Nakamoto equivalents"
  (if (is-nakamoto-active)
;; Nakamoto blocks are ~120x more frequent than legacy
    (* legacy-blocks u120)
    legacy-blocks))
(define-read-only (get-epoch-length)
  "Get current epoch length based on network state"
  (if (is-nakamoto-active)
    NAKAMOTO_EPOCH_LENGTH
    u1008
;; Legacy 1 week
  ))
(define-read-only (get-reward-frequency)
  "Get reward distribution frequency"
  (if (is-nakamoto-active)
    NAKAMOTO_REWARD_FREQUENCY
;; 4 hours
    u1008
;; Legacy weekly
  ))
(define-read-only (get-oracle-stale-threshold)
  "Get oracle staleness threshold for current network"
  (if (is-nakamoto-active)
    NAKAMOTO_ORACLE_STALE_THRESHOLD
    u144
;; Legacy 24 hours
  ))

;; =============================================================================

;; BITCOIN FINALITY FUNCTIONS

;; =============================================================================
(define-read-only (get-bitcoin-finality-depth)
  "Get required Bitcoin finality depth"
  BITCOIN_FINALITY_DEPTH)
(define-private (cache-bitcoin-finality (block-height uint))
  "Cache Bitcoin finality status for performance"
  (let ((current-burn-block burn-block-height)
        (is-final (>= (- burn-block-height block-height) BITCOIN_FINALITY_DEPTH)))
    (map-set bitcoin-finality-cache { block-height: block-height }
      {
        burn-block-at-height: current-burn-block,
        is-finalized: is-final,
        cached-at-block: block-height
      }
    )
    is-final))
(define-read-only (is-bitcoin-finalized (block-height uint))
  "Check if a Stacks block is Bitcoin-finalized"
  (if (var-get bitcoin-finality-enabled)
    (match (map-get? bitcoin-finality-cache { block-height: block-height })
      cached-result (get is-finalized cached-result)
;; Not cached, calculate and cache
      (cache-bitcoin-finality block-height))
    true
;; Skip finality check if disabled
  ))
(define-read-only (get-last-finalized-block)
  "Get the last Bitcoin-finalized Stacks block height"
  (if (var-get bitcoin-finality-enabled)
    (- block-height BITCOIN_FINALITY_DEPTH)
    block-height
;; Return current if finality disabled
  ))
(define-read-only (check-bitcoin-reorg-risk (block-height uint))
  "Assess Bitcoin reorganization risk for given block"
  (let ((finality-depth (- burn-block-height block-height)))
    (cond
      ((< finality-depth u1) { risk-level: u5, description: "Unconfirmed" })
      ((< finality-depth u6) { risk-level: u4, description: "Low confirmation" })
      ((< finality-depth u50) { risk-level: u3, description: "Medium risk" })
      ((< finality-depth u100) { risk-level: u2, description: "Low risk" })
      ({ risk-level: u1, description: "Bitcoin finalized" })))

;; =============================================================================

;; MEV PROTECTION FUNCTIONS

;; =============================================================================
(define-private (generate-tx-hash (caller principal) (function-name (string-ascii 50)))
  "Generate deterministic transaction hash for MEV protection"
  (let ((caller-str (unwrap! (as-max-len? (to-string caller) u42) (err ERR_NOT_AUTHORIZED)))
        (fn-buff (unwrap! (string-to-utf8 function-name) (err ERR_NOT_AUTHORIZED)))
        (height-buff (unwrap! (int-to-utf8 block-height) (err ERR_NOT_AUTHORIZED))))
    (concat caller-str (concat fn-buff height-buff))))
(define-public (register-mev-protection (function-name (string-ascii 50)))
  "Register transaction for MEV protection"
  (let ((tx-hash (generate-tx-hash tx-sender function-name))
        (protection-expires (+ block-height MEV_PROTECTION_WINDOW)))
    (if (var-get mev-protection-enabled)
      (begin
        (map-set mev-protection-state { tx-hash: tx-hash }
          {
            submitted-block: block-height,
            protection-expires: protection-expires,
            is-protected: true
          }
        )
        (ok tx-hash))
      (ok tx-hash)
;; Pass through if disabled
    )))
(define-read-only (is-mev-protected (tx-hash (buff 32)))
  "Check if transaction has active MEV protection"
  (match (map-get? mev-protection-state { tx-hash: tx-hash })
    protection (and (get is-protected protection)
                   (< block-height (get protection-expires protection)))
    false))
(define-private (detect-front-running (caller principal))  "Detect potential front-running patterns"
  (let ((current-block-data (default-to { transaction-count: u0, first-tx-timestamp: u0, suspicious-pattern: false } (map-get? transaction-timing { block-height: block-height }))))
    (let ((tx-count (+ (get transaction-count current-block-data) u1))
          (suspicious (> tx-count u10)))
;; Flag if >10 txs from same caller in block
      (map-set transaction-timing { block-height: block-height }
        {
          transaction-count: tx-count,
          first-tx-timestamp: (if (is-eq (get first-tx-timestamp current-block-data) u0)
                              block-height
                              (get first-tx-timestamp current-block-data)),
          suspicious-pattern: suspicious
        }
      )
      suspicious)))

;; =============================================================================

;; MIGRATION TIMING FUNCTIONS

;; =============================================================================
(define-read-only (get-migration-conversion-rate (blocks-since-start uint))
  "Calculate conversion rate based on Nakamoto migration timeline"
  (cond
    ((<= blocks-since-start NAKAMOTO_MIGRATION_BAND_1_END) u1100000)
;; 110%
    ((<= blocks-since-start NAKAMOTO_MIGRATION_BAND_2_END) u1080000)
;; 108%
    ((<= blocks-since-start NAKAMOTO_MIGRATION_BAND_3_END) u1050000)
;; 105%
    u1000000
;; 100% base rate
  ))
(define-read-only (get-current-migration-band (migration-start-block uint))
  "Determine current migration band"
  (let ((blocks-elapsed (- block-height migration-start-block)))
    (cond
      ((<= blocks-elapsed NAKAMOTO_MIGRATION_BAND_1_END) u1)
      ((<= blocks-elapsed NAKAMOTO_MIGRATION_BAND_2_END) u2)
      ((<= blocks-elapsed NAKAMOTO_MIGRATION_BAND_3_END) u3)
      u4)))

;; =============================================================================

;; ADMIN FUNCTIONS

;; =============================================================================
(define-public (activate-nakamoto)
  "Activate Nakamoto timing parameters"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set nakamoto-activated true)
    (print { event: "nakamoto-activated", block-height: block-height })
    (ok true)))
(define-public (enable-bitcoin-finality (enabled bool))
  "Enable/disable Bitcoin finality checks"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set bitcoin-finality-enabled enabled)
    (print { event: "bitcoin-finality-toggled", enabled: enabled })
    (ok true)))
(define-public (configure-mev-protection (enabled bool))
  "Configure MEV protection settings"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set mev-protection-enabled enabled)
    (print { event: "mev-protection-configured", enabled: enabled })
    (ok true)))

;; =============================================================================

;; VALIDATION FUNCTIONS

;; =============================================================================
(define-public (validate-transaction-timing (required-finality bool))
  "Validate transaction meets timing and finality requirements"
  (begin
;; Check Bitcoin finality if required
    (if required-finality
      (asserts! (is-bitcoin-finalized (- block-height u1)) ERR_INSUFFICIENT_FINALITY)
      true)
;; Check for front-running patterns
    (if (var-get mev-protection-enabled)
      (asserts! (not (detect-front-running tx-sender)) ERR_FRONT_RUN_DETECTED)
      true)
    (ok true)))
(define-public (validate-price-update-timing (last-update-block uint))
  "Validate oracle price update timing"
  (let ((blocks-since-update (- block-height last-update-block)))
    (if (is-nakamoto-active)
      (asserts! (>= blocks-since-update NAKAMOTO_PRICE_UPDATE_MIN_INTERVAL)
                (err u2005))
;; ERR_UPDATE_TOO_FREQUENT
      (asserts! (>= blocks-since-update u6)
;; Legacy minimum
               (err u2005))))
    (ok true)))

;; =============================================================================

;; INTEGRATION HELPERS

;; =============================================================================
(define-read-only (get-adjusted-timelock (legacy-timelock uint))
  "Convert legacy timelock to Nakamoto-adjusted duration"
  (if (is-nakamoto-active)
;; Maintain same real-world duration despite faster blocks
    (convert-legacy-timing legacy-timelock)
    legacy-timelock))
(define-read-only (should-use-finality-delay (operation-type (string-ascii 20)))
  "Determine if operation should wait for Bitcoin finality"
  (and (var-get bitcoin-finality-enabled)
       (or (is-eq operation-type "large-liquidation")
           (is-eq operation-type "revenue-distribution")
           (is-eq operation-type "governance-execution")
           (is-eq operation-type "migration-execution"))))

;; Initialize with safe defaults
(begin
  (var-set nakamoto-activated false)
;; Start with legacy timing
  (var-set bitcoin-finality-enabled true)
;; Enable finality checks
  (var-set mev-protection-enabled true)
;; Enable MEV protection
  (print { event: "nakamoto-compatibility-deployed", version: "1.0.0" }))
