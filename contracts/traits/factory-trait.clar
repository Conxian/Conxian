;; ===========================================
;; FACTORY TRAIT
;; ===========================================
;; Interface for creating and managing contract instances
;;
;; This trait provides functions to deploy new contract instances
;; and retrieve information about existing ones.
;;
;; Example usage:
;;   (use-trait factory .factory-trait.factory-trait)
(define-trait factory-trait
  (
    ;; Deploy a new contract instance
    ;; @param contract-name: name of the contract to deploy
    ;; @param deployer: principal of the deployer
    ;; @return (response principal uint): principal of the new contract and error code
    (deploy-contract ((string-ascii 32) principal) (response principal uint))

    ;; Get contract instance by name
    ;; @param contract-name: name of the contract
    ;; @return (response (optional principal) uint): principal of the contract or none, and error code
    (get-contract-by-name ((string-ascii 32)) (response (optional principal) uint))

    ;; Get all deployed contract instances
    ;; @return (response (list 20 principal) uint): list of contract principals and error code
    (get-all-contracts () (response (list 20 principal) uint))
  )
)
