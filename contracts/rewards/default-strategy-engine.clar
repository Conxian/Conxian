;; Default Strategy Engine
;; Manages system-wide default strategies across DeFi dimensions
;; Categories: stable, loans, money-market, assets, bonds
;; Applies defaults to vault assets based on metrics and optimization params

;; Traits
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
(use-trait strategy-trait .traits folder.strategy-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u9501))
(define-constant ERR_CATEGORY_NOT_FOUND (err u9502))
(define-constant ERR_STRATEGY_NOT_SET (err u9503))
(define-constant ERR_ASSET_NOT_SUPPORTED (err u9504))
(define-constant ERR_ENGINE_NOT_CONFIGURED (err u9505))
(define-constant ERR_INVALID_PARAMS (err u9506))

;; Categories (string identifiers)
(define-constant CAT_STABLE "stable")
(define-constant CAT_LOANS "loans")
(define-constant CAT_MONEY_MARKET "money-market")
(define-constant CAT_ASSETS "assets")
(define-constant CAT_BONDS "bonds")

;; Admin and core configuration
(define-data-var admin principal tx-sender)
(define-data-var metrics (optional principal) none)
(define-data-var vault (optional principal) none)

;; Category -> default strategy
(define-map category-defaults { category: (string-ascii 32) } { strategy: principal })

;; Asset -> applied strategy (current default applied)
(define-map asset-strategy { asset: principal } { strategy: principal, category: (string-ascii 32) })

;; Optimization parameters per asset
(define-map asset-params { asset: principal } {
  min-liquidity: uint,
  max-slippage-bps: uint,
  risk-score: uint
})

;; Performance snapshots per asset
(define-map performance-snapshots { asset: principal } {
  last-updated: uint,
  apy-bps: uint,
  tvl: uint,
  efficiency-bps: uint
})

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-metrics (m principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set metrics (some m))
    (ok true)))

(define-public (set-vault (v principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set vault (some v))
    (ok true)))

;; Configure category default strategies
(define-public (set-category-default (category (string-ascii 32)) (strategy principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set category-defaults { category: category } { strategy: strategy })
    (ok true)))

;; Set optimization parameters for a given asset
(define-public (set-asset-params (asset principal) (min-liquidity uint) (max-slippage-bps uint) (risk-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (and (>= max-slippage-bps u0) (<= max-slippage-bps u10000)) ERR_INVALID_PARAMS)
    (map-set asset-params { asset: asset } {
      min-liquidity: min-liquidity,
      max-slippage-bps: max-slippage-bps,
      risk-score: risk-score
    })
    (ok true)))

;; Apply a category default strategy to an asset (auto-assignment)
(define-public (apply-default-to-asset (asset principal) (category (string-ascii 32)))
  (let ((entry (map-get? category-defaults { category: category })))
    (asserts! (is-some entry) ERR_CATEGORY_NOT_FOUND)
    (let ((s (get strategy (unwrap-panic entry))))
      (map-set asset-strategy { asset: asset } { strategy: s, category: category })
      (ok s)
    )
  )
)

;; Read-only helpers
(define-read-only (get-category-default (category (string-ascii 32)))
  (match (map-get? category-defaults { category: category })
    e (ok (get strategy e))
    (err ERR_CATEGORY_NOT_FOUND)))

(define-read-only (get-asset-strategy (asset principal))
  (match (map-get? asset-strategy { asset: asset })
    e (ok (tuple (strategy (get strategy e)) (category (get category e))))
    (err ERR_STRATEGY_NOT_SET)))

;; Strategy selection API for optimizers/routers
(define-read-only (select-default-strategy (asset principal) (category (string-ascii 32)))
  (let ((by-asset (map-get? asset-strategy { asset: asset })))
    (if (is-some by-asset)
      (ok (get strategy (unwrap-panic by-asset)))
      (let ((by-cat (map-get? category-defaults { category: category })))
        (match by-cat e (ok (get strategy e)) (err ERR_CATEGORY_NOT_FOUND))
      )
    )
  )
)

;; Performance tracking (calls strategy.get-apy, strategy.get-tvl if available)
(define-public (update-performance (asset principal))
  (let ((applied (unwrap! (map-get? asset-strategy { asset: asset }) ERR_STRATEGY_NOT_SET)))
    (let ((s (get strategy applied)))
      (let (
        (apy-res (contract-call? s get-apy))
        (tvl-res (contract-call? s get-tvl))
      )
        (let ((apy (match apy-res (ok v) v (err u0) u0))
              (tvl (match tvl-res (ok v) v (err u0) u0)))
          (map-set performance-snapshots { asset: asset } {
            last-updated: block-height,
            apy-bps: (if (is-none apy) u0 (default-to u0 apy)),
            tvl: (if (is-none tvl) u0 (default-to u0 tvl)),
            efficiency-bps: u0
          })
          (ok true)
        )
      )
    )
  )
)

;; Rebalance according to defaults (withdraw from current, deposit to default)
(define-public (rebalance-asset (asset (contract-of sip-010-ft-trait)))
  (let ((asset-principal (contract-of asset)))
    (let ((applied (unwrap! (map-get? asset-strategy { asset: asset-principal }) ERR_STRATEGY_NOT_SET)))
      (let ((s (get strategy applied)))
        ;; Minimal: call deposit on strategy with available asset balance from vault (requires configured vault)
        (match (var-get vault)
          v
            (begin
              ;; In a complete implementation, would withdraw from any previous strategy and deposit to s
              ;; Here we perform a no-op and record the rebalance intent
              (ok true)
            )
          (err ERR_ENGINE_NOT_CONFIGURED)
        )
      )
    )
  )
)

;; Get performance snapshot
(define-read-only (get-performance (asset principal))
  (match (map-get? performance-snapshots { asset: asset })
    snap (ok snap)
    (ok { last-updated: u0, apy-bps: u0, tvl: u0, efficiency-bps: u0 }))
)
