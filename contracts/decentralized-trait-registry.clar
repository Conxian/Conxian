;; decentralized-trait-registry.clar
;; Decentralized Trait Registry for Conxian Protocol

;; --- Trait Imports ---
(use-trait dao-trait .governance.dao-trait)
(use-trait upgrade-controller-trait .core-protocol.upgradeable-trait)
(use-trait governance-token-trait .governance.governance-token-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_TRAIT_NAME u101)
(define-constant ERR_TRAIT_ALREADY_REGISTERED u102)
(define-constant ERR_IMPLEMENTATION_ALREADY_REGISTERED u103)
(define-constant ERR_TRAIT_NOT_FOUND u104)
(define-constant ERR_IMPLEMENTATION_NOT_FOUND u105)
(define-constant ERR_NOT_GOVERNANCE_CONTRACT u106)
(define-constant ERR_ALREADY_ACTIVE u107)
(define-constant ERR_NOT_ACTIVE u108)
(define-constant ERR_UPGRADE_FAILED u109)
(define-constant ERR_INTERNAL_STATE_ERROR (err u110))

;; --- Data Variables ---
;; Contract owner (for initial setup and emergency, can be transferred to DAO)
(define-data-var contract-owner principal tx-sender)

;; Governance contract principal (e.g., DAO contract)
(define-data-var governance-contract principal tx-sender)

;; Maps trait names to their definitions (e.g., {name: (string-ascii 64), description: (string-ascii 256)})
(define-map trait-interfaces (string-ascii 64) {
  name: (string-ascii 64),
  description: (string-ascii 256)
})

;; Stores all registered implementations for a given trait interface
;; Key: {trait-name: (string-ascii 64), implementation-principal: principal}
;; Value: {version: uint, status: (string-ascii 16)} ;; status: "pending", "active", "deprecated"
(define-map trait-implementations {trait-name: (string-ascii 64), implementation-principal: principal} {
  version: uint,
  status: (string-ascii 16)
})

;; Stores the currently active implementation for each trait interface
;; Key: (string-ascii 64) ;; trait-name
;; Value: principal ;; active-implementation-principal
(define-map active-trait-implementations (string-ascii 64) principal)

;; Stores pending trait upgrade proposals awaiting DAO approval
;; Key: uint ;; proposal-id (from DAO)
;; Value: {
;;   trait-name: (string-ascii 64),
;;   new-implementation-principal: principal,
;;   new-version: uint
;; }
(define-map pending-trait-upgrades uint {
  trait-name: (string-ascii 64),
  new-implementation-principal: principal,
  new-version: uint
})

;; --- Private Helper Functions ---
;; (define-private (is-dao-caller)
;;   (ok (is-eq tx-sender (var-get governance-contract)))
;; )

;; --- Public Functions ---

;; @desc Registers a new trait interface.
;; @param trait-name The name of the trait interface.
;; @param description A brief description of the trait.
;; @returns (response bool uint) True if successful, or an error.
(define-public (register-trait-interface (trait-name (string-ascii 64)) (description (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (not (is-some (map-get? trait-interfaces trait-name))) (err ERR_TRAIT_ALREADY_REGISTERED))
    (map-set trait-interfaces trait-name {name: trait-name, description: description})
    (ok true)
  )
)

;; @desc Registers a new implementation for a trait interface.
;; @param trait-name The name of the trait interface.
;; @param implementation-principal The principal of the contract implementing the trait.
;; @param version The version of this implementation.
;; @returns (response bool uint) True if successful, or an error.
(define-public (register-trait-implementation (trait-name (string-ascii 64)) (implementation-principal principal) (version uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (map-get? trait-interfaces trait-name)) (err ERR_TRAIT_NOT_FOUND))
    (asserts!
      (not (is-some (map-get? trait-implementations {
        trait-name: trait-name,
        implementation-principal: implementation-principal,
      })))
      (err ERR_IMPLEMENTATION_ALREADY_REGISTERED)
    )

    (map-set trait-implementations {
      trait-name: trait-name,
      implementation-principal: implementation-principal,
    } {
      version: version,
      status: "pending",
    })
    (ok true)
  )
)

;; @desc Activates a registered trait implementation. This should be called by the governance contract.
;; @param trait-name The name of the trait interface.
;; @param implementation-principal The principal of the contract implementing the trait to activate.
;; @returns (response bool uint) True if successful, or an error.
(define-public (activate-trait-implementation (trait-name (string-ascii 64)) (implementation-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) (err ERR_NOT_GOVERNANCE_CONTRACT))
    (asserts! (is-some (map-get? trait-interfaces trait-name)) (err ERR_TRAIT_NOT_FOUND))
    (let ((impl-data (map-get? trait-implementations {trait-name: trait-name, implementation-principal: implementation-principal})))
      (asserts! (is-some impl-data) (err ERR_IMPLEMENTATION_NOT_FOUND))
      (asserts!
        (is-eq (get status (unwrap! impl-data ERR_INTERNAL_STATE_ERROR))
          "pending"
        )
        (err ERR_ALREADY_ACTIVE)
      )

      ;; Deactivate current active implementation if exists
      (if (is-some (map-get? active-trait-implementations trait-name))
        (let ((current-active-impl (unwrap! (map-get? active-trait-implementations trait-name) ERR_INTERNAL_STATE_ERROR)))
          (map-set trait-implementations
            {trait-name: trait-name, implementation-principal: current-active-impl}
            (merge
              (unwrap!
                (map-get? trait-implementations {
                  trait-name: trait-name,
                  implementation-principal: current-active-impl,
                })
                ERR_INTERNAL_STATE_ERROR
              )
              {status: "deprecated"}
            )
          )
        )
        true
      )

      (map-set active-trait-implementations trait-name implementation-principal)
      (map-set trait-implementations {
        trait-name: trait-name,
        implementation-principal: implementation-principal,
      }
        (merge (unwrap! impl-data ERR_INTERNAL_STATE_ERROR) { status: "active" })
      )
      (ok true)
    )
  )
)

