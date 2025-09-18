;; dex-router.clar
;; Conxian DEX Router - Routes trades across DEX pools and bond markets
;; Non-custodial, immutable design with bond trading support

;; --- Traits ---
(use-trait std-constants 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.standard-constants-trait)
(use-trait bond-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bond-trait)
(use-trait router-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.router-trait)
(use-trait sip-010-ft-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip-010-ft-trait)
(use-trait pool-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.pool-trait)

(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.router-trait)

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
(define-data-var factory-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.dex-factory)
(define-data-var bond-factory-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.bond-factory)
(define-data-var locked bool false)  ;; Reentrancy guard

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
        (asserts! (>= amount-out min-amount-out) ERR_INSUFFICIENT_OUTPUT)
        
        ;; Transfer bonds and update state
        (try! (contract-call? bond-in transfer amount-in tx-sender (as-contract tx-sender) none))
        (try! (contract-call? bond-out transfer amount-out (as-contract tx-sender) tx-sender none))
        
        ;; Update market data
        (try! (update-bond-volume bond-in amount-in))
        (try! (update-bond-volume bond-out amount-out))
        
        (ok {
          amount-in: amount-in,
          amount-out: amount-out,
          fee: fee,
          price: price
        })
      )
    )
  ))))
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
              (ok {
                lp-tokens: lp-tokens,
                bond-amount: bond-amount,
                token-amount: token-amount
              })
            )
          )
          (err e) (begin
            ;; Create new pool and add initial liquidity
            (let ((new-pool (try! (contract-call? factory create-pool bond-contract token-contract))))
              (let ((lp-tokens (try! (contract-call? new-pool add-liquidity bond-amount token-amount min-lp-tokens))))
                (ok {
                  pool: new-pool,
                  lp-tokens: lp-tokens,
                  bond-amount: bond-amount,
                  token-amount: token-amount
                })
              )
            )
          )
        )
      )
    )
  ))))
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
    (map-set bond-markets bond-contract {
      is-active: true,
      min-trade-amount: min-trade-amount,
      max-trade-amount: max-trade-amount,
      trading-fee: trading-fee,
      last-price: u0,
      volume-24h: u0,
      last-updated: block-height
    })
    (ok true)
  )
)

(define-public (disable-bond-market (bond-contract principal))
  (begin
    (try! (only-owner))
    (match (map-get? bond-markets bond-contract)
      market (begin
        (map-set bond-markets bond-contract (merge market {
          is-active: false
        }))
        (ok true)
      )
      (err e) (err ERR_INVALID_BOND)
    )
  )
)

;; Execute a single swap
(define-private (process-next-hop
    (token-in principal)
    (path (list 5 principal))
    (amount-in uint)
    (min-amount-out uint)
    (deadline uint)
    (recipient principal)
    (depth uint))
  (let (
      (token-out (unwrap! (element-at path 0) (err ERR_INVALID_PATH)))
      (remaining-path (unwrap! (slice path 1 u5) (err ERR_INVALID_PATH)))
      (pool (unwrap! (contract-call? (var-get factory-address) get-pool token-in token-out) (err ERR_POOL_NOT_FOUND)))
      (amount-out (unwrap! (contract-call? pool get-amount-out amount-in token-in token-out) (err ERR_SWAP_FAILED)))
    )
    (if (is-eq (len remaining-path) u0)
      ;; Last hop - execute the swap
      (contract-call? pool swap token-in token-out amount-in amount-out recipient)
      ;; More hops - process the next one
      (match (contract-call? pool swap token-in token-out amount-in amount-out (as-contract tx-sender))
        success (process-next-hop token-out remaining-path amount-out min-amount-out deadline recipient (+ depth u1))
        error error
      )
    )
  )
)

;; Main entry point for token swaps
(define-public (get-factory-address)
  (ok (var-get factory-address))
)

