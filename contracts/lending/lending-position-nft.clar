;; lending-position-nft.clar
;; Comprehensive NFT system for lending protocol positions
;; Represents borrower positions, lender positions, and liquidation events

(use-trait sip-009-nft-trait .defi-traits.sip-009-nft-trait)
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

(impl-trait .defi-traits.sip-009-nft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u7000))
(define-constant ERR_INVALID_POSITION (err u7001))
(define-constant ERR_POSITION_NOT_FOUND (err u7002))
(define-constant ERR_ZERO_AMOUNT (err u7003))
(define-constant ERR_INVALID_ASSET (err u7004))
(define-constant ERR_POSITION_CLOSED (err u7005))

;; NFT Type Constants
(define-constant NFT_TYPE_BORROW_POSITION u1)     ;; Borrower loan position
(define-constant NFT_TYPE_LENDER_POSITION u2)     ;; Lender supply position
(define-constant NFT_TYPE_LIQUIDATION u3)         ;; Liquidation event
(define-constant NFT_TYPE_COLLATERAL u4)          ;; Collateral position
(define-constant NFT_TYPE_INTEREST_EARNED u5)      ;; Interest earnings position

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)
(define-data-var base-token-uri (optional (string-utf8 256)) none)

;; ===== NFT Definition =====
(define-non-fungible-token lending-position-nft uint)

;; ===== Enhanced Position Metadata =====
(define-map lending-position-metadata
  { token-id: uint }
  {
    owner: principal,
    nft-type: uint,                              ;; Position type
    asset-token: principal,                       ;; Underlying asset
    asset-amount: uint,                          ;; Position amount
    collateral-token: (optional principal),       ;; Collateral asset (for borrows)
    collateral-amount: (optional uint),            ;; Collateral amount
    interest-rate: uint,                          ;; Current interest rate (basis points)
    creation-block: uint,                         ;; When position was created
    last-update-block: uint,                      ;; Last activity
    health-factor: (optional uint),               ;; Health factor (for borrows)
    liquidation-price: (optional uint),            ;; Liquidation price (for borrows)
    accumulated-interest: uint,                   ;; Total interest earned/paid
    position-status: uint,                         ;; 1=active, 2=closed, 3=liquidated
    risk-tier: uint,                              ;; 1=low, 2=medium, 3=high risk
    revenue-share: uint,                          ;; Revenue sharing percentage
    governance-weight: uint,                      ;; Enhanced governance weight
    visual-tier: uint,                            ;; Visual appearance tier
    special-privileges: (list 10 (string-ascii 50)) ;; Special abilities
  })

;; ===== Position Tracking Maps =====
(define-map user-positions
  { user: principal, position-type: uint }
  { token-ids: (list 100 uint) })

(define-map asset-positions
  { asset: principal, position-type: uint }
  { total-positions: uint, total-value: uint })

(define-map liquidation-events
  { liquidation-id: uint }
  {
    borrower: principal,
    liquidator: principal,
    collateral-token: principal,
    collateral-amount: uint,
    debt-token: principal,
    debt-amount: uint,
    liquidation-block: uint,
    nft-token-id: uint
  })

(define-data-var next-liquidation-id uint u1)

;; ===== Public Functions =====

