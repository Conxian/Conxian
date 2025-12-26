;; migration-adapter.clar
;; Compatibility layer for transitioning from guardian system to Stacks native architecture
;; Provides backward compatibility during migration period

(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_MIGRATION_COMPLETE (err u9001))

;; Migration state tracking
(define-data-var migration-active bool true)
(define-data-var legacy-guardian-active bool false)
(define-data-var native-automation-active bool false)

;; Contract references
(define-data-var block-automation-manager principal tx-sender)
(define-data-var native-stacking-operator principal tx-sender)
(define-data-var native-multisig-controller principal tx-sender)

;; Legacy guardian registry (for compatibility)
(define-map legacy-guardians principal {
  bonded-cxd: uint,
  active: bool,
  migrated-to-native: bool,
})

;; Migration tracking
(define-map migration-status principal {
  guardian-migrated: bool,
  native-operator-registered: bool,
  migration-date: uint,
})

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Initialize migration adapter
(define-public (initialize-migration
    (block-automation principal)
    (native-stacking principal)
    (native-multisig principal)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (var-set block-automation-manager block-automation)
    (var-set native-stacking-operator native-stacking)
    (var-set native-multisig-controller native-multisig)
    
    (var-set native-automation-active true)
    
    (print {
      event: "migration-adapter-initialized",
      block-automation: block-automation,
      native-stacking: native-stacking,
      native-multisig: native-multisig,
      initialized-at: block-height,
    })
    (ok true)
  )
)

;; Legacy guardian registration (compatibility function)
(define-public (register-legacy-guardian
    (guardian principal)
    (amount uint)
    (cxd-token <sip-010-ft-trait>)
  )
  (begin
    (asserts! (var-get migration-active) ERR_MIGRATION_COMPLETE)
    (asserts! (var-get legacy-guardian-active) ERR_UNAUTHORIZED)
    
    ;; Transfer CXD for bonding (legacy behavior)
    (try! (contract-call? cxd-token transfer amount guardian (as-contract tx-sender) none))
    
    ;; Register in legacy system
    (map-set legacy-guardians guardian {
      bonded-cxd: amount,
      active: true,
      migrated-to-native: false,
    })
    
    ;; Auto-migrate to native system if possible
    (try! (migrate-guardian-to-native guardian))
    
    (print {
      event: "legacy-guardian-registered",
      guardian: guardian,
      amount: amount,
      auto-migrated: true,
    })
    (ok true)
  )
)

;; Migrate guardian to native system
(define-public (migrate-guardian-to-native (guardian principal))
  (begin
    (asserts! (var-get migration-active) ERR_MIGRATION_COMPLETE)
    
    (let ((legacy-data (map-get? legacy-guardians guardian)))
      (if (is-some legacy-data)
        (let ((data (unwrap-panic legacy-data)))
          (if (not (get migrated-to-native data))
            (begin
              ;; Register as native operator
              (try! (contract-call? .native-stacking-operator register-operator
                guardian
              ))
              
              ;; Update legacy record
              (map-set legacy-guardians guardian
                (merge data {migrated-to-native: true})
              )
              
              ;; Track migration status
              (map-set migration-status guardian {
                guardian-migrated: true,
                native-operator-registered: true,
                migration-date: block-height,
              })
              
              (print {
                event: "guardian-migrated-to-native",
                guardian: guardian,
                migrated-at: block-height,
              })
              (ok true)
            )
            (ok { already-migrated: true })
          )
        )
        (err ERR_UNAUTHORIZED)
      )
    )
  )
)

;; Execute operation with fallback to legacy system
(define-public (execute-operation
    (operation-id uint)
    (use-native bool)
  )
  (begin
    (if use-native
      ;; Use native automation system - use hardcoded contract
      (begin
        (asserts! (var-get native-automation-active) ERR_UNAUTHORIZED)
        (contract-call? .block-automation-manager execute-authorized-operation
          operation-id
        )
      )
      ;; Use legacy guardian system
      (begin
        (asserts! (var-get legacy-guardian-active) ERR_UNAUTHORIZED)
        (asserts! (is-valid-legacy-guardian tx-sender) ERR_UNAUTHORIZED)
        
        (print {
          event: "legacy-operation-executed",
          guardian: tx-sender,
          operation-id: operation-id,
        })
        (ok true)
      )
    )
  )
)

;; Check if legacy guardian is valid
(define-private (is-valid-legacy-guardian (guardian principal))
  (match (map-get? legacy-guardians guardian)
    guardian-data (and (get active guardian-data) (> (get bonded-cxd guardian-data) u0))
    false
  )
)

;; Complete migration (disable legacy system)
(define-public (complete-migration)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    ;; Disable legacy guardian system
    (var-set legacy-guardian-active false)
    (var-set migration-active false)
    
    ;; Ensure native system is active
    (asserts! (var-get native-automation-active) ERR_UNAUTHORIZED)
    
    (print {
      event: "migration-completed",
      completed-at: block-height,
      legacy-system-disabled: true,
      native-system-active: true,
    })
    (ok true)
  )
)

;; Emergency fallback (reactivate legacy system)
(define-public (emergency-activate-legacy)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (var-set legacy-guardian-active true)
    (var-set migration-active true)
    
    (print {
      event: "legacy-system-emergency-activated",
      activated-at: block-height,
      activated-by: tx-sender,
    })
    (ok true)
  )
)

;; Read-only views
(define-read-only (get-migration-status)
  (ok {
    migration-active: (var-get migration-active),
    legacy-guardian-active: (var-get legacy-guardian-active),
    native-automation-active: (var-get native-automation-active),
    total-legacy-guardians: (len (map-keys legacy-guardians)),
    migrated-guardians: (len (filter is-migrated (map-keys legacy-guardians))),
  })
)

(define-read-only (get-guardian-migration-status (guardian principal))
  (map-get? migration-status guardian)
)

(define-read-only (is-legacy-guardian-active (guardian principal))
  (ok (is-valid-legacy-guardian guardian))
)

;; Helper function for filtering migrated guardians
(define-private (is-migrated (guardian principal))
  (let ((status (map-get? migration-status guardian)))
    (if (some? status)
      (get guardian-migrated (unwrap! status false))
      false
    )
  )
)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Batch migration for all legacy guardians
(define-public (migrate-all-guardians)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (let ((guardian-list (map-keys legacy-guardians)))
      (fold migrate-guardian-helper guardian-list true)
    )
  )
)

(define-private (migrate-guardian-helper (guardian principal) (result bool))
  (if (not result) 
    false
    (match (map-get? legacy-guardians guardian)
      legacy-data (if (not (get migrated-to-native legacy-data))
        (begin
          ;; Use hardcoded contract reference
          (match (contract-call? 'STXS4928S95SEP4YNJMH7V9Z8RY8J7PZ5RG74TXF.native-stacking-operator-v3 register-operator guardian)
            success (begin
              (map-set legacy-guardians guardian
                (merge legacy-data {migrated-to-native: true})
              )
              (map-set migration-status guardian {
                guardian-migrated: true,
                native-operator-registered: true,
                migration-date: block-height,
              })
              true
            )
            error false
          )
        )
        true
      )
      true
    )
  )
)
