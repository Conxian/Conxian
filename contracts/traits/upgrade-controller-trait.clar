;; ===========================================
;; UPGRADE CONTROLLER TRAIT
;; ===========================================
;; @desc Interface for managing contract upgrades.
;; This trait defines functions for initiating and finalizing contract upgrades.
;;
;; @example
;; (use-trait upgrade-ctrl .upgrade-controller-trait)
(define-trait upgrade-controller-trait
  (
    ;; @desc Initiate a contract upgrade.
    ;; @param new-contract: The principal of the new contract to upgrade to.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (initiate-upgrade (principal) (response bool uint))

    ;; @desc Finalize a contract upgrade.
    ;; @param new-contract: The principal of the new contract that was upgraded to.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (finalize-upgrade (principal) (response bool uint))
  )
)
