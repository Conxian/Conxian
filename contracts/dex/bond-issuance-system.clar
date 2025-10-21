;; ===== Imports =====
(use-trait bond-issuance-trait .all-traits.bond-issuance-trait)
(use-trait ft-trait .all-traits.sip-010-ft-trait)

;; ===== Traits =====
(impl-trait bond-issuance-trait)

;; bond-issuance-system.clar
;; Tokenized bond system for backing large enterprise loans
;; Issues ERC-1155 style bonds representing shares in loan portfolios

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u8001))
(define-constant ERR_BOND_NOT_FOUND (err u8002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u8003))
(define-constant ERR_BOND_MATURED (err u8004))
(define-constant ERR_INVALID_AMOUNT (err u8005))
(define-constant ERR_TRANSFER_FAILED (err u8006))
(define-constant ERR_BOND_NOT_MATURED (err u8007))
(define-constant ERR_CIRCUIT_OPEN (err u5000))

;; Token constants
(define-fungible-token conxian-bond)
(define-constant TOKEN_NAME "Conxian Enterprise Bonds")
(define-constant TOKEN_SYMBOL "CXB")
(define-constant TOKEN_DECIMALS u6)

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var next-series-id uint u1)
(define-data-var system-paused bool false)
(define-data-var total-bonds-issued uint u0)
(define-data-var authorized-issuers (list 10 principal) (list tx-sender))
(define-data-var enterprise-loan-manager (optional principal) none)
(define-data-var yield-distribution-engine (optional principal) none)
(define-data-var circuit-breaker principal .circuit-breaker)

;; ===== Data Maps =====
(define-map bond-series uint {
  total-supply: uint,
  maturity-block: uint,
  yield-rate: uint,
  backing-loans: (list 20 uint),
  total-backing-amount: uint,
  series-name: (string-ascii 50),
  status: (string-ascii 20),
  creation-block: uint,
  last-yield-payment: uint
})

(define-map bond-holder-positions {holder: principal, series: uint} {
  balance: uint,
  total-yield-earned: uint,
  last-claim-block: uint
})

(define-map series-yield-pool uint uint)

;; ===== Circuit Breaker =====
(define-private (check-circuit-breaker)
  (contract-call? (var-get circuit-breaker) is-circuit-open))

;; ===== Private Helper Functions =====
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (is-authorized-issuer)
  (is-some (index-of (var-get authorized-issuers) tx-sender)))

(define-private (get-series-balance (series-id uint))
  (match (map-get? bond-holder-positions {holder: tx-sender, series: series-id})
    position (get balance position)
    u0))

(define-private (get-user-series (user principal))
  (list u1 u2 u3 u4 u5))

;; ===== SIP-010 Implementation =====
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (err u9999))

(define-public (get-name)
  (ok TOKEN_NAME))

(define-public (get-symbol)
  (ok TOKEN_SYMBOL))

(define-public (get-decimals)
  (ok TOKEN_DECIMALS))

(define-public (get-balance (who principal))
  (ok (fold + (map get-series-balance (get-user-series who)) u0)))

(define-public (get-total-supply)
  (ok (var-get total-bonds-issued)))

(define-public (get-token-uri)
  (ok (some u"https://conxian.finance/bonds/metadata")))

(define-public (set-token-uri (uri (optional (string-utf8 256))))
  (ok true))

;; ===== Admin Functions =====
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (add-authorized-issuer (issuer principal))
  (let ((current-issuers (var-get authorized-issuers)))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-none (index-of current-issuers issuer)) ERR_UNAUTHORIZED)
    (var-set authorized-issuers (unwrap! (as-max-len? (append current-issuers issuer) u10) ERR_UNAUTHORIZED))
    (ok true)))

(define-public (set-enterprise-loan-manager (manager principal))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set enterprise-loan-manager (some manager))
    (ok true)))

;; ===== Bond Issuance =====
(define-public (create-bond-series
  (series-name (string-ascii 50))
  (total-supply uint)
  (maturity-blocks uint)
  (yield-rate uint)
  (backing-loan-ids (list 20 uint))
  (total-backing-amount uint))
  (let ((series-id (var-get next-series-id))
        (maturity-block (+ block-height maturity-blocks)))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (or (is-contract-owner) (is-authorized-issuer)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get system-paused)) ERR_UNAUTHORIZED)
    (asserts! (> total-supply u0) ERR_INVALID_AMOUNT)
    (asserts! (> maturity-blocks u0) ERR_INVALID_AMOUNT)
    (asserts! (> total-backing-amount u0) ERR_INVALID_AMOUNT)
    (map-set bond-series series-id {
      total-supply: total-supply,
      maturity-block: maturity-block,
      yield-rate: yield-rate,
      backing-loans: backing-loan-ids,
      total-backing-amount: total-backing-amount,
      series-name: series-name,
      status: "active",
      creation-block: block-height,
      last-yield-payment: block-height
    })
    (map-set series-yield-pool series-id u0)
    (var-set next-series-id (+ series-id u1))
    (var-set total-bonds-issued (+ (var-get total-bonds-issued) total-supply))
    (try! (ft-mint? conxian-bond total-supply (as-contract tx-sender)))
    (print {event: "bond-series-created", series-id: series-id, name: series-name,
            supply: total-supply, yield-rate: yield-rate, maturity-block: maturity-block})
    (ok series-id)))