;; @desc Creates a new borrower position NFT
;; @param asset-token The borrowed asset
;; @param asset-amount The amount borrowed
;; @param collateral-token The collateral asset
;; @param collateral-amount The collateral amount
;; @param interest-rate The interest rate in basis points
;; @returns Response with new token ID or error
(define-public (create-borrower-position-nft
  (asset-token <sip-010-ft-trait>)
  (asset-amount uint)
  (collateral-token <sip-010-ft-trait>)
  (collateral-amount uint)
  (interest-rate uint))
  (begin
    (asserts! (> asset-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (> collateral-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= interest-rate u0) ERR_INVALID_INPUT)
    
    (let ((token-id (var-get next-token-id))
          (asset-principal (contract-of asset-token))
          (collateral-principal (contract-of collateral-token))
          (health-factor (/ (* collateral-amount u10000) asset-amount)))
      
      ;; Create position metadata
      (map-set lending-position-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_BORROW_POSITION,
          asset-token: asset-principal,
          asset-amount: asset-amount,
          collateral-token: (some collateral-principal),
          collateral-amount: (some collateral-amount),
          interest-rate: interest-rate,
          creation-block: block-height,
          last-update-block: block-height,
          health-factor: (some health-factor),
          liquidation-price: (some (/ (* asset-amount u10000) health-factor)),
          accumulated-interest: u0,
          position-status: u1, ;; Active
          risk-tier: (calculate-risk-tier asset-amount collateral-amount),
          revenue-share: u200, ;; 2% revenue share
          governance-weight: u1200, ;; 1.2x governance weight
          visual-tier: (calculate-borrow-visual-tier asset-amount),
          special-privileges: (list "borrow-access" "collateral-management" "rate-monitoring")
        })
      
      ;; Update user positions
      (update-user-positions tx-sender NFT_TYPE_BORROW_POSITION token-id)
      
      ;; Update asset positions
      (update-asset-positions asset-principal NFT_TYPE_BORROW_POSITION asset-amount)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "borrower-position-nft-created",
        token-id: token-id,
        owner: tx-sender,
        asset-token: asset-principal,
        asset-amount: asset-amount,
        collateral-token: collateral-principal,
        collateral-amount: collateral-amount,
        health-factor: health-factor,
        risk-tier: (calculate-risk-tier asset-amount collateral-amount)
      })
      
      (ok token-id)
    )
  )
)

;; @desc Creates a new lender position NFT
;; @param asset-token The supplied asset
;; @param asset-amount The amount supplied
;; @param interest-rate The interest rate in basis points
;; @returns Response with new token ID or error
(define-public (create-lender-position-nft
  (asset-token <sip-010-ft-trait>)
  (asset-amount uint)
  (interest-rate uint))
  (begin
    (asserts! (> asset-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (>= interest-rate u0) ERR_INVALID_INPUT)
    
    (let ((token-id (var-get next-token-id))
          (asset-principal (contract-of asset-token)))
      
      ;; Create position metadata
      (map-set lending-position-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_LENDER_POSITION,
          asset-token: asset-principal,
          asset-amount: asset-amount,
          collateral-token: none,
          collateral-amount: none,
          interest-rate: interest-rate,
          creation-block: block-height,
          last-update-block: block-height,
          health-factor: none,
          liquidation-price: none,
          accumulated-interest: u0,
          position-status: u1, ;; Active
          risk-tier: (calculate-lender-risk-tier asset-amount),
          revenue-share: u300, ;; 3% revenue share
          governance-weight: u1300, ;; 1.3x governance weight
          visual-tier: (calculate-lender-visual-tier asset-amount),
          special-privileges: (list "supply-access" "interest-earnings" "withdrawal-priority")
        })
      
      ;; Update user positions
      (update-user-positions tx-sender NFT_TYPE_LENDER_POSITION token-id)
      
      ;; Update asset positions
      (update-asset-positions asset-principal NFT_TYPE_LENDER_POSITION asset-amount)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "lender-position-nft-created",
        token-id: token-id,
        owner: tx-sender,
        asset-token: asset-principal,
        asset-amount: asset-amount,
        interest-rate: interest-rate,
        risk-tier: (calculate-lender-risk-tier asset-amount)
      })
      
      (ok token-id)
    )
  )
)