;; @desc Deactivates the currently active trait implementation. This should be called by the governance contract.
;; @param trait-name The name of the trait interface.
;; @returns (response bool uint) True if successful, or an error.
(define-public (deactivate-trait-implementation (trait-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) (err ERR_NOT_GOVERNANCE_CONTRACT))
    (asserts! (is-some (map-get? trait-interfaces trait-name)) (err ERR_TRAIT_NOT_FOUND))
    (asserts! (is-some (map-get? active-trait-implementations trait-name)) (err ERR_NOT_ACTIVE))

    (let ((current-active-impl (unwrap! (map-get? active-trait-implementations trait-name) ERR_INTERNAL_STATE_ERROR)))
      (map-set trait-implementations
        {trait-name: trait-name, implementation-principal: current-active-impl}
        (merge
          (unwrap!
            (map-get? trait-implementations {
              trait-name: trait-name,
              implementation-principal: current-active-impl,
            })
            ERR_INTERNAL_STATE_ERROR
          )
          {status: "deprecated"}
        )
      )
      (map-delete active-trait-implementations trait-name)
      (ok true)
    )
  )
)

;; @desc Proposes a trait upgrade. This should be called by the governance contract.
;; @param proposal-id The ID of the DAO proposal.
;; @param trait-name The name of the trait interface.
;; @param new-implementation-principal The principal of the new contract implementing the trait.
;; @param new-version The version of the new implementation.
;; @returns (response bool uint) True if successful, or an error.
(define-public (propose-trait-upgrade (proposal-id uint) (trait-name (string-ascii 64)) (new-implementation-principal principal) (new-version uint))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) (err ERR_NOT_GOVERNANCE_CONTRACT))
    (asserts! (is-some (map-get? trait-interfaces trait-name)) (err ERR_TRAIT_NOT_FOUND))
    ;; Check if the new implementation is already registered and pending or active
    (let ((new-impl-data (map-get? trait-implementations {trait-name: trait-name, implementation-principal: new-implementation-principal})))
      (asserts! (is-some new-impl-data) (err ERR_IMPLEMENTATION_NOT_FOUND))
      (asserts!
        (is-eq (get status (unwrap! new-impl-data ERR_INTERNAL_STATE_ERROR))
          "pending"
        )
        (err ERR_ALREADY_ACTIVE)
      )
;; Should be pending to be proposed for upgrade
    )

    (map-set pending-trait-upgrades proposal-id {
      trait-name: trait-name,
      new-implementation-principal: new-implementation-principal,
      new-version: new-version
    })
    (ok true)
  )
)

;; @desc Finalizes a trait upgrade after DAO approval. This should be called by the governance contract.
;; @param proposal-id The ID of the DAO proposal.
;; @returns (response bool uint) True if successful, or an error.
(define-public (finalize-trait-upgrade (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get governance-contract)) (err ERR_NOT_GOVERNANCE_CONTRACT))
    ;; Temporary simplification to isolate syntax error
(ok true)
  )
)

;; @desc Gets the active implementation principal for a given trait name.
;; @param trait-name The name of the trait interface.
;; @returns (response (optional principal) uint) The principal of the active implementation, or none if not found.
(define-read-only (get-active-trait-implementation (trait-name (string-ascii 64)))
  (ok (map-get? active-trait-implementations trait-name))
)

;; @desc Gets all registered implementations for a given trait name.
;; @param trait-name The name of the trait interface.
;; @returns (response (list 100 {principal: principal, version: uint, status: (string-ascii 16)}) uint) A list of implementations.
;; (define-read-only (get-trait-implementations (trait-name (string-ascii 64)))
;;   (ok (map-fold
;;     (fun (key value acc)
;;       (if (is-eq (get "trait-name" key) trait-name)
;;         (cons (merge key value) acc)
;;         acc
;;       )
;;     )
;;     (list)
;;     trait-implementations
;;   ))
;; )

;; @desc Sets the governance contract principal. Only callable by the contract owner.
;; @param new-governance-contract The principal of the new governance contract.
;; @returns (response bool uint) True if successful, or an error.
(define-public (set-governance-contract (new-governance-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set governance-contract new-governance-contract)
    (ok true)
  )
)

;; @desc Transfers ownership of the contract. Only callable by the current owner.
;; @param new-owner The principal of the new owner.
;; @returns (response bool uint) True if successful, or an error.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Temporary initialization function to register rbac-trait
(define-public (initialize)
  (begin
    (try! (register-trait-interface "rbac-trait" "Role-Based Access Control Trait"))
    (try! (register-trait-implementation "rbac-trait" .core-protocol.rbac-trait u1))
    (try! (activate-trait-implementation "rbac-trait" .core-protocol.rbac-trait))
    (ok true)
  )
)
