;; upgrade-controller.clar

;; Manages safe protocol upgrades with timelock and approval mechanisms

;; ===== Traits =====
(use-trait upgrade-controller-trait .governance.upgrade-controller-trait)
(use-trait upgrade_controller_trait .governance.upgrade-controller-trait)

;; ===== Error Codes =====
(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_UPGRADE_NOT_READY (err u4002))
(define-constant ERR_UPGRADE_EXPIRED (err u4003))
(define-constant ERR_INVALID_UPGRADE (err u4004))
(define-constant ERR_ALREADY_EXECUTED (err u4005))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u4006))
(define-constant ERR_ALREADY_APPROVED (err u4007))

;; ===== Upgrade Types =====
(define-constant UPGRADE_CONTRACT u1)
(define-constant UPGRADE_PARAMETER u2)
(define-constant UPGRADE_IMPLEMENTATION u3)

;; ===== Timelock Settings =====
(define-constant UPGRADE_TIMELOCK_BLOCKS u1008) ;; ~16.8 hours
(define-constant APPROVAL_WINDOW_BLOCKS u4320) ;; ~3 days
(define-constant REQUIRED_APPROVALS u3)
(define-constant EMERGENCY_TIMELOCK u2) ;; ~20 minutes
(define-constant ROLLBACK_WINDOW u144) ;; ~24 hours

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var upgrade-counter uint u0)
(define-data-var emergency-mode bool false)

;; ===== Upgrade Proposals =====
(define-map upgrade-proposals uint {
  upgrade-type: uint,
  target-contract: principal,
  new-implementation: principal,
  parameter-name: (string-ascii 64),
  parameter-value: uint,
  description: (string-utf8 512),
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  expires-at: uint,
  executed: bool,
  approvals: uint,
  rollback-data: (optional (buff 1024))
})

;; Approval tracking
(define-map upgrade-approvals {upgrade-id: uint, approver: principal} bool)

;; Approved upgraders (governance-controlled)
(define-map authorized-upgraders principal bool)

;; Contract version registry
(define-map contract-versions principal {
  version: uint,
  implementation: principal,
  deployed-at: uint,
  deprecated: bool
})

;; Upgrade history
(define-map upgrade-history uint {
  upgrade-id: uint,
  executed-at: uint,
  executed-by: principal,
  success: bool,
  rollback-id: (optional uint)
})

;; ===== Authorization =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (check-is-upgrader)
  (ok (asserts! (or (is-eq tx-sender (var-get contract-owner))
                    (default-to false (map-get? authorized-upgraders tx-sender)))
                ERR_UNAUTHORIZED)))

