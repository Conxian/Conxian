;; tokenized-bond.clar
;;
;; This contract implements a SIP-010 tokenized bond.
;; It represents a single series of bonds with uniform characteristics.
;;
;; Features:
;; - SIP-010 compliant fungible token for secondary market trading.
;; - Periodic coupon payments that can be claimed by bondholders.
;; - Principal payout at maturity.

;; Import traits from the all-traits.clar file
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait bond-trait .all-traits.bond-trait)

;; Implement the traits for this contract
(impl-trait .all-traits.bond-trait)
(impl-trait .all-traits.sip-010-ft-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_NOT_OWNER (err u103))
(define-constant ERR_BOND_NOT_ISSUED (err u104))
(define-constant ERR_ALREADY_ISSUED (err u105))
(define-constant ERR_INVALID_DECIMALS (err u106))
(define-constant ERR_INVALID_MATURITY (err u107))
(define-constant ERR_INVALID_COUPON_RATE (err u108))
(define-constant ERR_INVALID_FREQUENCY (err u109))
(define-constant ERR_INVALID_FACE_VALUE (err u110))
(define-constant ERR_NOT_YET_MATURED (err u111))
(define-constant ERR_ALREADY_MATURED (err u112))
(define-constant ERR_NO_COUPONS_DUE (err u113))
(define-constant ERR_INVALID_TOKEN_URI (err u114))
(define-constant ERR_REENTRANCY (err u115))
(define-constant ERR_CONTRACT_PAUSED (err u116))
(define-constant ERR_INVALID_TIMING (err u117))

;; Reentrancy protection
(define-data-var locked bool false)
(define-data-var paused bool false)

(define-private (non-reentrant)
  (let ((current-locked (var-get locked)))
    (asserts! (not current-locked) ERR_REENTRANCY)
    (var-set locked true)
    true))

(define-private (when-not-paused)
  (asserts! (not (var-get paused)) ERR_CONTRACT_PAUSED)
  true)

;; Constants
(define-constant MAX_UINT u340282366920938463463374607431768211455)
(define-constant MAX_DECIMALS u18)
(define-constant MIN_MATURITY_BLOCKS u1440)  ;; ~1 day at 1 block/60s
(define-constant MAX_COUPON_RATE u1000000000000000000)  ;; 100%
(define-constant MIN_COUPON_FREQUENCY u144)  ;; ~1 day at 1 block/10min

(define-fungible-token tokenized-bond u6)

;; --- SIP-010 Token Functions ---

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_OWNER)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal recipient) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance tokenized-bond sender) amount) ERR_INSUFFICIENT_BALANCE)
    (match (ft-transfer? tokenized-bond amount sender recipient memo)
      (ok true) (ok true)
      (err e) (err e)
    )
  )
)

;; Internal mint function (not part of SIP-010)
(define-private (mint-internal (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal recipient) ERR_INVALID_AMOUNT)
    (asserts! (<= (+ (ft-get-supply tokenized-bond) amount) MAX_UINT) ERR_INVALID_AMOUNT)
    (unwrap-panic (ft-mint? tokenized-bond amount recipient))
  )
)

;; Internal burn function (not part of SIP-010)
(define-private (burn-internal (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-principal owner) ERR_INVALID_AMOUNT)
    (asserts! (>= (ft-get-balance tokenized-bond owner) amount) ERR_INSUFFICIENT_BALANCE)
    (unwrap-panic (ft-burn? tokenized-bond amount owner))
  )
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance tokenized-bond who))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-constant ERR_UNAUTHORIZED u201)
(define-constant ERR_NOT_YET_MATURED u202)
(define-constant ERR_ALREADY_MATURED u203)
(define-constant ERR_NO_COUPONS_DUE u204)
(define-constant ERR_BOND_NOT_ISSUED u205)
(define-constant ERR_ALREADY_ISSUED u210)

(define-data-var token-name (string-ascii 32) "Tokenized Bond")
(define-data-var token-symbol (string-ascii 10) "BOND")
(define-data-var token-decimals uint u8)
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-data-var bond-issued bool false)
(define-data-var issue-block uint u0)
(define-data-var maturity-block uint u0)
(define-data-var coupon-rate uint u0)
(define-data-var coupon-frequency uint u0)
(define-data-var face-value uint u0)
(define-data-var payment-token-contract (optional principal) none)
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)

(define-map last-claimed-coupon { user: principal } { period: uint })