(define-private (execute-swap
    (token-in principal)
    (token-out principal)
    (amount-in uint)
    (min-amount-out uint)
    (deadline uint)
    (is-final-hop bool)
  )
  (let ((pool (unwrap! (get-pool token-in token-out) (err ERR_POOL_NOT_FOUND))))
    (match (contract-call? pool get-reserves)
      (ok { token-x-reserve: x, token-y-reserve: y, x-to-y: x-to-y })
        (let ((amount-out (calculate-amount-out amount-in x y x-to-y)))
          (if (or is-final-hop (>= amount-out min-amount-out))
            (match (as-contract (contract-call? 
                                token-in 
                                transfer 
                                amount-in 
                                (as-contract tx-sender) 
                                pool 
                                none))
              true (let ((result (contract-call? 
                                 pool 
                                 swap 
                                 amount-in 
                                 (if is-final-hop min-amount-out u0) 
                                 tx-sender 
                                 x-to-y 
                                 deadline)))
                     (match result
                       (ok val) (ok {
                         amount-out: amount-out,
                         token-out: token-out,
                         is-final-hop: is-final-hop
                       })
                       err (err (unwrap-err result))
                     )
                   )
              false (err ERR_TRANSFER_FAILED)
            )
            (err ERR_INSUFFICIENT_OUTPUT)
          )
        )
      err (err (unwrap-err err))
    )
  )
)

(define-public (swap-exact-tokens-for-tokens 
    (amount-in uint)
    (min-amount-out uint)
    (path (list 5 principal))
    (deadline uint))
  (begin
    ;; Input validation
    (asserts! (> amount-in u0) ERR_ZERO_AMOUNT)
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
    
    ;; Simple path validation (no recursive calls)
    (let ((length (len path)))
      (asserts! (and (>= length u2) (<= length u5)) ERR_INVALID_PATH)
      (fold (lambda (i result)
        (if (is-err result)
          result
          (let ((token (unwrap! (element-at path i) ERR_INVALID_PATH)))
            (if (and (< (+ i u1) length) (is-eq token (unwrap! (element-at path (+ i u1)) ERR_INVALID_PATH)))
              (err ERR_DUPLICATE_TOKENS)
              (ok true)
            )
          )
        )
      ) (ok true) (list u0 u1 u2 u3 u4))
    )
    (try! (validate-path path))
    
    (let ((token-in (unwrap! (element-at path u0) ERR_INVALID_PATH))
          (token-out (unwrap! (element-at path u1) ERR_INVALID_PATH))
          (is-final-hop (is-eq (len path) u2)))
      
      ;; Transfer input tokens to router
      (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
      
      ;; Execute the swap
      (match (execute-swap token-in token-out amount-in 
                         (if is-final-hop min-amount-out u0)
                         deadline
                         is-final-hop)
        err (err (unwrap-err err))
        ok (let ((swap-result (unwrap ok))
                 (amount-out (get amount-out swap-result)))
             
             (if is-final-hop
               ;; If this is the final hop, transfer tokens to user
               (match (as-contract (contract-call? token-out 
                                                 transfer 
                                                 amount-out 
                                                 (as-contract tx-sender) 
                                                 tx-sender 
                                                 none))
                 true (ok amount-out)
                 false (err ERR_TRANSFER_FAILED)
               )
               
               ;; Otherwise, process the next hop
               (let ((next-token (unwrap! (element-at path u2) ERR_INVALID_PATH)))
                 (match (execute-swap token-out next-token amount-out
                                    min-amount-out
                                    deadline
                                    true)
                   err (err (unwrap-err err))
                   ok (let ((final-result (unwrap ok))
                           (final-amount (get amount-out final-result)))
                        (match (as-contract (contract-call? next-token
                                                          transfer
                                                          final-amount
                                                          (as-contract tx-sender)
                                                          tx-sender
                                                          none))
                          true (ok final-amount)
                          false (err ERR_TRANSFER_FAILED)
                        )
                      )
                 )
               )
             )
           )
      )
    )
  ))

;; --- Admin Functions ---
(define-public (set-factory (new-factory principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-ok (contract-call? new-factory get-pool 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-a 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.token-b)) ERR_INVALID_PATH)
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