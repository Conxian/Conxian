;; ===========================================
;; AUDIT REGISTRY TRAIT
;; ===========================================
;; @desc Interface for audit registry and voting system.
;; This trait provides functions to submit audits, vote on them,
;; and manage the audit approval process.
;;
;; @example
;; (use-trait audit-registry-trait .audit-registry-trait.audit-registry-trait)
(define-trait audit-registry-trait
  (
    ;; @desc Submit a new audit.
    ;; @param contract-address: The address of the contract being audited.
    ;; @param audit-hash: The hash of the audit report.
    ;; @param report-uri: The URI to the full audit report.
    ;; @returns (response uint uint): The ID of the newly created audit, or an error code.
    (submit-audit (principal (string-ascii 64) (string-utf8 256)) (response uint uint))

    ;; @desc Vote on an audit.
    ;; @param audit-id: The ID of the audit to vote on.
    ;; @param approve: true to approve the audit, false to reject it.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (vote (uint bool) (response bool uint))

    ;; @desc Finalize an audit after the voting period has ended.
    ;; @param audit-id: The ID of the audit to finalize.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (finalize-audit (uint) (response bool uint))

    ;; @desc Get the details of a specific audit.
    ;; @param audit-id: The ID of the audit to retrieve.
    ;; @returns (response (optional (tuple ...)) uint): A tuple containing the audit details, or none if the audit is not found.
    (get-audit-details (uint) (response (optional (tuple
      (contract-address principal)
      (audit-hash (string-ascii 64))
      (report-uri (string-utf8 256))
      (votes-for uint)
      (votes-against uint)
      (finalized bool)
      (approved bool)
    )) uint))

    ;; @desc Get the total number of audits submitted to the registry.
    ;; @returns (response uint uint): The total number of audits, or an error code.
    (get-total-audits () (response uint uint))
  )
)
