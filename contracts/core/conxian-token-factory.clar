;; conxian-token-factory.clar
;; Automated Asset Deployment & Listing System
;;
;; @desc Allows governance or whitelisted users to deploy new SIP-010 tokens 
;; and automatically register them with the DEX and Lending protocols.

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait factory-trait .defi-traits.factory-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ASSET_EXISTS (err u1001))
(define-constant ERR_DEPLOY_FAILED (err u1002))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var fee-deploy-asset uint u100000000) ;; 100 STX fee to deploy

;; --- Maps ---
(define-map deployed-assets
    { symbol: (string-ascii 10) }
    {
        contract: principal,
        deployer: principal,
        created-at: uint
    }
)

;; --- Admin ---

(define-public (set-deploy-fee (fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set fee-deploy-asset fee)
        (ok true)
    )
)

;; --- Public ---

;; @desc Registers an existing asset into the Conxian ecosystem
;; This is a registry function, actual deployment happens via standard Stacks tools for now
;; In a full version, this would call `contract-deploy` via a trait or factory pattern if Stacks supported dynamic deploys
(define-public (register-asset (token <sip-010-trait>) (symbol (string-ascii 10)))
    (let (
        (token-contract (contract-of token))
    )
        (asserts! (is-none (map-get? deployed-assets { symbol: symbol })) ERR_ASSET_EXISTS)
        
        ;; Pay fee
        (if (> (var-get fee-deploy-asset) u0)
            (try! (stx-transfer? (var-get fee-deploy-asset) tx-sender (var-get contract-owner)))
            true
        )
        
        (map-set deployed-assets 
            { symbol: symbol }
            {
                contract: token-contract,
                deployer: tx-sender,
                created-at: block-height
            }
        )
        (ok true)
    )
)

(define-read-only (get-asset-by-symbol (symbol (string-ascii 10)))
    (map-get? deployed-assets { symbol: symbol })
)