(define-private (is-valid-principal (who principal))
  (is-eq (len (unwrap-panic (principal-destruct who))) 28)
)

(define-public (issue-bond
    (name (string-ascii 32))
    (symbol (string-ascii 10))
    (decimals uint)
    (initial-supply uint)
    (maturity-in-blocks uint)
    (coupon-rate-scaled uint)
    (frequency-in-blocks uint)
    (bond-face-value uint)
    (payment-token-address principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get bond-issued)) ERR_ALREADY_ISSUED)
    (asserts! (<= decimals MAX_DECIMALS) ERR_INVALID_DECIMALS)
    (asserts! (>= (len name) 1) ERR_INVALID_AMOUNT)
    (asserts! (>= (len symbol) 1) ERR_INVALID_AMOUNT)
    (asserts! (> initial-supply u0) ERR_INVALID_AMOUNT)
    (asserts! (>= maturity-in-blocks MIN_MATURITY_BLOCKS) ERR_INVALID_MATURITY)
    (asserts! (<= coupon-rate-scaled MAX_COUPON_RATE) ERR_INVALID_COUPON_RATE)
    (asserts! (>= frequency-in-blocks MIN_COUPON_FREQUENCY) ERR_INVALID_FREQUENCY)
    (asserts! (> bond-face-value u0) ERR_INVALID_FACE_VALUE)
    (asserts! (is-valid-principal payment-token-address) ERR_INVALID_AMOUNT)
    (asserts! (<= (len (unwrap-panic (principal-destruct payment-token-address))) 28) ERR_INVALID_AMOUNT)

    (var-set token-name name)
    (var-set token-symbol symbol)
    (var-set token-decimals decimals)
    (var-set issue-block block-height)
    (var-set maturity-block (safe-add block-height maturity-in-blocks))
    (var-set coupon-rate coupon-rate-scaled)
    (var-set coupon-frequency frequency-in-blocks)
    (var-set face-value bond-face-value)
    (var-set payment-token-contract (some payment-token-address))

    (try! (mint-internal initial-supply (var-get contract-owner)))
    (var-set total-supply initial-supply)
    (var-set bond-issued true)
    
    (print {
      event: "bond-issued",
      name: name,
      symbol: symbol,
      decimals: decimals,
      initial-supply: initial-supply,
      maturity-block: (var-get maturity-block),
      coupon-rate: coupon-rate-scaled,
      frequency: frequency-in-blocks,
      face-value: bond-face-value,
      payment-token: payment-token-address
    })
    
    (ok true)
  )
)

(define-private (safe-add (a uint) (b uint))
  (let ((sum (+ a b)))
    (asserts! (>= sum a) (err ERR_INVALID_AMOUNT))
    (ok sum)
  )
)

(define-private (safe-mul (a uint) (b uint))
  (let ((product (* a b)))
    (asserts! (or (is-eq a (/ product b)) (is-eq b u0)) (err ERR_INVALID_AMOUNT))
    (ok product)
  )
)

(define-private (safe-sub (a uint) (b uint))
  (asserts! (>= a b) (err ERR_INVALID_AMOUNT))
  (ok (- a b))
)

(define-private (safe-div (a uint) (b uint))
  (asserts! (> b u0) (err ERR_INVALID_AMOUNT))
  (ok (/ a b)))

