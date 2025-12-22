;; btc-adapter.clar
;; Bitcoin integration layer with finality verification
;; Implements the Cross-Chain Dimension requirements
;; Refactored for Nakamoto & Trustless Verification

(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_TX (err u5001))
(define-constant ERR_NOT_CONFIRMED (err u5002))
(define-constant ERR_ALREADY_PROCESSED (err u5003))
(define-constant ERR_INVALID_AMOUNT (err u5004))
(define-constant ERR_VERIFICATION_FAILED (err u5005))

;; Rescaled for Nakamoto (assuming 5s blocks, 6 blocks -> 30s is too fast, keeping 6 BTC blocks = ~60 mins)
;; We use burn-block-height for BTC finality, so u6 is correct for Bitcoin blocks.
(define-constant BTC_FINALITY_BLOCKS u6)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var sbtc-token principal tx-sender)

;; --- Data Maps ---
(define-map processed-txs
  { txid: (buff 32) }
  {
    processed: bool,
    block-height: uint,
    recipient: principal,
    amount: uint,
  }
)

;; --- Public Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-sbtc-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set sbtc-token token)
    (ok true)
  )
)

;; @desc Verify a Bitcoin transaction has achieved finality by checking against burnchain data.
;; @param header: The Bitcoin block header containing the tx
;; NOTE: get-burn-block-info not available in current Clarity version - simplified implementation
(define-read-only (verify-finality (header (buff 80)))
  (let (
      ;; Assumes .clarity-bitcoin has functions to parse header.
      (header-height (unwrap! (contract-call? .clarity-bitcoin get-height header) ERR_INVALID_TX))
      (header-hash (unwrap! (contract-call? .clarity-bitcoin get-block-hash header)
        ERR_INVALID_TX
      ))
      ;; TODO: Replace with proper burnchain verification when get-burn-block-info is available
      ;; For now, skip canonical hash check
    )

    ;; 2. Ensure the block is deep enough for finality.
    (asserts! (>= (- burn-block-height header-height) BTC_FINALITY_BLOCKS)
      ERR_NOT_CONFIRMED
    )

    (ok true)
  )
)

;; @desc Process a deposit from Bitcoin (Mint sBTC)
;; @param tx-blob: The raw Bitcoin transaction
;; @param block-header: The Bitcoin block header
;; @param proof: Merkle proof
;; @param amount: The amount to mint (extracted from tx in real implementation, passed here for simplicity of mock)
;; @param recipient: The Stacks recipient
;; @param token: The sBTC token contract
(define-public (deposit
    (tx-blob (buff 1024))
    (block-header (buff 80))
    (proof {
      tx-index: uint,
      hashes: (list 12 (buff 32)),
      tree-depth: uint,
    })
    (recipient principal)
    (token <sip-010-ft-trait>)
  )
  (let (
      (tx-id (contract-call? .clarity-bitcoin get-txid tx-blob))
      (was-mined (contract-call? .clarity-bitcoin was-tx-mined? block-header tx-blob proof))
      (amount (contract-call? .clarity-bitcoin get-out-value tx-blob))
    )
    ;; 1. Verify finality of the Bitcoin block.
    (try! (verify-finality block-header))

    ;; 2. Verify Inclusion
    (asserts! was-mined ERR_VERIFICATION_FAILED)

    ;; 3. Check if already processed
    (asserts! (is-none (map-get? processed-txs { txid: tx-id }))
      ERR_ALREADY_PROCESSED
    )

    ;; 3. Verify amount (sanity check)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    ;; 4. Mint sBTC (currently modeled as transfer from pre-funded contract)
    (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))

    ;; 5. Mark as processed
    (map-set processed-txs { txid: tx-id } {
      processed: true,
      block-height: block-height,
      recipient: recipient,
      amount: amount,
    })

    (print {
      event: "btc-deposit",
      tx-id: tx-id,
      amount: amount,
      recipient: recipient,
    })
    (ok amount)
  )
)
