;; ===========================================
;; DIMENSIONAL TRAITS MODULE
;; ===========================================
;; @desc Multi-dimensional DeFi specific traits.
;; Optimized for complex position management.

;; ===========================================
;; DIMENSIONAL TRAIT
;; ===========================================
;; @desc Interface for a dimensional position.
(define-trait dimensional-trait
  (
    ;; @desc Gets the details of a specific position.
    ;; @param position-id: The ID of the position to retrieve.
    ;; @returns (response (optional { ... }) uint): A tuple containing the position details, or none if the position is not found.
    (get-position (uint) (response (optional {
      owner: principal,
      asset: principal,
      collateral: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      is-long: bool
    }) uint))

    ;; @desc Closes a position.
    ;; @param position-id: The ID of the position to close.
    ;; @param amount: The amount of the position to close.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (close-position (uint uint) (response bool uint))

    ;; @desc Gets the protocol statistics.
    ;; @returns (response { ... } uint): A tuple containing the protocol statistics, or an error code.
    (get-protocol-stats () (response {
      total-positions: uint,
      total-volume: uint,
      total-value-locked: uint
    } uint))
  )
)

;; ===========================================
;; DIMENSIONAL REGISTRY TRAIT
;; ===========================================
;; @desc Interface for a dimensional registry.
(define-trait dim-registry-trait
  (
    ;; @desc Registers a new node in the registry.
    ;; @param principal: The principal of the node to register.
    ;; @param data: A tuple containing the node's type and metadata.
    ;; @returns (response uint uint): The ID of the newly registered node, or an error code.
    (register-node (principal {type: (string-ascii 32), metadata: (optional (string-utf8 256))}) (response uint uint))

    ;; @desc Gets the details of a specific node.
    ;; @param node-id: The ID of the node to retrieve.
    ;; @returns (response (optional { ... }) uint): A tuple containing the node details, or none if the node is not found.
    (get-node (uint) (response (optional {
      principal: principal,
      type: (string-ascii 32),
      metadata: (optional (string-utf8 256)),
      active: bool
    }) uint))

    ;; @desc Updates the status of a node.
    ;; @param node-id: The ID of the node to update.
    ;; @param active: A boolean indicating the new status of the node.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (update-node-status (uint bool) (response bool uint))
  )
)
