;; ico-offering.clar
;; Conxian Retail ICO Contract
;;
;; Features:
;; 1. Fixed Price Token Sale
;; 2. Vesting Schedule (Claimable after Cliff)
;; 3. Whitelist Support (KYC/AML)
;; 4. Treasury Forwarding (No funds stored in contract)

(impl-trait .defi-traits.fee-manager-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_SALE_NOT_ACTIVE (err u7001))
(define-constant ERR_BELOW_MIN_BUY (err u7002))
(define-constant ERR_ABOVE_MAX_BUY (err u7003))
(define-constant ERR_NOT_WHITELISTED (err u7004))
(define-constant ERR_NO_TOKENS_TO_CLAIM (err u7005))

(define-constant TOKEN_PRICE_STX u500000) ;; 0.5 STX per Token (u500000 micro-STX)
(define-constant MIN_BUY_STX u50000000)   ;; 50 STX Min
(define-constant MAX_BUY_STX u5000000000) ;; 5000 STX Max

;; --- Data Variables ---
(define-data-var sale-active bool false)
(define-data-var treasury-address principal tx-sender)
(define-data-var token-address principal .governance-token)
(define-data-var total-raised uint u0)
(define-data-var tokens-sold uint u0)

;; Vesting: 10% unlock TGE, 90% linear over 12 months
(define-data-var cliff-block uint u0)
(define-data-var vesting-duration uint u52560) ;; ~1 year

;; --- Maps ---
(define-map whitelist principal bool)
(define-map user-purchases 
    principal 
    {
        stx-spent: uint,
        tokens-bought: uint,
        tokens-claimed: uint,
        last-claim: uint
    }
)

;; --- Admin Functions ---
(define-public (set-sale-active (active bool))
    (begin
        (asserts! (is-eq tx-sender (var-get treasury-address)) ERR_UNAUTHORIZED)
        (var-set sale-active active)
        (ok true)
    )
)

(define-public (add-to-whitelist (users (list 200 principal)))
    (begin
        (asserts! (is-eq tx-sender (var-get treasury-address)) ERR_UNAUTHORIZED)
        (map (lambda (user) (map-set whitelist user true)) users)
        (ok true)
    )
)

(define-public (set-treasury (new-treasury principal))
    (begin
        (asserts! (is-eq tx-sender (var-get treasury-address)) ERR_UNAUTHORIZED)
        (var-set treasury-address new-treasury)
        (ok true)
    )
)

;; --- Public Functions ---

;; @desc Buy tokens with STX
(define-public (buy-tokens (stx-amount uint))
    (let (
        (sender tx-sender)
        (is-whitelisted (default-to false (map-get? whitelist sender)))
        (tokens-to-buy (/ (* stx-amount u1000000) TOKEN_PRICE_STX)) ;; Assumes 6 decimals
        (current-purchase (default-to { stx-spent: u0, tokens-bought: u0, tokens-claimed: u0, last-claim: u0 } (map-get? user-purchases sender)))
    )
        (asserts! (var-get sale-active) ERR_SALE_NOT_ACTIVE)
        (asserts! is-whitelisted ERR_NOT_WHITELISTED)
        (asserts! (>= stx-amount MIN_BUY_STX) ERR_BELOW_MIN_BUY)
        (asserts! (<= (+ stx-amount (get stx-spent current-purchase)) MAX_BUY_STX) ERR_ABOVE_MAX_BUY)

        ;; 1. Transfer STX to Treasury
        (try! (stx-transfer? stx-amount sender (var-get treasury-address)))

        ;; 2. Record Purchase (Tokens are virtual until claimed)
        (map-set user-purchases sender {
            stx-spent: (+ (get stx-spent current-purchase) stx-amount),
            tokens-bought: (+ (get tokens-bought current-purchase) tokens-to-buy),
            tokens-claimed: (get tokens-claimed current-purchase),
            last-claim: (get last-claim current-purchase)
        })

        (var-set total-raised (+ (var-get total-raised) stx-amount))
        (var-set tokens-sold (+ (var-get tokens-sold) tokens-to-buy))

        (print { event: "ico-purchase", buyer: sender, stx: stx-amount, tokens: tokens-to-buy })
        (ok tokens-to-buy)
    )
)

;; @desc Claim vested tokens
(define-public (claim-tokens)
    (let (
        (sender tx-sender)
        (purchase (unwrap! (map-get? user-purchases sender) ERR_UNAUTHORIZED))
        (total-bought (get tokens-bought purchase))
        (total-claimed (get tokens-claimed purchase))
        (current-block block-height)
        (cliff (var-get cliff-block))
    )
        ;; Unlock Schedule:
        ;; TGE (cliff): 10%
        ;; Remaining 90% linear over vesting-duration
        
        (let (
            (tge-unlock (/ total-bought u10)) ;; 10%
            (vesting-tokens (- total-bought tge-unlock))
            
            (blocks-passed (if (> current-block cliff) (- current-block cliff) u0))
            (vested-amount (if (>= blocks-passed (var-get vesting-duration))
                               vesting-tokens
                               (/ (* vesting-tokens blocks-passed) (var-get vesting-duration))))
            
            (total-claimable (+ tge-unlock vested-amount))
            (new-claim-amount (- total-claimable total-claimed))
        )
            (asserts! (> new-claim-amount u0) ERR_NO_TOKENS_TO_CLAIM)

            ;; Mint/Transfer Tokens
            ;; In reality, this contract needs MINT authority or needs to hold the tokens.
            ;; Assuming this contract holds the ICO allocation.
            (try! (as-contract (contract-call? (var-get token-address) transfer new-claim-amount tx-sender sender none)))

            (map-set user-purchases sender (merge purchase {
                tokens-claimed: total-claimable,
                last-claim: current-block
            }))

            (print { event: "ico-claim", user: sender, amount: new-claim-amount })
            (ok new-claim-amount)
        )
    )
)

;; --- Trait Stubs (for fee-manager-trait compatibility if needed) ---
(define-read-only (get-fee-rate (module (string-ascii 32))) (ok u0))
(define-public (route-fees (token <sip-010-trait>) (amount uint) (is-total bool) (module (string-ascii 32))) (ok u0))
