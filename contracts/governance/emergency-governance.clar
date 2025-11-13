;; emergency-governance.clar
;; Fast-track emergency governance for critical protocol actions
;; Multi-sig protected emergency pause, parameter updates, and recovery

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u6001))
(define-constant ERR_INVALID_THRESHOLD (err u6002))
(define-constant ERR_ALREADY_APPROVED (err u6003))
(define-constant ERR_PROPOSAL_EXPIRED (err u6004))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u6005))
(define-constant ERR_ALREADY_EXECUTED (err u6006))
(define-constant ERR_INVALID_ACTION_TYPE (err u6007))
(define-constant ERR_PROTOCOL_PAUSED (err u6008))

;; Emergency action types
(define-constant ACTION_PAUSE_PROTOCOL u1)
(define-constant ACTION_UNPAUSE_PROTOCOL u2)
(define-constant ACTION_UPDATE_PARAMETER u3)
(define-constant ACTION_EMERGENCY_WITHDRAWAL u4)
(define-constant ACTION_BLACKLIST_ADDRESS u5)
(define-constant ACTION_UPDATE_ORACLE u6)

;; Timelock settings
(define-constant EMERGENCY_TIMELOCK_BLOCKS u2) ;; ~2 minutes for critical actions
(define-constant STANDARD_TIMELOCK_BLOCKS u144) ;; ~2.4 hours for standard actions
(define-constant PROPOSAL_EXPIRY_BLOCKS u1008) ;; ~16.8 hours

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var approval-threshold uint u3) ;; Require 3 of 5 signers
(define-data-var total-signers uint u0)
(define-data-var protocol-paused bool false)
(define-data-var proposal-counter uint u0)

;; ===== Data Maps =====
;; Emergency signers (multi-sig)
(define-map emergency-signers 
  principal 
  {
    is-active: bool,
    approvals-count: uint,
    last-approval-block: uint
  }
)

;; Emergency proposals
(define-map emergency-proposals 
  uint 
  {
    action-type: uint,
    target: principal,
    parameter: (string-ascii 64),
    value: uint,
    proposer: principal,
    created-at: uint,
    execute-after: uint,
    executed: bool,
    approvals: uint,
    description: (string-utf8 256)
  }
)

;; Approval tracking
(define-map proposal-approvals 
  {proposal-id: uint, signer: principal} 
  bool
)

;; Emergency action history
(define-map action-history 
  uint 
  {
    action-type: uint,
    executed-at: uint,
    executed-by: principal,
    reverted: bool
  }
)

;; ===== Authorization =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED))
)

(define-private (check-is-signer)
  (ok (asserts! (is-signer tx-sender) ERR_UNAUTHORIZED))
)

(define-private (is-signer (address principal))
  (match (map-get? emergency-signers address)
    signer-data (get is-active signer-data)
    false
  )
)

(define-private (is-emergency-action (action-type uint))
  (or (is-eq action-type ACTION_PAUSE_PROTOCOL)
      (is-eq action-type ACTION_EMERGENCY_WITHDRAWAL))
)

;; ===== Admin Functions =====
(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (add-emergency-signer (signer principal))
  (begin
    (try! (check-is-owner))
    (map-set emergency-signers signer {
      is-active: true,
      approvals-count: u0,
      last-approval-block: u0
    })
    (var-set total-signers (+ (var-get total-signers) u1))
    (ok true)
  )
)

