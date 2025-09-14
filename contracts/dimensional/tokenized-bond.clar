;; tokenized-bond.clar
;;
;; This contract implements a SIP-010 tokenized bond.
;; It represents a single series of bonds with uniform characteristics.
;;
;; Features:
;; - SIP-010 compliant fungible token for secondary market trading.
;; - Periodic coupon payments that can be claimed by bondholders.
;; - Principal payout at maturity.

(use-trait sip10 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip-010-trait)
(impl-trait .sip-010-trait.sip-010-trait)
(define-fungible-token tokenized-bond)

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
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get bond-issued)) (err ERR_ALREADY_ISSUED))

    (var-set token-name name)
    (var-set token-symbol symbol)
    (var-set token-decimals decimals)
    (var-set issue-block block-height)
    (var-set maturity-block (+ block-height maturity-in-blocks))
    (var-set coupon-rate coupon-rate-scaled)
    (var-set coupon-frequency frequency-in-blocks)
    (var-set face-value bond-face-value)
    (var-set payment-token-contract (some payment-token-address))

    (try! (ft-mint? tokenized-bond initial-supply (var-get contract-owner)))
    (var-set total-supply initial-supply)

    (var-set bond-issued true)
    (ok true)
  )
)

 (define-public (claim-coupons (payment-token <sip10>))
  (let (
      (user tx-sender)
      (last-period (default-to u0 (get period (map-get? last-claimed-coupon { user: user }))))
      (current-period (/ (- block-height (var-get issue-block)) (var-get coupon-frequency)))
      (balance (ft-get-balance tokenized-bond user))
    )
    (asserts! (var-get bond-issued) (err ERR_BOND_NOT_ISSUED))
    (asserts! (< block-height (var-get maturity-block)) (err ERR_ALREADY_MATURED))
    (asserts! (> current-period last-period) (err ERR_NO_COUPONS_DUE))

    (let (
        (periods-to-claim (- current-period last-period))
        (coupon-per-token-per-period (/ 
          (* (var-get face-value)
            (* (var-get coupon-rate) (var-get coupon-frequency))
          )
          u525600000
        ))
        (total-coupon-payment (* balance (* periods-to-claim coupon-per-token-per-period)))
      )
      (asserts!
        (is-ok (contract-call? payment-token transfer total-coupon-payment tx-sender user none))
        (err u400)
      )
      (map-set last-claimed-coupon { user: user } { period: current-period })
      (ok total-coupon-payment)
    )
  )
)

 (define-public (redeem-at-maturity (payment-token <sip10>))
  (let (
      (user tx-sender)
      (balance (ft-get-balance tokenized-bond user))
      (maturity (var-get maturity-block))
    )
    (asserts! (var-get bond-issued) (err ERR_BOND_NOT_ISSUED))
    (asserts! (>= block-height maturity) (err ERR_NOT_YET_MATURED))

    (let (
        (last-claim-period (default-to u0 (get period (map-get? last-claimed-coupon { user: user }))))
        (maturity-period (/ (- maturity (var-get issue-block)) (var-get coupon-frequency)))
        (periods-to-claim (if (> maturity-period last-claim-period)
          (- maturity-period last-claim-period)
          u0
        ))
        (coupon-per-token-per-period (/ 
          (* (var-get face-value)
            (* (var-get coupon-rate) (var-get coupon-frequency))
          )
          u525600000
        ))
        (final-coupon-payment (* balance (* periods-to-claim coupon-per-token-per-period)))
        (principal-payment (* balance (var-get face-value)))
        (total-payment (+ final-coupon-payment principal-payment))
      )
      (asserts! (> balance u0) (err u0))
      (asserts!
        (is-ok (contract-call? payment-token transfer total-payment tx-sender user none))
        (err u400)
      )
      (try! (ft-burn? tokenized-bond balance user))
      (var-set total-supply (- (var-get total-supply) balance))
      (map-set last-claimed-coupon { user: user } { period: maturity-period })
      (ok {
        principal: principal-payment,
        coupon: final-coupon-payment,
      })
    )
  )
)

(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq sender tx-sender) (err u4))
    (try! (ft-transfer? tokenized-bond amount sender recipient))
    (ok true)
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
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set token-uri value)
    (ok true)
  )
)

(define-read-only (get-payment-token-contract)
  (ok (var-get payment-token-contract))
)





