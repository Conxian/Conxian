;; travel-rule-service.clar
;; Travel Rule compliance service for regulated transfers
;; Implements FATF Travel Rule data collection and sharing

(define-constant ERR_UNAUTHORIZED (err u9500))
(define-constant ERR_INVALID_AMOUNT (err u9501))
(define-constant ERR_TRANSFER_EXISTS (err u9502))
(define-constant ERR_COMPLIANCE_REQUIRED (err u9503))
(define-constant ERR_THRESHOLD_NOT_MET (err u9504))

;; --- Constants ---
(define-constant TRAVEL_RULE_THRESHOLD u1000000000)  ;; 1000 USD equivalent in smallest units
(define-constant VASP_LIST_MAX u100)
(define-constant DATA_RETENTION_BLOCKS u15768000)  ;; 1 year at 5s blocks

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var compliance-admin principal tx-sender)
(define-data-var vasp-registry (list 100 principal) (list))

;; --- Travel Rule Data ---
(define-map travel-rule-transfers {
  transfer-id: (string 64),
} {
  from-vasp principal,
  to-vasp principal,
  from-address principal,
  to-address principal,
  amount uint,
  token principal,
  timestamp uint,
  originator-info (string 512),
  beneficiary-info (string 512),
  status (string 32),  ;; "pending", "sent", "received", "completed"
})

(define-map vasp-compliance-info {
  vasp: principal,
} {
  compliance-email (string 128),
  compliance-phone (string 32),
  jurisdiction (string 8),
  registration-number (string 64),
  contact-person (string 128),
})

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-admin-or-owner)
  (or (is-eq tx-sender (var-get contract-owner))
      (is-eq tx-sender (var-get compliance-admin)))
)

(define-private (is-registered-vasp)
  (let ((vasp-list (var-get vasp-registry)))
    (is-some (filter is-eq vasp-list tx-sender))
  )
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-compliance-admin (admin principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set compliance-admin admin)
    (ok true)
  )
)

;; --- VASP Registry Management ---

;; @notice Register a VASP in the compliance registry
(define-public (register-vasp
    (vasp principal)
    (compliance-email (string 128))
    (compliance-phone (string 32))
    (jurisdiction (string 8))
    (registration-number (string 64))
    (contact-person (string 128))
  )
  (begin
    (asserts! (is-admin-or-owner) ERR_UNAUTHORIZED)
    (asserts! (< (len (var-get vasp-registry)) VASP_LIST_MAX) ERR_UNAUTHORIZED)
    
    ;; Add to VASP registry
    (var-set vasp-registry (append (var-get vasp-registry) vasp))
    
    ;; Store compliance info
    (map-set vasp-compliance-info vasp {
      compliance-email: compliance-email,
      compliance-phone: compliance-phone,
      jurisdiction: jurisdiction,
      registration-number: registration-number,
      contact-person: contact-person,
    })
    
    (print {
      event: "vasp-registered",
      vasp: vasp,
      jurisdiction: jurisdiction,
      registration-number: registration-number,
    })
    (ok true)
  )
)

;; @notice Remove a VASP from registry
(define-public (remove-vasp (vasp principal))
  (begin
    (asserts! (is-admin-or-owner) ERR_UNAUTHORIZED)
    (var-set vasp-registry (filter not-eq (var-get vasp-registry) vasp))
    (map-delete vasp-compliance-info vasp)
    (print {
      event: "vasp-removed",
      vasp: vasp,
      removed-at: block-height,
    })
    (ok true)
  )
)

;; --- Travel Rule Transfer Functions ---

;; @notice Initiate a Travel Rule transfer
(define-public (initiate-travel-rule-transfer
    (transfer-id (string 64))
    (to-vasp principal)
    (to-address principal)
    (amount uint)
    (token principal)
    (originator-info (string 512))
    (beneficiary-info (string 512))
  )
  (begin
    (asserts! (is-registered-vasp) ERR_UNAUTHORIZED)
    (asserts! (>= amount TRAVEL_RULE_THRESHOLD) ERR_THRESHOLD_NOT_MET)
    (asserts! (none? (map-get? travel-rule-transfers {transfer-id: transfer-id})) ERR_TRANSFER_EXISTS)
    
    ;; Store travel rule data
    (map-set travel-rule-transfers {transfer-id: transfer-id} {
      from-vasp: tx-sender,
      to-vasp: to-vasp,
      from-address: tx-sender,
      to-address: to-address,
      amount: amount,
      token: token,
      timestamp: block-height,
      originator-info: originator-info,
      beneficiary-info: beneficiary-info,
      status: "pending",
    })
    
    (print {
      event: "travel-rule-initiated",
      transfer-id: transfer-id,
      from-vasp: tx-sender,
      to-vasp: to-vasp,
      amount: amount,
      token: token,
    })
    (ok true)
  )
)

