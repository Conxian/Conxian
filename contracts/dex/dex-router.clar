(use-trait router-trait .all-traits.router-trait)
(use-trait factory-trait .all-traits.factory-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(impl-trait router-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u4000))
(define-constant ERR_INVALID_PATH (err u4002))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u4003))
(define-constant ERR_DEADLINE_PASSED (err u4004))
(define-constant ERR_POOL_NOT_FOUND (err u4005))
(define-constant ERR_TRANSFER_FAILED (err u4006))
(define-constant ERR_RECURSION_DEPTH (err u4007))
(define-constant ERR_ZERO_AMOUNT (err u4008))
(define-constant ERR_DUPLICATE_TOKENS (err u4009))
(define-constant ERR_INVALID_BOND (err u4010))
(define-constant ERR_BOND_NOT_MATURE (err u4011))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u4012))
(define-constant ERR_REENTRANCY (err u4013))
(define-constant MAX_RECURSION_DEPTH u5)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var factory-address principal .dex-factory)
(define-data-var bond-factory-address principal .bond-factory)
(define-data-var locked bool false)  ;; Reentrancy guard
(define-data-var swap-iteration uint u0)  ;; Track swap iterations

;; --- Bond Trading State ---
(define-map bond-markets
  principal  ;; bond token address
  {
    is-active: bool,
    min-trade-amount: uint,
    max-trade-amount: uint,
    trading-fee: uint,  ;; in basis points
    last-price: uint,
    volume-24h: uint
  }
)

(define-map bond-positions
  { holder: principal, bond: principal }  ;; Composite key
  {
    amount: uint,
    last-claim: uint,
    is-liquid: bool
  }
)

;; --- Security Helpers ---
(define-private (non-reentrant (action (function () (response AnyError Any))))
  (asserts! (not (var-get locked)) ERR_REENTRANCY)
  (var-set locked true)
  (let ((result (try! (action))))
    (var-set locked false)
    result
  )
)