;; ===== Bond Purchase =====
(define-public (purchase-bonds (series-id uint) (amount uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND))
        (buyer tx-sender))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (not (var-get system-paused)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status series) "active") ERR_BOND_MATURED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= block-height (get maturity-block series)) ERR_BOND_MATURED)
    (let ((contract-balance (ft-get-balance conxian-bond (as-contract tx-sender))))
      (asserts! (>= contract-balance amount) ERR_INSUFFICIENT_BALANCE)
      (try! (as-contract (ft-transfer? conxian-bond amount tx-sender buyer)))
      (let ((current-position (default-to
                                {balance: u0, total-yield-earned: u0, last-claim-block: block-height}
                                (map-get? bond-holder-positions {holder: buyer, series: series-id}))))
        (map-set bond-holder-positions {holder: buyer, series: series-id}
          (merge current-position {balance: (+ (get balance current-position) amount)})))
      (print {event: "bonds-purchased", buyer: buyer, series-id: series-id, amount: amount})
      (ok amount))))

;; ===== Yield Distribution =====
(define-public (distribute-yield (series-id uint) (yield-amount uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND)))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (or (is-contract-owner)
                  (is-some (index-of (var-get authorized-issuers) tx-sender))
                  (is-eq (some tx-sender) (var-get enterprise-loan-manager))) ERR_UNAUTHORIZED)
    (let ((current-pool (default-to u0 (map-get? series-yield-pool series-id))))
      (map-set series-yield-pool series-id (+ current-pool yield-amount))
      (map-set bond-series series-id
        (merge series {last-yield-payment: block-height}))
      (print {event: "yield-distributed", series-id: series-id, amount: yield-amount})
      (ok true))))

;; ===== Yield Claiming =====
(define-public (claim-yield (series-id uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND))
        (claimer tx-sender)
        (position (unwrap! (map-get? bond-holder-positions {holder: claimer, series: series-id}) ERR_INSUFFICIENT_BALANCE)))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((holder-balance (get balance position))
          (total-supply (get total-supply series))
          (available-yield (default-to u0 (map-get? series-yield-pool series-id)))
          (holder-share (/ (* available-yield holder-balance) total-supply)))
      (asserts! (> holder-share u0) ERR_INVALID_AMOUNT)
      (map-set series-yield-pool series-id (- available-yield holder-share))
      (map-set bond-holder-positions {holder: claimer, series: series-id}
        (merge position
               {total-yield-earned: (+ (get total-yield-earned position) holder-share),
                last-claim-block: block-height}))
      (print {event: "yield-claimed", holder: claimer, series-id: series-id, amount: holder-share})
      (ok holder-share))))

;; ===== Bond Maturity =====
(define-public (mature-bonds (series-id uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND)))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (>= block-height (get maturity-block series)) ERR_BOND_NOT_MATURED)
    (asserts! (is-eq (get status series) "active") ERR_BOND_MATURED)
    (map-set bond-series series-id
      (merge series {status: "matured"}))
    (print {event: "bond-series-matured", series-id: series-id})
    (ok true)))

(define-public (redeem-mature-bonds (series-id uint) (amount uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND))
        (holder tx-sender)
        (position (unwrap! (map-get? bond-holder-positions {holder: holder, series: series-id}) ERR_INSUFFICIENT_BALANCE)))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-eq (get status series) "matured") ERR_BOND_NOT_MATURED)
    (asserts! (>= (get balance position) amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let ((total-backing (get total-backing-amount series))
          (total-supply (get total-supply series))
          (redemption-value (/ (* amount total-backing) total-supply)))
      (try! (ft-burn? conxian-bond amount holder))
      (map-set bond-holder-positions {holder: holder, series: series-id}
        (merge position {balance: (- (get balance position) amount)}))
      (print {event: "bonds-redeemed", holder: holder, series-id: series-id,
              amount: amount, value: redemption-value})
      (ok redemption-value))))

;; ===== Read-Only Functions =====
(define-read-only (get-bond-series (series-id uint))
  (map-get? bond-series series-id))

(define-read-only (get-holder-position (holder principal) (series-id uint))
  (map-get? bond-holder-positions {holder: holder, series: series-id}))

(define-read-only (get-yield-pool (series-id uint))
  (map-get? series-yield-pool series-id))

(define-read-only (calculate-yield-due (holder principal) (series-id uint))
  (match (map-get? bond-holder-positions {holder: holder, series: series-id})
    position
      (match (map-get? bond-series series-id)
        series
          (let ((holder-balance (get balance position))
                (total-supply (get total-supply series))
                (available-yield (default-to u0 (map-get? series-yield-pool series-id))))
            (ok (/ (* available-yield holder-balance) total-supply)))
        ERR_BOND_NOT_FOUND)
    ERR_INSUFFICIENT_BALANCE))

(define-read-only (get-bond-price (series-id uint))
  (match (map-get? bond-series series-id)
    series (ok {
      series-id: series-id,
      price: u1000000,  ;; Base price
      last-updated: block-height,
      status: (get status series)
    })
    (err ERR_BOND_NOT_FOUND)
  )
)

(define-read-only (get-series-stats (series-id uint))
  (match (map-get? bond-series series-id)
    series (ok {
      series-id: series-id,
      name: (get series-name series),
      total-supply: (get total-supply series),
      status: (get status series),
      yield-rate: (get yield-rate series),
      maturity-block: (get maturity-block series),
      backing-amount: (get total-backing-amount series),
      available-yield: (default-to u0 (map-get? series-yield-pool series-id))
    })
    none (err ERR_BOND_NOT_FOUND)
  )
)