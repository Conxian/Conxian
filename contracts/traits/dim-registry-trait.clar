;; ===========================================
;; DIM REGISTRY TRAIT
;; ===========================================
;; Interface for managing oracle registrations
;;
;; This trait provides functions to register and manage oracle contracts.
;;
;; Example usage:
;;   (use-trait registry .dim-registry-trait.dim-registry-trait)
(define-trait dim-registry-trait
  (
    ;; @desc Registers an oracle contract.
    ;; @param oracle-contract The principal of the oracle contract to register.
    ;; @returns (response bool uint) True if successful, or an error.
    (register-oracle (oracle-contract principal)) (response bool uint))

    ;; @desc Unregisters an oracle contract.
    ;; @param oracle-contract The principal of the oracle contract to unregister.
    ;; @returns (response bool uint) True if successful, or an error.
    (unregister-oracle (oracle-contract principal)) (response bool uint))

    ;; @desc Checks if an oracle contract is registered.
    ;; @param oracle-contract The principal of the oracle contract to check.
    ;; @returns (response bool uint) True if registered, or an error.
    (is-oracle-registered (oracle-contract principal)) (response bool uint))

    ;; @desc Gets the list of registered oracle contracts.
    ;; @returns (response (list principal) uint) A list of registered oracle principals, or an error.
    (get-registered-oracles) (response (list principal) uint))
  )
)
