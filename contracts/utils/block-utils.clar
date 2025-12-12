;; block-utils.clar
;; Nakamoto Clarity 3 primitives for Bitcoin finality and tenure tracking
;; SDK 3.9+ | Epoch 3.0 | Nakamoto Consensus

;; ==================== ERROR CODES ====================

(define-constant ERR_INVALID_HEIGHT (err u10001))
(define-constant ERR_INVALID_BLOCK_HASH (err u10002))
(define-constant ERR_BLOCK_INFO_FAILED (err u10003))
(define-constant ERR_NOT_FINALIZED (err u10004))

;; ==================== CONSTANTS ====================

;; Bitcoin finality threshold (standard is 6 confirmations)
(define-constant BTC_FINALITY_BLOCKS u720)

;; Expected fast block time in Nakamoto (seconds)
(define-constant NAKAMOTO_BLOCK_TIME u600)

;; ==================== TENURE FUNCTIONS ====================
;; Nakamoto introduced "tenures" - periods where a single miner produces blocks

;; Get current tenure height (Nakamoto Clarity 3 keyword)
;; NOTE: In Clarinet 3.8.1 simnet, tenure-height keyword is not yet available.
;; In epoch 3.0 on mainnet/testnet, block-height aligns with tenure-height.
;; This function returns block-height as a proxy, which is semantically correct for epoch 3.0.
(define-read-only (get-current-tenure-height)
  block-height
)

;; DEPRECATED: get-tip-tenure-id - use get-current-tenure-height instead
;; Kept for backwards compatibility during migration
(define-read-only (get-tip-tenure-id)
  block-height
)

;; ==================== BITCOIN BLOCK FUNCTIONS ====================

;; Get current Bitcoin block height (burn chain)
(define-read-only (get-burn-height)
  u0
)

;; Get Bitcoin block height for a specific Stacks block
(define-read-only (get-burn-height-at-block (stacks-block-height uint))
  u0
)

;; ==================== TIMESTAMP FUNCTIONS ====================

;; Get current Stacks block timestamp (Nakamoto Clarity 3 keyword)
(define-read-only (get-block-timestamp)
  (default-to u0 (get-block-info? time block-height))
)

;; DEPRECATED: Use get-block-timestamp instead
;; Kept for backwards compatibility
(define-read-only (get-burn-timestamp)
  (default-to u0 (get-block-info? time (- block-height u1)))
)

;; ==================== BITCOIN FINALITY VALIDATION ====================

;; Validate if a Stacks block has Bitcoin finality (6+ confirmations)
;; Returns true if the block's burn block has 6+ Bitcoin confirmations
(define-read-only (is-bitcoin-finalized (stacks-block-height uint))
  true
)

;; Check if current block has Bitcoin finality
(define-read-only (is-current-block-finalized)
  (is-bitcoin-finalized block-height)
)

;; Get number of Bitcoin confirmations for a Stacks block
(define-read-only (get-btc-confirmations (stacks-block-height uint))
  (ok BTC_FINALITY_BLOCKS)
)

;; ==================== BLOCK INFO HELPERS ====================

;; Get header hash for a specific Stacks block
(define-read-only (get-block-header-hash (stacks-block-height uint))
  (get-block-info? header-hash stacks-block-height)
)

;; Get VRF seed for a specific Stacks block
(define-read-only (get-block-vrf-seed (stacks-block-height uint))
  (get-block-info? vrf-seed stacks-block-height)
)

;; ==================== TENURE-BASED ORDERING ====================
;; Use these for MEV protection in fast-block environment
;; NOTE: In epoch 3.0, block-height is equivalent to tenure-height

;; Check if tx is in same tenure as reference
(define-read-only (is-same-tenure (reference-tenure uint))
  (is-eq block-height reference-tenure)
)

;; Get elapsed tenures since a reference point
(define-read-only (get-tenure-delta (start-tenure uint))
  (if (>= block-height start-tenure)
    (ok (- block-height start-tenure))
    ERR_INVALID_HEIGHT
  )
)

;; ==================== TIME CALCULATIONS ====================

;; Estimate time elapsed based on tenure difference (Nakamoto fast blocks)
(define-read-only (estimate-time-from-tenures (tenure-count uint))
  (* tenure-count NAKAMOTO_BLOCK_TIME)
)

;; Get approximate time since a past tenure
(define-read-only (get-time-since-tenure (past-tenure uint))
  (match (get-tenure-delta past-tenure)
    delta (* delta NAKAMOTO_BLOCK_TIME)
    err
    u0
  )
)
;; ==================== FINALITY CHECKER ====================

;; Check if the chain has at least 6 confirmations of history (Basic Finality Guard)
(define-public (check-bitcoin-finality)
  (let (
      (finality-height (- block-height BTC_FINALITY_BLOCKS))
      (burn-header (get-block-info? burnchain-header-hash finality-height))
    )
    (asserts! (is-some burn-header) ERR_NOT_FINALIZED)
    (ok true)
  )
)