;; @notice Confirm receipt of Travel Rule data by receiving VASP
(define-public (confirm-travel-rule-receipt (transfer-id (string 64)))
  (let ((transfer (unwrap! (map-get? travel-rule-transfers {transfer-id: transfer-id}) ERR_TRANSFER_EXISTS)))
    (asserts! (is-registered-vasp) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get to-vasp transfer)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status transfer) "sent") ERR_COMPLIANCE_REQUIRED)
    
    ;; Update status to received
    (map-set travel-rule-transfers {transfer-id: transfer-id}
      (merge transfer {status: "received"})
    )
    
    (print {
      event: "travel-rule-received",
      transfer-id: transfer-id,
      confirmed-by: tx-sender,
      confirmed-at: block-height,
    })
    (ok true)
  )
)

;; @notice Send Travel Rule data to receiving VASP
(define-public (send-travel-rule-data (transfer-id (string 64)))
  (let ((transfer (unwrap! (map-get? travel-rule-transfers {transfer-id: transfer-id}) ERR_TRANSFER_EXISTS)))
    (asserts! (is-registered-vasp) ERR_UNAUTHORIZED)
    (asserts! (is-eq tx-sender (get from-vasp transfer)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status transfer) "pending") ERR_COMPLIANCE_REQUIRED)
    
    ;; Update status to sent
    (map-set travel-rule-transfers {transfer-id: transfer-id}
      (merge transfer {status: "sent"})
    )
    
    (print {
      event: "travel-rule-sent",
      transfer-id: transfer-id,
      sent-from: tx-sender,
      sent-to: (get to-vasp transfer),
      sent-at: block-height,
    })
    (ok true)
  )
)

;; @notice Mark transfer as completed after on-chain execution
(define-public (complete-travel-rule-transfer (transfer-id (string 64)))
  (let ((transfer (unwrap! (map-get? travel-rule-transfers {transfer-id: transfer-id}) ERR_TRANSFER_EXISTS)))
    (asserts! (is-registered-vasp) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq tx-sender (get from-vasp transfer))
                  (is-eq tx-sender (get to-vasp transfer))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status transfer) "received") ERR_COMPLIANCE_REQUIRED)
    
    ;; Update status to completed
    (map-set travel-rule-transfers {transfer-id: transfer-id}
      (merge transfer {status: "completed"})
    )
    
    (print {
      event: "travel-rule-completed",
      transfer-id: transfer-id,
      completed-by: tx-sender,
      completed_at: block-height,
    })
    (ok true)
  )
)

;; --- Read-Only Views ---

(define-read-only (get-travel-rule-transfer (transfer-id (string 64)))
  (map-get? travel-rule-transfers {transfer-id: transfer-id})
)

(define-read-only (get-vasp-info (vasp principal))
  (map-get? vasp-compliance-info vasp)
)

(define-read-only (is-registered-vasp-view (vasp principal))
  (let ((vasp-list (var-get vasp-registry)))
    (ok (is-some (filter is-eq vasp-list vasp)))
  )
)

(define-read-only (get-vasp-registry)
  (ok (var-get vasp-registry))
)

(define-read-only (get-transfers-by-vasp (vasp principal) (status (string 32)))
  ;; Simplified for demo - would need proper filtering in production
  (ok {
    transfers: (map-get? travel-rule-transfers {transfer-id: "demo"}),
    total-count: u0,
  })
)

;; --- Compliance Reporting ---

;; @notice Generate compliance report for a time period
(define-read-only (generate-compliance-report
    (start-block uint)
    (end-block uint)
  )
  (ok {
    report-id: (as-max-len? (concat "report-" (tx-sender)) u64),
    period: {start: start-block, end: end-block},
    total-transfers: u0,  // Would calculate from stored data
    high-value-transfers: u0,
    vasp-count: (len (var-get vasp-registry)),
    generated-at: block-height,
  })
)
