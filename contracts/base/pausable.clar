;; @desc This contract provides a mechanism to pause and unpause contract functionality,
;; typically used for emergency stops or upgrades.
;; Only the contract owner can pause or unpause the contract.

;; --- Traits ---
(use-trait pausable-trait .traits.pausable-trait.pausable-trait)
(use-trait ownable-trait .traits.ownable-trait.ownable-trait)
(use-trait rbac-trait .traits.rbac-trait.rbac-trait)

;; @constants
;; @var ERR_CONTRACT_PAUSED: The contract is currently paused.
(define-constant ERR_CONTRACT_PAUSED (err u1003))
;; @var ERR_CONTRACT_NOT_PAUSED: The contract is not currently paused.
(define-constant ERR_CONTRACT_NOT_PAUSED (err u1004))
;; @var ERR_NOT_OWNER: The caller is not the owner of the contract.
(define-constant ERR_NOT_OWNER (err u1002))
;; @var ERR_ALREADY_PAUSED: The contract is already paused.
(define-constant ERR_ALREADY_PAUSED (err u1003))
;; @var ERR_ALREADY_UNPAUSED: The contract is already unpaused.
(define-constant ERR_ALREADY_UNPAUSED (err u1004))
;; @var ERR_PAUSED: The contract is paused.
(define-constant ERR_PAUSED (err u1003))

;; @data-vars
;; @var is-paused: A boolean indicating if the contract is paused.
(define-data-var is-paused bool false)

;; ===========================================
;; Public functions
;; ===========================================

;; @desc Check if the contract is paused.
;; @returns (response bool uint): An `ok` response with a boolean indicating if the contract is paused.
(define-read-only (is-paused)
  (ok (var-get is-paused))
)

;; @desc Pause the contract (only callable by owner).
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (pause)
  (begin
    (asserts! (is-ok (contract-call? .rbac-trait has-role "contract-owner")) (err ERR_NOT_OWNER))
    ;; Ensure contract is not already paused
    (asserts! (not (var-get is-paused)) ERR_ALREADY_PAUSED)
    
    ;; Update state
    (var-set is-paused true)
    (ok true)
  )
)

;; @desc Unpause the contract (only callable by owner).
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (unpause)
  (begin
    (asserts! (is-ok (contract-call? .rbac-trait has-role "contract-owner")) (err ERR_NOT_OWNER))
    ;; Ensure contract is currently paused
    (asserts! (var-get is-paused) ERR_ALREADY_UNPAUSED)
    
    ;; Update state
    (var-set is-paused false)
    (ok true)
  )
)

;; @desc Helper function for derived contracts to check if the contract is not paused.
;; @returns (response bool uint): An `ok` response with `true` if the contract is not paused, or an error code.
(define-public (check-not-paused)
  (begin
    (asserts! (not (var-get is-paused)) ERR_ALREADY_PAUSED)
    (ok true)
  )
)

;; @data-vars
;; @var paused-event: A dummy variable for event emission.
(define-data-var paused-event (buff 1) 0x00)
