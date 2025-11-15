;; ===========================================
;; FACTORY TRAIT
;; ===========================================
;; @desc Interface for creating and managing contract instances.
;; This trait provides functions to deploy new contract instances
;; and retrieve information about existing ones.
;;
;; @example
;; (use-trait factory .factory-trait.factory-trait)
(define-trait factory-trait
  (
    ;; @desc Deploy a new contract instance.
    ;; @param contract-name: The name of the contract to deploy.
    ;; @param deployer: The principal of the deployer.
    ;; @returns (response principal uint): The principal of the newly deployed contract, or an error code.
    (deploy-contract ((string-ascii 32) principal) (response principal uint))

    ;; @desc Get a contract instance by its name.
    ;; @param contract-name: The name of the contract.
    ;; @returns (response (optional principal) uint): The principal of the contract, or none if it's not found.
    (get-contract-by-name ((string-ascii 32)) (response (optional principal) uint))

    ;; @desc Get all deployed contract instances.
    ;; @returns (response (list 20 principal) uint): A list of the principals of all deployed contracts, or an error code.
    (get-all-contracts () (response (list 20 principal) uint))
  )
)