(define-public (claim-coupons (payment-token principal))
  (let (
      (user tx-sender)
      (last-period (default-to u0 (get period (map-get? last-claimed-coupon { user: user }))))
      (current-period (unwrap! (safe-div (unwrap! (safe-sub block-height (var-get issue-block)) (err ERR_INVALID_AMOUNT)) (var-get coupon-frequency)) (err ERR_INVALID_AMOUNT)))
      (balance (unwrap-panic (ft-get-balance tokenized-bond user)))
    )
    (asserts! (var-get bond-issued) ERR_BOND_NOT_ISSUED)
    (asserts! (< block-height (var-get maturity-block)) ERR_ALREADY_MATURED)
    (asserts! (> current-period last-period) ERR_NO_COUPONS_DUE)
    (asserts! (is-eq payment-token (unwrap! (var-get payment-token-contract) ERR_INVALID_AMOUNT)) ERR_INVALID_AMOUNT)

    (let (
        (periods-to-claim (unwrap! (safe-sub current-period last-period) (err ERR_INVALID_AMOUNT)))
        (coupon-per-token-per-period (unwrap! (safe-div 
          (unwrap! (safe-mul 
            (var-get face-value)
            (unwrap! (safe-mul (var-get coupon-rate) (var-get coupon-frequency)) (err ERR_INVALID_AMOUNT))
          ) (err ERR_INVALID_AMOUNT))
          u525600000
        ) (err ERR_INVALID_AMOUNT)))
        (total-coupon-payment (unwrap! (safe-mul balance (unwrap! (safe-mul periods-to-claim coupon-per-token-per-period) (err ERR_INVALID_AMOUNT))) (err ERR_INVALID_AMOUNT)))
      )
      (asserts! (> total-coupon-payment u0) ERR_INVALID_AMOUNT)
      
      (match (contract-call? payment-token transfer total-coupon-payment tx-sender user none)
        (ok true) 
        (begin 
          (map-set last-claimed-coupon { user: user } { period: current-period })
          (print {
            event: "coupons-claimed",
            user: user,
            amount: total-coupon-payment,
            periods: periods-to-claim,
            current-period: current-period
          })
          (ok total-coupon-payment)
        )
        (err error) (err error)
      )
    )
  )
)

 (define-public (redeem-at-maturity (payment-token principal))
  (let (
      (user tx-sender)
      (balance (unwrap-panic (ft-get-balance tokenized-bond user)))
      (maturity (var-get maturity-block))
    )
    (asserts! (var-get bond-issued) ERR_BOND_NOT_ISSUED)
    (asserts! (>= block-height maturity) ERR_NOT_YET_MATURED)
    (asserts! (> balance u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq payment-token (unwrap! (var-get payment-token-contract) ERR_INVALID_AMOUNT)) ERR_INVALID_AMOUNT)

    (let (
        (last-claim-period (default-to u0 (get period (map-get? last-claimed-coupon { user: user }))))
        (maturity-period (unwrap! (safe-div (unwrap! (safe-sub maturity (var-get issue-block)) (err ERR_INVALID_AMOUNT)) (var-get coupon-frequency)) (err ERR_INVALID_AMOUNT)))
        (periods-to-claim (if (> maturity-period last-claim-period)
          (unwrap! (safe-sub maturity-period last-claim-period) (err ERR_INVALID_AMOUNT))
          u0
        ))
        (coupon-per-token-per-period (unwrap! (safe-div 
          (unwrap! (safe-mul 
            (var-get face-value)
            (unwrap! (safe-mul (var-get coupon-rate) (var-get coupon-frequency)) (err ERR_INVALID_AMOUNT))
          ) (err ERR_INVALID_AMOUNT))
          u525600000
        ) (err ERR_INVALID_AMOUNT)))
        (final-coupon-payment (unwrap! (safe-mul balance (unwrap! (safe-mul periods-to-claim coupon-per-token-per-period) (err ERR_INVALID_AMOUNT))) (err ERR_INVALID_AMOUNT)))
        (principal-payment (unwrap! (safe-mul balance (var-get face-value)) (err ERR_INVALID_AMOUNT)))
        (total-payment (unwrap! (safe-add final-coupon-payment principal-payment) (err ERR_INVALID_AMOUNT)))
      )
      (match (as-contract (contract-call? payment-token transfer total-payment tx-sender user none))
        (ok true)
        (begin
          (try! (burn-internal balance user))
          (var-set total-supply (unwrap! (safe-sub (var-get total-supply) balance) (err ERR_INVALID_AMOUNT)))
          (map-set last-claimed-coupon { user: user } { period: maturity-period })
          
          (print {
            event: "bond-redeemed",
            user: user,
            principal: principal-payment,
            coupon: final-coupon-payment,
            total: total-payment,
            balance: balance
          })
          
          (ok {
            principal: principal-payment,
            coupon: final-coupon-payment,
          })
        )
        (err error) (err error)
      )
    )
  )
)


;; --- SIP-010 and helper read-only/public functions ---

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance tokenized-bond who))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (set-token-uri (value (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (match value
      (some uri) (asserts! (<= (len uri) 256) ERR_INVALID_TOKEN_URI)
      none true
    )
    (var-set token-uri value)
    
    (print {
      event: "token-uri-updated",
      by: tx-sender,
      new-uri: value
    })
    
    (ok true)
  )
)

(define-read-only (get-payment-token-contract)
  (ok (var-get payment-token-contract))
)