;; @desc Creates a liquidation event NFT
;; @param borrower The borrower being liquidated
;; @param liquidator The liquidator
;; @param collateral-token The collateral asset
;; @param collateral-amount The collateral amount
;; @param debt-token The debt asset
;; @param debt-amount The debt amount
;; @returns Response with new token ID or error
(define-public (create-liquidation-nft
  (borrower principal)
  (liquidator principal)
  (collateral-token principal)
  (collateral-amount uint)
  (debt-token principal)
  (debt-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> collateral-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (> debt-amount u0) ERR_ZERO_AMOUNT)
    
    (let ((token-id (var-get next-token-id))
          (liquidation-id (var-get next-liquidation-id)))
      
      ;; Create liquidation NFT metadata
      (map-set lending-position-metadata
        { token-id: token-id }
        {
          owner: liquidator,
          nft-type: NFT_TYPE_LIQUIDATION,
          asset-token: debt-token,
          asset-amount: debt-amount,
          collateral-token: (some collateral-token),
          collateral-amount: (some collateral-amount),
          interest-rate: u0,
          creation-block: block-height,
          last-update-block: block-height,
          health-factor: none,
          liquidation-price: none,
          accumulated-interest: u0,
          position-status: u3, ;; Liquidated
          risk-tier: u3, ;; High risk (liquidation event)
          revenue-share: u500, ;; 5% revenue share for liquidators
          governance-weight: u1500, ;; 1.5x governance weight
          visual-tier: u5, ;; Legendary - animated border
          special-privileges: (list "liquidation-access" "priority-borrow" "risk-monitoring")
        })
      
      ;; Record liquidation event
      (map-set liquidation-events
        { liquidation-id: liquidation-id }
        {
          borrower: borrower,
          liquidator: liquidator,
          collateral-token: collateral-token,
          collateral-amount: collateral-amount,
          debt-token: debt-token,
          debt-amount: debt-amount,
          liquidation-block: block-height,
          nft-token-id: token-id
        })
      
      ;; Update liquidator positions
      (update-user-positions liquidator NFT_TYPE_LIQUIDATION token-id)
      
      ;; Mint NFT to liquidator
      (mint-nft token-id liquidator)
      
      (var-set next-token-id (+ token-id u1))
      (var-set next-liquidation-id (+ liquidation-id u1))
      
      (print {
        event: "liquidation-nft-created",
        token-id: token-id,
        liquidation-id: liquidation-id,
        borrower: borrower,
        liquidator: liquidator,
        collateral-token: collateral-token,
        collateral-amount: collateral-amount,
        debt-token: debt-token,
        debt-amount: debt-amount
      })
      
      (ok token-id)
    )
  )
)

