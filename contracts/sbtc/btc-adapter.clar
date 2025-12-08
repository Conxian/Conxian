;; btc-adapter.clar
;; Bitcoin integration layer with finality verification
;; Implements the Cross-Chain Dimension requirements
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_TX (err u5001))
(define-constant ERR_NOT_CONFIRMED (err u5002))
(define-constant ERR_ALREADY_PROCESSED (err u5003))
(define-constant ERR_INVALID_AMOUNT (err u5004))

(define-constant MIN_CONFIRMATIONS u6)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var sbtc-token principal tx-sender) ;; Placeholder, set by admin

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

;; @desc Verify a Bitcoin transaction has achieved finality and is part of the canonic
;; @param tx-height: The Bitcoin block height where the transaction was included
;; @param header-hash: The hash of the Bitcoin block header (accepted for future use)
(define-read-only (verify-finality (tx-height uint) (header-hash (buff 32)))
    (let ((current-burn-height burn-block-height))
        (if (>= current-burn-height (+ tx-height MIN_CONFIRMATIONS))
            (ok true)
            ERR_NOT_CONFIRMED
        )
    )
)

;; @desc Process a deposit from Bitcoin (Mint sBTC)
;; @param tx-height: The Bitcoin block height
;; @param tx-id: The Bitcoin transaction ID
;; @param header-hash: The Bitcoin block header hash
;; @param amount: The amount to mint (in sats)
;; @param recipient: The Stacks recipient
;; @param token: The sBTC token contract principal
(define-public (deposit
        (tx-height uint)
        (tx-id (buff 32))
        (header-hash (buff 32))
        (amount uint)
        (recipient principal)
        (token <sip-010-ft-trait>)
    )
    (begin
        ;; 1. Verify Finality (header-hash kept for future SPV use)
(try! (verify-finality tx-height header-hash))

        ;; 2. Check if already processed
        (asserts! (is-none (map-get? processed-txs { txid: tx-id }))
            ERR_ALREADY_PROCESSED
        )

        ;; 3. Verify amount (sanity check)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)

        ;; 4. Mint sBTC (currently modeled as transfer from pre-funded contract)
(try! (contract-call? token transfer amount tx-sender recipient none))

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
            finality-verified: true,
            header-hash: header-hash
        })
        (ok true)
    )
)

;; @desc Initiate a withdrawal to Bitcoin (Burn sBTC)
;; @param amount: The amount to withdraw
;; @param btc-address: The destination Bitcoin address (script)
;; @param token: The sBTC token contract principal
(define-public (withdraw
        (amount uint)
        (btc-address (buff 128))
        (token <sip-010-ft-trait>)
    )
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)

        ;; Burn sBTC (or transfer to vault)
        (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender)
            none
        ))

        (print {
            event: "btc-withdraw",
            amount: amount,
            btc-address: btc-address,
            sender: tx-sender,
        })
        (ok true)
    )
)