(define-private (only-owner)
  (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
  (ok true)
)

;; --- Bond Market Helpers ---
(define-private (validate-bond-market (bond-contract principal))
  (match (map-get? bond-markets bond-contract)
    market (ok (get is-active market))
    (err ERR_INVALID_BOND)
  )
)

(define-private (calculate-bond-price (bond-contract principal) (amount uint))
  (match (contract-call? bond-contract get-bond-price amount)
    (ok price) (ok price)
    (err e) (err ERR_INVALID_BOND)
  )
)

(define-private (update-bond-volume (bond-contract principal) (amount uint))
  (match (map-get? bond-markets bond-contract)
    market (let ((new-volume (+ (get volume-24h market) amount)))
      (map-set bond-markets bond-contract (merge market {
        volume-24h: new-volume,
        last-updated: block-height
      }))
      (ok true)
    )
    (err ERR_INVALID_BOND)
  )
)

;; --- Core Trading Functions ---
(define-public (swap-bonds
    (bond-in principal)
    (bond-out principal)
    (amount-in uint)
    (min-amount-out uint)
    (deadline uint)
  )
  (try! (non-reentrant (lambda ()
    (begin
      (asserts! (> amount-in u0) ERR_ZERO_AMOUNT)
      (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
      (try! (validate-bond-market bond-in))
      (try! (validate-bond-market bond-out))
      
      (let (
          (price (try! (calculate-bond-price bond-in amount-in)))
          (fee (/ (* price (get trading-fee (unwrap! (map-get? bond-markets bond-in) (err ERR_INVALID_BOND)))) u10000))
          (amount-out (- price fee))
        )
        (begin
            (asserts! (>= amount-out min-amount-out) ERR_INSUFFICIENT_OUTPUT)

            ;; Transfer bonds and update state
            (try! (contract-call? bond-in transfer amount-in tx-sender (as-contract tx-sender) none))
            (try! (contract-call? bond-out transfer amount-out (as-contract tx-sender) tx-sender none))

            ;; Update market data
            (try! (update-bond-volume bond-in amount-in))
            (try! (update-bond-volume bond-out amount-out))

            (ok (tuple
              (amount-in amount-in)
              (amount-out amount-out)
              (fee fee)
              (price price)
            ))
        )
      )
    )
  )))
)

(define-public (add-bond-liquidity
    (bond-contract principal)
    (token-contract principal)
    (bond-amount uint)
    (token-amount uint)
    (min-lp-tokens uint)
    (deadline uint)
  )
  (try! (non-reentrant (lambda ()
    (begin
      (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
      (asserts! (and (> bond-amount u0) (> token-amount u0)) ERR_ZERO_AMOUNT)
      
      ;; Transfer tokens to contract
      (try! (contract-call? bond-contract transfer bond-amount tx-sender (as-contract tx-sender) none))
      (try! (contract-call? token-contract transfer token-amount tx-sender (as-contract tx-sender) none))
      
      ;; Get or create pool
      (let ((factory (var-get factory-address)))
        (match (contract-call? factory get-pool bond-contract token-contract)
          pool-principal (begin
            ;; Add liquidity to existing pool
            (let ((lp-tokens (try! (contract-call? pool-principal add-liquidity bond-amount token-amount min-lp-tokens))))
              (ok (tuple
                (lp-tokens lp-tokens)
                (bond-amount bond-amount)
                (token-amount token-amount)
              ))
            )
          )
          (err e) (begin
            ;; Create new pool and add initial liquidity
            (let ((new-pool (try! (contract-call? factory create-pool bond-contract token-contract))))
              (let ((lp-tokens (try! (contract-call? new-pool add-liquidity bond-amount token-amount min-lp-tokens))))
                (ok (tuple
                  (pool new-pool)
                  (lp-tokens lp-tokens)
                  (bond-amount bond-amount)
                  (token-amount token-amount)
                ))
              )
            )
          )
        )
      )
    )
  )))
)

;; --- Admin Functions ---
(define-public (set-bond-factory (new-factory principal))
  (begin
    (try! (only-owner))
    (var-set bond-factory-address new-factory)
    (ok true)
  )
)

(define-public (register-bond-market
    (bond-contract principal)
    (min-trade-amount uint)
    (max-trade-amount uint)
    (trading-fee uint)
  )
  (begin
    (try! (only-owner))
    (map-set bond-markets bond-contract (tuple
      (is-active true)
      (min-trade-amount min-trade-amount)
      (max-trade-amount max-trade-amount)
      (trading-fee trading-fee)
      (last-price u0)
      (volume-24h u0)
      (last-updated block-height)
    ))
    (ok true)
  )
)

(define-public (disable-bond-market (bond-contract principal))
  (begin
    (try! (only-owner))
    (match (map-get? bond-markets bond-contract)
      market (begin
        (map-set bond-markets bond-contract (merge market (tuple
          (is-active false)
        )))
        (ok true)
      )
      (err e) (err ERR_INVALID_BOND)
    )
  )
)

;; Helper function to get the next token in the path
(define-private (get-next-token (path (list 5 principal)))
  (unwrap! (element-at path u1) ERR_INVALID_PATH)
)

;; Helper function to get remaining path
(define-private (get-remaining-path (path (list 5 principal)))
  (slice path u1 u5)
)

;; Process swap with multiple hops (direct implementation without interdependency)
(define-private (process-multi-hop
    (token-in principal)
    (path (list 5 principal))
    (amount-in uint)
    (min-amount-out uint)
    (deadline uint)
    (recipient principal)
  )
  (fold (lambda (hop-index acc)
    (match acc
      ((ok current-state)
        (let ((current-token (get current-token current-state))
              (current-amount (get current-amount current-state))
              (remaining-path (get remaining-path current-state))
              (path-length (len remaining-path)))
          (if (<= path-length u1)
            (ok current-state) ;; No more hops to process
            (let ((token-out (unwrap! (element-at remaining-path u1) ERR_INVALID_PATH))
                  (pool (unwrap! (contract-call? (var-get factory-address) get-pool current-token token-out) ERR_POOL_NOT_FOUND))
                  (is-final-hop (is-eq path-length u2)))
              (let ((amount-out (if is-final-hop
                    min-amount-out
                    (unwrap! (contract-call? pool get-amount-out current-amount current-token token-out)
                            ERR_INSUFFICIENT_LIQUIDITY)
                  )))
                (let ((swap-result (contract-call? pool swap
                      current-token
                      token-out
                      current-amount
                      amount-out
                      (if is-final-hop recipient (as-contract tx-sender))
                    )))
                  (if (is-ok swap-result)
                    (ok (tuple
                      (current-token token-out)
                      (current-amount (unwrap-panic swap-result))
                      (remaining-path (slice remaining-path u1 u5))
                    ))
                    (err (unwrap-err swap-result))
                  )
                )
              )
            )
          )
        )
      )
      ((err e) (err e))
    ))
    (ok (tuple
      (current-token token-in)
      (current-amount amount-in)
      (remaining-path path)
    ))
    (range u0 (len path))
  )
)

;; Main entry point for token swaps
(define-public (get-factory-address)
  (ok (var-get factory-address))
)

(define-public (swap-exact-tokens-for-tokens 
    (amount-in uint)
    (min-amount-out uint)
    (path (list 5 principal))
    (to principal)
    (deadline uint)
  )
  (if (>= block-height deadline)
    (err ERR_DEADLINE_PASSED)
    (if (or (is-eq (len path) u0) (> (len path) u5))
      (err ERR_INVALID_PATH)
      (let ((token-in (unwrap! (element-at path u0) ERR_INVALID_PATH)))
      (let ((balance-before (contract-call? token-in balance-of tx-sender)))
        (begin
            ;; Transfer tokens to contract
            (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))

            ;; Process the swap through all hops
            (match (process-multi-hop token-in path amount-in min-amount-out deadline to)
              success (ok true)
              error (begin
                ;; On error, refund any tokens
                (try! (contract-call? token-in transfer amount-in (as-contract tx-sender) tx-sender none))
                (err ERR_TRANSFER_FAILED)
              )
            )
        )
      ))
    )
  )
)


;; --- Admin Functions ---
(define-public (set-factory (new-factory principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; (asserts! (is-ok (contract-call? new-factory get-pool .token-a .token-b)) ERR_INVALID_PATH) ;; Removed hardcoded token check
    (var-set factory-address new-factory)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (contract-call? new-owner get-false) false) ERR_INVALID_PATH)
    (var-set contract-owner new-owner)
    (ok true)
  )
)



>>>>>>> 8bce9a06227aa3d139e549a8bea28e27bd6665af