;; ===== Admin Functions =====
(define-public (set-owner (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (add-authorized-upgrader (upgrader principal))
  (begin
    (try! (check-is-owner))
    (map-set authorized-upgraders upgrader true)
    (ok true)))

(define-public (remove-authorized-upgrader (upgrader principal))
  (begin
    (try! (check-is-owner))
    (map-set authorized-upgraders upgrader false)
    (ok true)))

(define-public (set-emergency-mode (enabled bool))
  (begin
    (try! (check-is-owner))
    (var-set emergency-mode enabled)
    (ok true)))

;; ===== Upgrade Proposal Functions =====
(define-public (propose-contract-upgrade
  (target-contract principal)
  (new-implementation principal)
  (description (string-utf8 512)))
  (begin
    (try! (check-is-upgrader))
    
    (let ((upgrade-id (+ (var-get upgrade-counter) u1))
          (timelock (if (var-get emergency-mode) EMERGENCY_TIMELOCK UPGRADE_TIMELOCK_BLOCKS)))
      
      (map-set upgrade-proposals upgrade-id {
        upgrade-type: UPGRADE_CONTRACT,
        target-contract: target-contract,
        new-implementation: new-implementation,
        parameter-name: "",
        parameter-value: u0,
        description: description,
        proposer: tx-sender,
        created-at: block-height,
        execute-after: (+ block-height timelock),
        expires-at: (+ block-height APPROVAL_WINDOW_BLOCKS),
        executed: false,
        approvals: u1,
        rollback-data: none
      })
      
      (map-set upgrade-approvals {upgrade-id: upgrade-id, approver: tx-sender} true)
      (var-set upgrade-counter upgrade-id)
      
      (ok upgrade-id))))

(define-public (propose-parameter-upgrade
  (target-contract principal)
  (parameter-name (string-ascii 64))
  (parameter-value uint)
  (description (string-utf8 512)))
  (begin
    (try! (check-is-upgrader))
    
    (let ((upgrade-id (+ (var-get upgrade-counter) u1))
          (timelock (if (var-get emergency-mode) EMERGENCY_TIMELOCK UPGRADE_TIMELOCK_BLOCKS)))
      
      (map-set upgrade-proposals upgrade-id {
        upgrade-type: UPGRADE_PARAMETER,
        target-contract: target-contract,
        new-implementation: tx-sender, ;; placeholder
        parameter-name: parameter-name,
        parameter-value: parameter-value,
        description: description,
        proposer: tx-sender,
        created-at: block-height,
        execute-after: (+ block-height timelock),
        expires-at: (+ block-height APPROVAL_WINDOW_BLOCKS),
        executed: false,
        approvals: u1,
        rollback-data: none
      })
      
      (map-set upgrade-approvals {upgrade-id: upgrade-id, approver: tx-sender} true)
      (var-set upgrade-counter upgrade-id)
      
      (ok upgrade-id))))

(define-public (approve-upgrade (upgrade-id uint))
  (begin
    (try! (check-is-upgrader))
    
    (let ((proposal (unwrap! (map-get? upgrade-proposals upgrade-id) ERR_INVALID_UPGRADE)))
      
      ;; Validate proposal status
      (asserts! (not (get executed proposal)) ERR_ALREADY_EXECUTED)
      (asserts! (< block-height (get expires-at proposal)) ERR_UPGRADE_EXPIRED)
      (asserts! (not (default-to false (map-get? upgrade-approvals {upgrade-id: upgrade-id, approver: tx-sender})))
                ERR_ALREADY_APPROVED)
      
      ;; Record approval
      (map-set upgrade-approvals {upgrade-id: upgrade-id, approver: tx-sender} true)
      (map-set upgrade-proposals upgrade-id
                (merge proposal {approvals: (+ (get approvals proposal) u1)}))
      
      (ok true))))

(define-public (execute-upgrade (upgrade-id uint))
  (begin
    (try! (check-is-upgrader))
    
    (let ((proposal (unwrap! (map-get? upgrade-proposals upgrade-id) ERR_INVALID_UPGRADE)))
      
      ;; Validate execution conditions
      (asserts! (not (get executed proposal)) ERR_ALREADY_EXECUTED)
      (asserts! (>= (get approvals proposal) REQUIRED_APPROVALS) ERR_INSUFFICIENT_APPROVALS)
      (asserts! (>= block-height (get execute-after proposal)) ERR_UPGRADE_NOT_READY)
      (asserts! (< block-height (get expires-at proposal)) ERR_UPGRADE_EXPIRED)
      
      ;; Execute upgrade based on type
      (let ((execution-result (execute-upgrade-action proposal)))
        
        ;; Mark as executed
        (map-set upgrade-proposals upgrade-id (merge proposal {executed: true}))
        
        ;; Record in history
        (map-set upgrade-history upgrade-id {
          upgrade-id: upgrade-id,
          executed-at: block-height,
          executed-by: tx-sender,
          success: (is-ok execution-result),
          rollback-id: none
        })
        
        ;; Update contract version if successful
        (if (is-ok execution-result)
            (update-contract-version (get target-contract proposal) (get new-implementation proposal))
            false)
        
        execution-result))))

;; ===== Upgrade Execution =====
(define-private (execute-upgrade-action (proposal {
  upgrade-type: uint,
  target-contract: principal,
  new-implementation: principal,
  parameter-name: (string-ascii 64),
  parameter-value: uint,
  description: (string-utf8 512),
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  expires-at: uint,
  executed: bool,
  approvals: uint,
  rollback-data: (optional (buff 1024))}))
  (let ((upgrade-type (get upgrade-type proposal)))
    (if (is-eq upgrade-type UPGRADE_CONTRACT)
        (execute-contract-upgrade proposal)
        (if (is-eq upgrade-type UPGRADE_PARAMETER)
            (execute-parameter-upgrade proposal)
            ERR_INVALID_UPGRADE))))

(define-private (execute-contract-upgrade (proposal {
  upgrade-type: uint,
  target-contract: principal,
  new-implementation: principal,
  parameter-name: (string-ascii 64),
  parameter-value: uint,
  description: (string-utf8 512),
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  expires-at: uint,
  executed: bool,
  approvals: uint,
  rollback-data: (optional (buff 1024))}))
  ;; Implementation would call target contract's upgrade function
  (ok true))

(define-private (execute-parameter-upgrade (proposal {
  upgrade-type: uint,
  target-contract: principal,
  new-implementation: principal,
  parameter-name: (string-ascii 64),
  parameter-value: uint,
  description: (string-utf8 512),
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  expires-at: uint,
  executed: bool,
  approvals: uint,
  rollback-data: (optional (buff 1024))}))
  ;; Implementation would call target contract's parameter update function
  (ok true))

(define-private (update-contract-version (contract principal) (implementation principal))
  (match (map-get? contract-versions contract)
    version-info
    (map-set contract-versions contract {
      version: (+ (get version version-info) u1),
      implementation: implementation,
      deployed-at: block-height,
      deprecated: false
    })
    (map-set contract-versions contract {
      version: u1,
      implementation: implementation,
      deployed-at: block-height,
      deprecated: false
    })))

;; ===== Rollback Functions =====
(define-public (propose-rollback (original-upgrade-id uint))
  (begin
    (try! (check-is-upgrader))
    
    (let ((original (unwrap! (map-get? upgrade-proposals original-upgrade-id) ERR_INVALID_UPGRADE))
          (rollback-id (+ (var-get upgrade-counter) u1)))
      
      (asserts! (get executed original) ERR_INVALID_UPGRADE)
      
      ;; Create rollback proposal with fast-track timelock
      (map-set upgrade-proposals rollback-id {
        upgrade-type: (get upgrade-type original),
        target-contract: (get target-contract original),
        new-implementation: (get target-contract original), ;; Revert to original
        parameter-name: (get parameter-name original),
        parameter-value: u0, ;; Will use rollback-data
        description: u"Rollback",
        proposer: tx-sender,
        created-at: block-height,
        execute-after: (+ block-height EMERGENCY_TIMELOCK),
        expires-at: (+ block-height ROLLBACK_WINDOW),
        executed: false,
        approvals: u1,
        rollback-data: (get rollback-data original)
      })
      
      (map-set upgrade-approvals {upgrade-id: rollback-id, approver: tx-sender} true)
      (var-set upgrade-counter rollback-id)
      (ok rollback-id))))

;; ===== Read-Only Functions =====
(define-read-only (get-owner)
  (var-get contract-owner))

(define-read-only (get-upgrade-proposal (upgrade-id uint))
  (map-get? upgrade-proposals upgrade-id))

(define-read-only (has-approved (upgrade-id uint) (approver principal))
  (default-to false (map-get? upgrade-approvals {upgrade-id: upgrade-id, approver: approver})))

(define-read-only (can-execute-upgrade (upgrade-id uint))
  (match (map-get? upgrade-proposals upgrade-id)
    proposal
    (and (not (get executed proposal))
         (>= (get approvals proposal) REQUIRED_APPROVALS)
         (>= block-height (get execute-after proposal))
         (< block-height (get expires-at proposal)))
    false))

(define-read-only (get-contract-version (contract principal))
  (map-get? contract-versions contract))

(define-read-only (get-upgrade-history (upgrade-id uint))
  (map-get? upgrade-history upgrade-id))

(define-read-only (is-authorized-upgrader (upgrader principal))
  (or (is-eq upgrader (var-get contract-owner))
      (default-to false (map-get? authorized-upgraders upgrader))))

(define-read-only (get-upgrade-stats)
  {
    total-upgrades: (var-get upgrade-counter),
    emergency-mode: (var-get emergency-mode),
    contract-owner: (var-get contract-owner)
  })
