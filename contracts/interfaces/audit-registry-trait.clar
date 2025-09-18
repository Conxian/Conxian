;; audit-registry-trait.clar
;; Defines the interface for the audit registry system

(define-trait audit-registry-trait
  ;; Submit a new audit
  (submit-audit 
    (contract-address principal) 
    (audit-hash (string-ascii 64))
    (report-uri (string-utf8 256))
    (response uint uint)
  )
  
  ;; Vote on an audit
  (vote (audit-id uint) (approve bool) (response bool uint))
  
  ;; Finalize audit after voting period
  (finalize-audit (audit-id uint) (response bool uint))
  
  ;; Get audit details
  (get-audit (audit-id uint) 
    (response {
      contract-address: principal,
      audit-hash: (string-ascii 64),
      auditor: principal,
      report-uri: (string-utf8 256),
      timestamp: uint,
      status: { 
        status: (string-ascii 20), 
        reason: (optional (string-utf8 500)) 
      },
      votes: {
        for: uint,
        against: uint,
        voters: (list 100 principal)
      },
      voting-ends: uint
    } uint)
  )
  
  ;; Get audit status
  (get-audit-status (audit-id uint) 
    (response {
      status: (string-ascii 20), 
      reason: (optional (string-utf8 500)) 
    } uint)
  )
  
  ;; Get audit votes
  (get-audit-votes (audit-id uint) 
    (response {
      for: uint,
      against: uint,
      voters: (list 100 principal)
    } uint)
  )
  
  ;; Admin: Set voting period
  (set-voting-period (blocks uint) (response bool uint))
  
  ;; Admin: Emergency pause an audit
  (emergency-pause-audit (audit-id uint) (reason (string-utf8 500)) (response bool uint))
)