(define-public (remove-emergency-signer (signer principal))
  (begin
    (try! (check-is-owner))
    (match (map-get? emergency-signers signer)
      signer-data
      (begin
        (map-set emergency-signers signer (merge signer-data {is-active: false}))
        (var-set total-signers (- (var-get total-signers) u1))
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
  )
)

(define-public (set-approval-threshold (threshold uint))
  (begin
    (try! (check-is-owner))
    (asserts! (and (> threshold u0) (<= threshold (var-get total-signers))) ERR_INVALID_THRESHOLD)
    (var-set approval-threshold threshold)
    (ok true)
  )
)

;; ===== Emergency Proposal Functions =====

(define-public (create-emergency-proposal 
  (action-type uint)
  (target principal)
  (parameter (string-ascii 64))
  (value uint)
  (description (string-utf8 256))
)
  (begin
    (try! (check-is-signer))
    (asserts! (<= action-type ACTION_UPDATE_ORACLE) ERR_INVALID_ACTION_TYPE)
    
    (let (
      (proposal-id (+ (var-get proposal-counter) u1))
      (timelock-blocks (if (is-emergency-action action-type)
                           EMERGENCY_TIMELOCK_BLOCKS
                           STANDARD_TIMELOCK_BLOCKS))
    )
      (map-set emergency-proposals proposal-id {
        action-type: action-type,
        target: target,
        parameter: parameter,
        value: value,
        proposer: tx-sender,
        created-at: block-height,
        execute-after: (+ block-height timelock-blocks),
        executed: false,
        approvals: u1,
        description: description
      })
      
      (map-set proposal-approvals {proposal-id: proposal-id, signer: tx-sender} true)
      (var-set proposal-counter proposal-id)
      (ok proposal-id)
    )
  )
)

(define-public (approve-proposal (proposal-id uint))
  (begin
    (try! (check-is-signer))
    
    (let (
      (proposal (unwrap! (map-get? emergency-proposals proposal-id) ERR_UNAUTHORIZED))
    )
      (asserts! (< block-height (+ (get created-at proposal) PROPOSAL_EXPIRY_BLOCKS)) ERR_PROPOSAL_EXPIRED)
      (asserts! (not (default-to false (map-get? proposal-approvals {proposal-id: proposal-id, signer: tx-sender})))
                ERR_ALREADY_APPROVED)
      
      (map-set proposal-approvals {proposal-id: proposal-id, signer: tx-sender} true)
      (map-set emergency-proposals proposal-id
        (merge proposal {approvals: (+ (get approvals proposal) u1)}))
      
      (match (map-get? emergency-signers tx-sender)
        signer-data
        (map-set emergency-signers tx-sender (merge signer-data {
          approvals-count: (+ (get approvals-count signer-data) u1),
          last-approval-block: block-height
        }))
        false
      )
      
      (ok true)
    )
  )
)

(define-public (execute-emergency-proposal (proposal-id uint))
  (begin
    (try! (check-is-signer))
    
    (let (
      (proposal (unwrap! (map-get? emergency-proposals proposal-id) ERR_UNAUTHORIZED))
    )
      (asserts! (not (get executed proposal)) ERR_ALREADY_EXECUTED)
      (asserts! (>= (get approvals proposal) (var-get approval-threshold)) ERR_INSUFFICIENT_APPROVALS)
      (asserts! (>= block-height (get execute-after proposal)) ERR_PROPOSAL_EXPIRED)
      (asserts! (< block-height (+ (get created-at proposal) PROPOSAL_EXPIRY_BLOCKS)) ERR_PROPOSAL_EXPIRED)
      
      (let (
        (execution-result (try! (execute-emergency-action proposal)))
      )
        (map-set emergency-proposals proposal-id (merge proposal {executed: true}))
        (map-set action-history proposal-id {
          action-type: (get action-type proposal),
          executed-at: block-height,
          executed-by: tx-sender,
          reverted: false
        })
        
        (ok execution-result)
      )
    )
  )
)

;; ===== Emergency Action Execution =====
(define-private (execute-emergency-action (proposal {
  action-type: uint,
  target: principal,
  parameter: (string-ascii 64),
  value: uint,
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  executed: bool,
  approvals: uint,
  description: (string-utf8 256)
}))
  (let ((action-type (get action-type proposal)))
    (if (is-eq action-type ACTION_PAUSE_PROTOCOL)
      (pause-protocol)
      (if (is-eq action-type ACTION_UNPAUSE_PROTOCOL)
        (unpause-protocol)
        (if (is-eq action-type ACTION_UPDATE_PARAMETER)
          (update-parameter proposal)
          (if (is-eq action-type ACTION_EMERGENCY_WITHDRAWAL)
            (emergency-withdraw proposal)
            (if (is-eq action-type ACTION_BLACKLIST_ADDRESS)
              (blacklist-address proposal)
              (if (is-eq action-type ACTION_UPDATE_ORACLE)
                (update-oracle proposal)
                ERR_INVALID_ACTION_TYPE
              )
            )
          )
        )
      )
    )
  )
)

(define-private (pause-protocol)
  (begin
    (var-set protocol-paused true)
    (ok true)
  )
)

(define-private (unpause-protocol)
  (begin
    (var-set protocol-paused false)
    (ok true)
  )
)

(define-private (update-parameter (proposal {
  action-type: uint,
  target: principal,
  parameter: (string-ascii 64),
  value: uint,
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  executed: bool,
  approvals: uint,
  description: (string-utf8 256)
}))
  ;; In production, call target contract to update parameter
  (ok true)
)

(define-private (emergency-withdraw (proposal {
  action-type: uint,
  target: principal,
  parameter: (string-ascii 64),
  value: uint,
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  executed: bool,
  approvals: uint,
  description: (string-utf8 256)
}))
  ;; In production, execute emergency withdrawal
  (ok true)
)

(define-private (blacklist-address (proposal {
  action-type: uint,
  target: principal,
  parameter: (string-ascii 64),
  value: uint,
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  executed: bool,
  approvals: uint,
  description: (string-utf8 256)
}))
  ;; In production, add address to blacklist
  (ok true)
)

(define-private (update-oracle (proposal {
  action-type: uint,
  target: principal,
  parameter: (string-ascii 64),
  value: uint,
  proposer: principal,
  created-at: uint,
  execute-after: uint,
  executed: bool,
  approvals: uint,
  description: (string-utf8 256)
}))
  ;; In production, update oracle price
  (ok true)
)

;; ===== Read-Only Functions =====
(define-read-only (get-proposal (proposal-id uint))
  (map-get? emergency-proposals proposal-id)
)

(define-read-only (has-approved (proposal-id uint) (signer principal))
  (default-to false (map-get? proposal-approvals {proposal-id: proposal-id, signer: signer}))
)

(define-read-only (is-protocol-paused)
  (var-get protocol-paused)
)

(define-read-only (get-emergency-config)
  {
    approval-threshold: (var-get approval-threshold),
    total-signers: (var-get total-signers),
    protocol-paused: (var-get protocol-paused),
    total-proposals: (var-get proposal-counter)
  }
)

(define-read-only (get-signer-info (signer principal))
  (map-get? emergency-signers signer)
)

(define-read-only (can-execute-proposal (proposal-id uint))
  (match (map-get? emergency-proposals proposal-id)
    proposal
    (and 
      (not (get executed proposal))
      (>= (get approvals proposal) (var-get approval-threshold))
      (>= block-height (get execute-after proposal))
      (< block-height (+ (get created-at proposal) PROPOSAL_EXPIRY_BLOCKS))
    )
    false
  )
)

(define-read-only (get-action-history (proposal-id uint))
  (map-get? action-history proposal-id)
)
