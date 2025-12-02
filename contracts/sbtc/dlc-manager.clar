;; dlc-manager.clar
;; Manages Discreet Log Contracts for Native Bitcoin Lending
;; Implements dlc-manager-trait

(use-trait dlc-manager-trait .dimensional-traits.dlc-manager-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_DLC_EXISTS (err u6001))
(define-constant ERR_DLC_NOT_FOUND (err u6002))
(define-constant ERR_INVALID_STATE (err u6003))

(define-constant STATUS_OPEN "open")
(define-constant STATUS_CLOSED "closed")
(define-constant STATUS_LIQUIDATED "liquidated")

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var authorized-lending-contract principal tx-sender) ;; The contract allowed to trigger liquidations

;; --- Data Maps ---
(define-map dlcs 
  { dlc-uuid: (buff 32) } 
  { 
    owner: principal,
    value-locked: uint,
    loan-id: uint,
    status: (string-ascii 20),
    closing-price: (optional uint)
  }
)

;; --- Public Functions ---

(define-public (set-authorized-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set authorized-lending-contract contract)
    (ok true)
  )
)

(define-public (register-dlc (dlc-uuid (buff 32)) (value-locked uint) (owner principal) (loan-id uint))
  (begin
    ;; Only authorized contracts (e.g. the lending pool) or the DLC oracle system can register
    ;; For v1, we allow the owner to register, but in prod this should be gated by the DLC oracle signature verification
    (asserts! (is-none (map-get? dlcs { dlc-uuid: dlc-uuid })) ERR_DLC_EXISTS)
    
    (map-set dlcs { dlc-uuid: dlc-uuid } {
      owner: owner,
      value-locked: value-locked,
      loan-id: loan-id,
      status: STATUS_OPEN,
      closing-price: none
    })
    
    (print {
      event: "dlc-registered",
      dlc-uuid: dlc-uuid,
      owner: owner,
      value-locked: value-locked
    })
    (ok true)
  )
)

(define-public (close-dlc (dlc-uuid (buff 32)))
  (let (
    (dlc (unwrap! (map-get? dlcs { dlc-uuid: dlc-uuid }) ERR_DLC_NOT_FOUND))
  )
    ;; Only authorized contract can close (e.g. upon repayment)
    (asserts! (is-eq tx-sender (var-get authorized-lending-contract)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dlc) STATUS_OPEN) ERR_INVALID_STATE)

    (map-set dlcs { dlc-uuid: dlc-uuid } (merge dlc { status: STATUS_CLOSED }))
    
    (print {
      event: "dlc-closed",
      dlc-uuid: dlc-uuid
    })
    (ok true)
  )
)

(define-public (liquidate-dlc (dlc-uuid (buff 32)))
  (let (
    (dlc (unwrap! (map-get? dlcs { dlc-uuid: dlc-uuid }) ERR_DLC_NOT_FOUND))
  )
    ;; Only authorized contract (Liquidation Engine) can trigger this
    (asserts! (is-eq tx-sender (var-get authorized-lending-contract)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dlc) STATUS_OPEN) ERR_INVALID_STATE)

    ;; In a real system, this would emit an event picked up by the DLC Oracle/Attestors
    ;; to broadcast the liquidation transaction to Bitcoin L1.
    
    (map-set dlcs { dlc-uuid: dlc-uuid } (merge dlc { status: STATUS_LIQUIDATED }))
    
    (print {
      event: "dlc-liquidated",
      dlc-uuid: dlc-uuid,
      info: "Attestors should broadcast liquidation tx"
    })
    (ok true)
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-dlc-info (dlc-uuid (buff 32)))
  (ok (map-get? dlcs { dlc-uuid: dlc-uuid }))
)
