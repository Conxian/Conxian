(use-trait ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait nft-trait .sip-009-nft-trait.sip-009-nft-trait)

;; Pool Template - Basic DEX Pool Implementation
;; This contract serves as a template for creating new DEX pools

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NOT_INITIALIZED (err u1002))
(define-constant ERR_INVALID_INPUT (err u1003))

;; --- Data Variables ---
(define-data-var token-a principal .cxd-token)
(define-data-var token-b principal .cxvg-token)
(define-data-var fee-bps uint u30) ;; 0.3% default fee (30 bps)
(define-data-var admin principal tx-sender)
(define-data-var reserve-a uint u0)
(define-data-var reserve-b uint u0)
(define-data-var total-supply uint u0)


;; --- Initialization ---
(define-public (initialize (a principal) (b principal) (fee uint) (admin-principal principal))
  (begin
    ;; Input validation
    (asserts! (is-ok (contract-call? a get-symbol)) (err ERR_INVALID_INPUT))
    (asserts! (is-ok (contract-call? b get-symbol)) (err ERR_INVALID_INPUT))
    (asserts! (not (is-eq a b)) (err ERR_INVALID_INPUT))
    (asserts! (<= fee u10000) (err ERR_INVALID_INPUT)) ;; Max 100% fee
    
    ;; Set token pair (sorted order for consistency)
    (if (< (unwrap-panic (to-uint a)) (unwrap-panic (to-uint b)))
      (begin
        (var-set token-a a)
        (var-set token-b b)
      )
      (begin
        (var-set token-a b)
        (var-set token-b a)
      )
    )
    
    (var-set fee-bps fee)
    (var-set admin admin-principal)
    (ok true)
  )
)

;; --- Core AMM Functions ---
(define-public (swap-exact-in (amount-in uint) (min-amount-out uint) (a-to-b bool) (deadline uint))
  (let (
      (token-in (if a-to-b (var-get token-a) (var-get token-b)))
      (token-out (if a-to-b (var-get token-b) (var-get token-a)))
      (reserve-in (if a-to-b (var-get reserve-a) (var-get reserve-b)))
      (reserve-out (if a-to-b (var-get reserve-b) (var-get reserve-a)))
    )
    (begin
      (asserts! (> block-height deadline) (err ERR_INVALID_INPUT))
      (asserts! (>= amount-in u0) (err ERR_INVALID_INPUT))
      
      (let (
          (amount-in-with-fee (- amount-in (/ (* amount-in (var-get fee-bps)) 10000)))
          (numerator (* amount-in-with-fee reserve-out))
          (denominator (+ reserve-in amount-in-with-fee))
          (amount-out (/ numerator denominator))
        )
        (asserts! (>= amount-out min-amount-out) (err ERR_INVALID_INPUT))
        
        ;; Update reserves
        (if a-to-b
          (begin
            (var-set reserve-a (+ (var-get reserve-a) amount-in))
            (var-set reserve-b (- (var-get reserve-b) amount-out))
          )
          (begin
            (var-set reserve-b (+ (var-get reserve-b) amount-in))
            (var-set reserve-a (- (var-get reserve-a) amount-out))
          )
        )
        
        ;; Emit event
        (print { event: "Swap", sender: tx-sender, "amount-in": amount-in, "amount-out": amount-out, "token-in": token-in, "token-out": token-out })
        (ok {
          amount-out: amount-out,
          fee: (- amount-in amount-in-with-fee)
        })
      )
    )
  )
)

;; --- Read-Only Functions ---
(define-read-only (get-reserves)
  (ok {
    reserve-a: (var-get reserve-a),
    reserve-b: (var-get reserve-b)
  })
)

(define-read-only (get-fee-info)
  (ok {
    lp-fee-bps: (var-get fee-bps),
    protocol-fee-bps: u0  ;; No protocol fee by default
  })
)

(define-read-only (get-price)
  (let ((reserves (unwrap! (get-reserves) (err ERR_NOT_INITIALIZED))))
    (ok {
      price-x-y: (get reserve-b reserves),
      price-y-x: (get reserve-a reserves)
    })
  )
)

(define-read-only (get-token-a)
  (ok (var-get token-a))
)

(define-read-only (get-token-b)
  (ok (var-get token-b))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

;; --- Admin Functions ---
(define-public (set-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-fee-bps u10000) (err ERR_INVALID_INPUT))
    (var-set fee-bps new-fee-bps)
    (ok true)
  )
)

;; --- Trait Implementation ---

(define-read-only (get-token-a)
  (ok (var-get token-a))
)

(define-read-only (get-token-b)
  (ok (var-get token-b))
)

(define-read-only (get-fee-bps)
  (ok (var-get fee-bps))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-reserves)
  (ok {
    reserve-a: (var-get reserve-a),
    reserve-b: (var-get reserve-b)
  })
)

(define-read-only (get-fee-info)
  (ok {
    lp-fee-bps: (var-get fee-bps),
    protocol-fee-bps: u0  ;; No protocol fee by default
  })
)

(define-read-only (get-price)
  (let ((reserves (unwrap! (get-reserves) (err ERR_NOT_INITIALIZED))))
    (ok {
      price-x-y: (get reserve-b reserves),
      price-y-x: (get reserve-a reserves)
    })
  )
)

;; --- Internal Functions ---
(define-private (mint (to principal) (amount uint))
  (begin
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)

(define-private (burn (from principal) (amount uint))
  (begin
    (var-set total-supply (- (var-get total-supply) amount))
    (ok true)
  )
)

