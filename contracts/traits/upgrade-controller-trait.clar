;; ===========================================
;; UPGRADE CONTROLLER TRAIT
;; ===========================================
;; Interface for managing contract upgrades.
;;
;; This trait defines functions for initiating and finalizing contract upgrades.
;;
;; Example usage:
;;   (use-trait upgrade-ctrl .upgrade-controller-trait)
(define-trait upgrade-controller-trait
  (
    ;; Initiate a contract upgrade.
    ;; @param new-contract: principal of the new contract to upgrade to
    ;; @return (response bool uint): success flag and error code
    (initiate-upgrade (principal) (response bool uint))

    ;; Finalize a contract upgrade.
    ;; @param new-contract: principal of the new contract that was upgraded to
    ;; @return (response bool uint): success flag and error code
    (finalize-upgrade (principal) (response bool uint))
  )
)