;; @desc Updates position interest accumulation
;; @param token-id The position token ID
;; @param interest-amount The interest amount to add
;; @returns Response with success status
(define-public (update-position-interest (token-id uint) (interest-amount uint))
  (let ((position (unwrap! (map-get? lending-position-metadata { token-id: token-id }) ERR_POSITION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (asserts! (> interest-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (= (get position-status position) u1) ERR_POSITION_CLOSED) ;; Must be active
    
    (map-set lending-position-metadata
      { token-id: token-id }
      (merge position {
        accumulated-interest: (+ (get accumulated-interest position) interest-amount),
        last-update-block: block-height
      }))
    
    (print {
      event: "position-interest-updated",
      token-id: token-id,
      owner: tx-sender,
      interest-amount: interest-amount,
      total-accumulated: (+ (get accumulated-interest position) interest-amount)
    })
    
    (ok true)
  )
)

;; @desc Closes a position and updates status
;; @param token-id The position token ID
;; @returns Response with success status
(define-public (close-position (token-id uint))
  (let ((position (unwrap! (map-get? lending-position-metadata { token-id: token-id }) ERR_POSITION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (asserts! (= (get position-status position) u1) ERR_POSITION_CLOSED) ;; Must be active
    
    (map-set lending-position-metadata
      { token-id: token-id }
      (merge position {
        position-status: u2, ;; Closed
        last-update-block: block-height
      }))
    
    (print {
      event: "position-closed",
      token-id: token-id,
      owner: tx-sender,
      nft-type: (get nft-type position),
      final-interest: (get accumulated-interest position)
    })
    
    (ok true)
  )
)

;; ===== SIP-009 Implementation =====

(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (ok (var-get base-token-uri)))

(define-read-only (get-owner (token-id uint))
  (match (map-get? lending-position-metadata { token-id: token-id })
    position (ok (some (get owner position)))
    (ok none)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((position (unwrap! (map-get? lending-position-metadata { token-id: token-id }) ERR_POSITION_NOT_FOUND)))
    (asserts! (is-eq sender (get owner position)) ERR_UNAUTHORIZED)
    (asserts! (= (get position-status position) u1) ERR_POSITION_CLOSED) ;; Only active positions can be transferred
    
    ;; Transfer NFT ownership
    (nft-transfer? lending-position-nft token-id sender recipient)
    
    ;; Update position metadata
    (map-set lending-position-metadata
      { token-id: token-id }
      (merge position { owner: recipient }))
    
    ;; Update user position tracking
    (update-user-positions-on-transfer sender recipient (get nft-type position) token-id)
    
    (print {
      event: "lending-position-nft-transferred",
      token-id: token-id,
      from: sender,
      to: recipient,
      nft-type: (get nft-type position)
    })
    
    (ok true)
  )
)

;; ===== Helper Functions =====

(define-private (mint-nft (token-id uint) (recipient principal))
  (nft-mint? lending-position-nft token-id recipient))

(define-private (calculate-risk-tier (asset-amount uint) (collateral-amount uint))
  (let ((collateral-ratio (/ (* collateral-amount u100) asset-amount)))
    (cond
      ((>= collateral-ratio u200) u1) ;; Low risk - 200%+ collateralization
      ((>= collateral-ratio u150) u2) ;; Medium risk - 150-200% collateralization
      (true u3))))                   ;; High risk - <150% collateralization

(define-private (calculate-lender-risk-tier (asset-amount uint))
  (cond
    ((>= asset-amount u10000000) u1) ;; Low risk - large position
    ((>= asset-amount u1000000) u2)  ;; Medium risk - medium position
    (true u3)))                      ;; High risk - small position

(define-private (calculate-borrow-visual-tier (asset-amount uint))
  (cond
    ((>= asset-amount u50000000) u5) ;; Legendary - golden animated
    ((>= asset-amount u10000000) u4) ;; Epic - silver glowing
    ((>= asset-amount u1000000) u3)  ;; Rare - bronze special
    (true u2)))                       ;; Common - standard

(define-private (calculate-lender-visual-tier (asset-amount uint))
  (cond
    ((>= asset-amount u50000000) u5) ;; Legendary - golden animated
    ((>= asset-amount u10000000) u4) ;; Epic - silver glowing
    ((>= asset-amount u1000000) u3)  ;; Rare - bronze special
    (true u2)))                       ;; Common - standard

(define-private (update-user-positions (user principal) (position-type uint) (token-id uint))
  (let ((current-positions (default-to (list) (map-get? user-positions { user: user, position-type: position-type }))))
    (new-positions (append current-positions (list token-id))))
    (map-set user-positions { user: user, position-type: position-type } { token-ids: new-positions })))

(define-private (update-user-positions-on-transfer (from principal) (to principal) (position-type uint) (token-id uint))
  ;; Remove from sender
  (let ((from-positions (default-to (list) (map-get? user-positions { user: from, position-type: position-type })))
        (to-positions (default-to (list) (map-get? user-positions { user: to, position-type: position-type }))))
    (new-from-positions (filter (lambda (id) (not (= id token-id))) from-positions))
    (new-to-positions (append to-positions (list token-id))))
    (map-set user-positions { user: from, position-type: position-type } { token-ids: new-from-positions })
    (map-set user-positions { user: to, position-type: position-type } { token-ids: new-to-positions })))

(define-private (update-asset-positions (asset principal) (position-type uint) (amount uint))
  (let ((current-positions (default-to { total-positions: u0, total-value: u0 } (map-get? asset-positions { asset: asset, position-type: position-type }))))
    (map-set asset-positions 
      { asset: asset, position-type: position-type }
      { 
        total-positions: (+ (get total-positions current-positions) u1),
        total-value: (+ (get total-value current-positions) amount)
      })))

;; ===== Read-Only Functions =====

(define-read-only (get-position-metadata (token-id uint))
  (map-get? lending-position-metadata { token-id: token-id }))

(define-read-only (get-user-positions (user principal) (position-type uint))
  (map-get? user-positions { user: user, position-type: position-type }))

(define-read-only (get-asset-positions (asset principal) (position-type uint))
  (map-get? asset-positions { asset: asset, position-type: position-type }))

(define-read-only (get-liquidation-event (liquidation-id uint))
  (map-get? liquidation-events { liquidation-id: liquidation-id }))

(define-read-only (get-user-position-count (user principal) (position-type uint))
  (let ((positions (default-to { token-ids: (list) } (map-get? user-positions { user: user, position-type: position-type }))))
    (ok (len (get token-ids positions)))))
