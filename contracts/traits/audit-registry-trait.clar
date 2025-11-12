;; ===========================================
;; AUDIT REGISTRY TRAIT
;; ===========================================
;; Interface for audit registry and voting system
;;
;; This trait provides functions to submit audits, vote on them,
;; and manage the audit approval process.
;;
;; Example usage:
;;   (use-trait audit-registry-trait .audit-registry-trait.audit-registry-trait)
(define-trait audit-registry-trait
  (
    ;; Submit a new audit
    ;; @param contract-address: address of contract being audited
    ;; @param audit-hash: hash of the audit report
    ;; @param report-uri: URI to the full audit report
    ;; @return (response uint uint): audit ID and error code
    (submit-audit (principal (string-ascii 64) (string-utf8 256)) (response uint uint))

    ;; Vote on an audit
    ;; @param audit-id: ID of the audit to vote on
    ;; @param approve: true to approve, false to reject
    ;; @return (response bool uint): success flag and error code
    (vote (uint bool) (response bool uint))

    ;; Finalize audit after voting period
    ;; @param audit-id: ID of the audit to finalize
    ;; @return (response bool uint): success flag and error code
    (finalize-audit (uint) (response bool uint))

    ;; Get audit details
    ;; @param audit-id: ID of the audit
    ;; @return (response (optional (tuple ...)) uint): audit details and error code
    (get-audit-details (uint) (response (optional (tuple
      (contract-address principal)
      (audit-hash (string-ascii 64))
      (report-uri (string-utf8 256))
      (votes-for uint)
      (votes-against uint)
      (finalized bool)
      (approved bool)
    )) uint))

    ;; Get the total number of audits
    ;; @return (response uint uint): total audits and error code
    (get-total-audits () (response uint uint))
  )
)
