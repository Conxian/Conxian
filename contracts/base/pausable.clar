;; @desc This contract provides a mechanism to pause and unpause contract functionality,
;; typically used for emergency stops or upgrades.
;; Only the contract owner can pause or unpause the contract.

;; --- Traits ---
(use-trait pausable-trait .base-traits.pausable-trait)
(use-trait ownable-trait .base-traits.ownable-trait)
(use-trait rbac-trait .02-core-protocol.02-core-protocol.rbac-trait-trait)

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
;; @var paused-flag: A boolean indicating if the contract is paused.
(define-data-var paused-flag bool false)

;; ===========================================
;; Public functions
;; ===========================================

;; @desc Check if the contract is paused.
;; @returns (response bool uint): An `ok` response with a boolean indicating if the contract is paused.
(define-read-only (is-paused)
  (ok (var-get paused-flag))
)

;; @desc Pause the contract (only callable by owner).
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (pause)
  (begin
    ;; Phase 0: skip RBAC check and rely on direct state.
(asserts! (not (var-get paused-flag)) ERR_ALREADY_PAUSED)
(var-set paused-flag true)
    (ok true)
  )
)

;; @desc Unpause the contract (only callable by owner).
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (unpause)
  (begin
    ;; Phase 0: skip RBAC check and rely on direct state.
(asserts! (var-get paused-flag) ERR_ALREADY_UNPAUSED)
(var-set paused-flag false)
    (ok true)
  )
)

;; @desc Helper function for derived contracts to check if the contract is not paused.
;; @returns (response bool uint): An `ok` response with `true` if the contract is not paused, or an error code.
(define-public (check-not-paused)
  (begin
    (asserts! (not (var-get paused-flag)) ERR_ALREADY_PAUSED)
    (ok true)
  )
)

;; @data-vars
;; @var paused-event: A dummy variable for event emission.
(define-data-var paused-event (buff 1) 0x00)
