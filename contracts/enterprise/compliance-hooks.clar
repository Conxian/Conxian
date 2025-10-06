;; compliance-hooks.clar
;; Implementation of compliance hooks for the enterprise API

(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)

(impl-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)

(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_ACCOUNT_NOT_VERIFIED (err u403))
(define-constant ERR_INVALID_KYC_TIER (err u404))

(define-data-var contract-owner principal tx-sender)
(define-map verified-accounts principal { kyc-tier: uint, last-updated: uint })
(define-map kyc-audit-trail uint { account: principal, action: uint, old-tier: uint, new-tier: uint, timestamp: uint })
(define-data-var audit-event-counter uint u0)

;; @desc Sets the KYC tier for a given account.
;; @param account (principal) The principal of the account to set the KYC tier for.
;; @param kyc-tier (uint) The new KYC tier for the account (e.g., u1 for basic, u2 for intermediate, u3 for advanced).
;; @return (response bool) An (ok true) response if the KYC tier is successfully set, or an error if unauthorized or the tier is invalid.
(define-public (set-kyc-tier (account principal) (kyc-tier uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= kyc-tier u3) ERR_INVALID_KYC_TIER) ;; Assuming max tier is u3

    (let (
      (old-kyc-tier (default-to u0 (get kyc-tier (map-get? verified-accounts account))))
      (event-id (+ u1 (var-get audit-event-counter)))
    )
      (map-set verified-accounts account { kyc-tier: kyc-tier, last-updated: block-height })
      (map-set kyc-audit-trail event-id {
        account: account,
        action: u3, ;; u3 for tier update
        old-tier: old-kyc-tier,
        new-tier: kyc-tier,
        timestamp: block-height
      })
      (var-set audit-event-counter event-id)
      (ok true)
    )
  )
)

;; @desc Verifies an account by setting its KYC tier to a basic level (u1).
;; @param account (principal) The principal of the account to verify.
;; @return (response bool) An (ok true) response if the account is successfully verified, or an error if unauthorized.
(define-public (verify-account (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let (
      (old-kyc-tier (default-to u0 (get kyc-tier (map-get? verified-accounts account))))
      (event-id (+ u1 (var-get audit-event-counter)))
    )
      (map-set verified-accounts account { kyc-tier: u1, last-updated: block-height }) ;; Default to basic tier u1 on verification
      (map-set kyc-audit-trail event-id {
        account: account,
        action: u1, ;; u1 for verification
        old-tier: old-kyc-tier,
        new-tier: u1,
        timestamp: block-height
      })
      (var-set audit-event-counter event-id)
      (ok true)
    )
  )
)

(define-public (unverify-account (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let (
      (old-kyc-tier (default-to u0 (get kyc-tier (map-get? verified-accounts account))))
      (event-id (+ u1 (var-get audit-event-counter)))
    )
      (map-delete verified-accounts account)
      (map-set kyc-audit-trail event-id {
        account: account,
        action: u2, ;; u2 for unverification
        old-tier: old-kyc-tier,
        new-tier: u0,
        timestamp: block-height
      })
      (var-set audit-event-counter event-id)
      (ok true)
    )
  )
)

;; @desc Checks if an account is currently verified.
;; @param account (principal) The principal of the account to check.
;; @return (bool) True if the account is verified, false otherwise.
(define-read-only (is-verified (account principal))
  (is-some (map-get? verified-accounts account))
)

;; @desc Retrieves the KYC tier of an account.
;; @param account (principal) The principal of the account to retrieve the KYC tier for.
;; @return (uint) The KYC tier of the account (u0 if not verified or no tier set).
(define-read-only (get-kyc-tier (account principal))
  (default-to u0 (get kyc-tier (map-get? verified-accounts account)))
)

;; @desc Retrieves a specific KYC audit event by its ID.
;; @param event-id (uint) The ID of the audit event to retrieve.
;; @return (response {account: principal, action: uint, old-tier: uint, new-tier: uint, timestamp: uint}) An (ok) response containing the audit event details, or an error if the event does not exist.
(define-read-only (get-audit-event (event-id uint))
  (map-get? kyc-audit-trail event-id)
)

;; @desc Retrieves the total number of KYC audit events recorded.
;; @return (response uint) An (ok) response containing the total count of audit events.
(define-read-only (get-audit-event-count)
  (ok (var-get audit-event-counter))
)
