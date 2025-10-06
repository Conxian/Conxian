;; Access Control Contract
;; Implements the access control functionality specified in AIP-7

;; --- Traits ---
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)

(impl-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(impl-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)

;; Constants
(define-constant TRAIT_REGISTRY .trait-registry)

;; Roles
(define-constant ROLE_ADMIN 0x41444d494e) ;; ADMIN in hex
(define-constant ROLE_OPERATOR 0x4f50455241544f52) ;; OPERATOR in hex
(define-constant ROLE_EMERGENCY 0x454d455247454e4359) ;; EMERGENCY in hex
(define-constant ERR_CIRCUIT_OPEN (err u5000))

;; Data storage
(define-data-var owner principal tx-sender)
;; roles: who -> list of role strings
(define-map roles
  principal
  (list (string-ascii 32))
)
(define-data-var paused bool false)
(define-data-var circuit-breaker principal .circuit-breaker)
;; proposals: id -> proposal tuple
(define-map proposals
  uint
  {
    id: uint,
    proposer: principal,
    target: principal,
    value: uint,
    data: (buff 1024),
    description: (string-utf8 500),
    approvals: (list principal),
    executed: bool,
  }
)
(define-data-var last-proposal-id uint u0)

(define-constant PROPOSAL_THRESHOLD u2) ;; Number of approvals required

(define-private (check-circuit-breaker)
  (contract-call? (var-get circuit-breaker) is-circuit-open)
)

;; ===== Role Management =====

(define-public (has-role
    (who principal)
    (role (string-ascii 32))
  )
  (let ((user-roles (unwrap! (map-get? roles who) (list))))
    (ok (contains? role user-roles))
  )
)

(define-public (grant-role
    (who principal)
    (role (string-ascii 32))
  )
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-admin tx-sender) (err u1001)) ;; ERR_NOT_ADMIN

    (let ((user-roles (unwrap! (map-get? roles who) (list))))
      (if (not (contains? role user-roles))
        (map-set roles who (append user-roles (list role)))
      )
    )

    (print {
      event: "role-granted",
      role: role,
      account: who,
      sender: tx-sender,
    })

    (ok true)
  )
)

(define-public (revoke-role
    (who principal)
    (role (string-ascii 32))
  )
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-admin tx-sender) (err u1001)) ;; ERR_NOT_ADMIN

    (let ((user-roles (unwrap! (map-get? roles who) (list))))
      (if (contains? role user-roles)
        (map-set roles who
          (filter (lambda ((r (string-ascii 32))) (not (is-eq r role)))
            user-roles
          ))
      )
    )

    (print {
      event: "role-revoked",
      role: role,
      account: who,
    })

    (ok true)
  )
)

;; ===== Access Control =====

(define-public (only-role (role (string-ascii 32)))
  (let ((has-role (unwrap! (contract-call? .self has-role tx-sender role) false)))
    (if has-role
      (ok true)
      (err u1002) ;; ERR_MISSING_ROLE
    )
  )
)

(define-public (only-roles (required-roles (list (string-ascii 32))))
  (let ((has-any-role (any
      (lambda ((role (string-ascii 32)))
        (unwrap! (contract-call? .self has-role tx-sender role) false)
      )
      required-roles
    )))
    (if has-any-role
      (ok true)
      (err u1002) ;; ERR_MISSING_ROLE
    )
  )
)

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1001))
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

;; ===== Emergency Controls =====

(define-public (pause)
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts!
      (unwrap! (contract-call? .self has-role tx-sender ROLE_EMERGENCY) false)
      (err u1003)
    )
    ;; ERR_NOT_EMERGENCY_ADMIN
    (var-set paused true)
    (print {
      event: "paused",
      by: tx-sender,
    })
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts!
      (unwrap! (contract-call? .self has-role tx-sender ROLE_EMERGENCY) false)
      (err u1003)
    )
    ;; ERR_NOT_EMERGENCY_ADMIN
    (var-set paused false)
    (print {
      event: "unpaused",
      by: tx-sender,
    })
    (ok true)
  )
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

;; ===== Multi-sig Operations =====

;; @desc Proposes a new multi-sig operation that requires approvals before execution.
;; @param target The principal of the contract to call.
;; @param value The STX amount to send with the call (if any).
;; @param data The data buffer to pass to the target contract function.
;; @param description A description of the proposal.
;; @return (response uint uint) A response tuple indicating success or failure, with the proposal ID on success.
(define-public (propose
    (target principal)
    (value uint)
    (data (buff 1024))
    (description (string-utf8 500))
  )
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let (
        (proposal-id (+ (var-get last-proposal-id) u1))
        (proposal {
          id: proposal-id,
          proposer: tx-sender,
          target: target,
          value: value,
          data: data,
          description: description,
          approvals: (list tx-sender),
          executed: false,
        })
      )
      (map-set proposals proposal-id proposal)
      (var-set last-proposal-id proposal-id)

      (print {
        event: "proposal-created",
        id: proposal-id,
        proposer: tx-sender,
        description: description,
      })

      (ok proposal-id)
    )
  )
)

;; @desc Approves a multi-sig proposal, adding the sender to the list of approvers.
;; @param proposal-id The ID of the proposal to approve.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (approve (proposal-id uint))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u1004))))
      ;; ERR_PROPOSAL_NOT_FOUND
      (asserts! (not (contains? tx-sender (get approvals proposal))) (err u1005))
      ;; ERR_ALREADY_APPROVED

      (map-set proposals proposal-id
        (merge proposal { approvals: (append (get approvals proposal) (list tx-sender)) })
      )

      (print {
        event: "proposal-approved",
        id: proposal-id,
        approver: tx-sender,
        approvals: (len (get approvals proposal)),
      })

      (ok true)
    )
  )
)

;; @desc Executes a multi-sig proposal after it has received sufficient approvals and the circuit breaker is not open.
;; @param proposal-id The ID of the proposal to execute.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (execute-proposal (proposal-id uint))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u1004))))
      ;; ERR_PROPOSAL_NOT_FOUND
      (asserts! (not (get executed proposal)) (err u1006))
      ;; ERR_ALREADY_EXECUTED
      (asserts! (>= (len (get approvals proposal)) PROPOSAL_THRESHOLD)
        (err u1007)
      )
      ;; ERR_NOT_ENOUGH_APPROVALS

      ;; Mark as executed before execution to prevent reentrancy
      (map-set proposals proposal-id (merge proposal { executed: true }))

      ;; NOTE: Dynamic execution omitted in this version for safety; treat as executed.
      (print {
        event: "proposal-executed",
        id: proposal-id,
        executor: tx-sender,
      })
      (ok true)
    )
  )
)

(define-map delayed-operations
  { operation-id: uint }
  {
    proposer: principal,
    target: principal,
    function-name: (string-ascii 64),
    parameters: (buff 1024),
    delay-blocks: uint,
    created-at: uint,
    executed: bool,
    approvals: (list principal),
  }
)

(define-data-var next-operation-id uint u1)
(define-data-var default-delay-blocks uint u144) ;; ~24 hours at 10 min blocks

;; Propose a time-delayed operation
;; @desc Proposes a time-delayed operation that requires admin privileges and approvals.
;; @param target The principal of the contract to call.
;; @param function-name The name of the function to execute on the target contract.
;; @param parameters The data buffer containing the parameters for the function call.
;; @param delay-blocks The number of blocks to delay the execution.
;; @return (response uint uint) A response tuple indicating success or failure, with the operation ID on success.
(define-public (propose-delayed-operation
    (target principal)
    (function-name (string-ascii 64))
    (parameters (buff 1024))
    (delay-blocks uint)
  )
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-admin tx-sender) (err u1001))

    (let (
        (operation-id (var-get next-operation-id))
        (operation {
          proposer: tx-sender,
          target: target,
          function-name: function-name,
          parameters: parameters,
          delay-blocks: (if (> delay-blocks u0)
            delay-blocks
            (var-get default-delay-blocks)
          ),
          created-at: block-height,
          executed: false,
          approvals: (list tx-sender),
        })
      )
      (map-set delayed-operations { operation-id: operation-id } operation)
      (var-set next-operation-id (+ operation-id u1))

      (print {
        event: "delayed-operation-proposed",
        id: operation-id,
        proposer: tx-sender,
        target: target,
        function: function-name,
        delay: delay-blocks,
      })

      (ok operation-id)
    )
  )
)

;; Approve a delayed operation (multi-sig)
;; @desc Approves a time-delayed operation, adding the sender to the list of approvers.
;; @param operation-id The ID of the delayed operation to approve.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (approve-delayed-operation (operation-id uint))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((operation (unwrap! (map-get? delayed-operations { operation-id: operation-id })
        (err u1004)
      )))
      (asserts! (not (contains? tx-sender (get approvals operation))) (err u1005))
      (asserts! (not (get executed operation)) (err u1006))

      (map-set delayed-operations { operation-id: operation-id }
        (merge operation { approvals: (append (get approvals operation) (list tx-sender)) })
      )

      (print {
        event: "delayed-operation-approved",
        id: operation-id,
        approver: tx-sender,
        total-approvals: (len (get approvals operation)),
      })

      (ok true)
    )
  )
)

;; Execute a delayed operation after delay period and sufficient approvals
;; @desc Executes a time-delayed operation after the delay period has passed and sufficient approvals have been gathered.
;; @param operation-id The ID of the delayed operation to execute.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (execute-delayed-operation (operation-id uint))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (let ((operation (unwrap! (map-get? delayed-operations { operation-id: operation-id })
        (err u1004)
      )))
      (asserts! (not (get executed operation)) (err u1006))
      (asserts! (>= (len (get approvals operation)) PROPOSAL_THRESHOLD)
        (err u1007)
      )

      ;; Check if delay period has passed
      (asserts!
        (>= (- block-height (get created-at operation))
          (get delay-blocks operation)
        )
        (err u1008)
      )

      ;; Mark as executed
      (map-set delayed-operations { operation-id: operation-id }
        (merge operation { executed: true })
      )

      ;; NOTE: Dynamic execution omitted in this version for safety; treat as executed.
      (print {
        event: "delayed-operation-executed",
        id: operation-id,
        executor: tx-sender,
      })
      (ok true)
    )
  )
)

;; Get operation details
;; @desc Retrieves the details of a specific delayed operation.
;; @param operation-id The ID of the delayed operation to retrieve.
;; @return (response (optional {proposer: principal, target: principal, function-name: (string-ascii 64), parameters: (buff 1024), delay-blocks: uint, created-at: uint, executed: bool, approvals: (list principal)}) bool) A response tuple containing the operation details or an error if not found.
(define-read-only (get-delayed-operation (operation-id uint))
  (map-get? delayed-operations { operation-id: operation-id })
)

;; Check if operation can be executed
;; @desc Checks if a delayed operation can be executed based on approvals, delay period, and execution status.
;; @param operation-id The ID of the delayed operation to check.
;; @return (response bool bool) A response tuple indicating whether the operation can be executed.
(define-read-only (can-execute-delayed-operation (operation-id uint))
  (let ((operation (unwrap! (map-get? delayed-operations { operation-id: operation-id }) false)))
    (if operation
      (let (
          (blocks-passed (- block-height (get created-at operation)))
          (has-enough-approvals (>= (len (get approvals operation)) PROPOSAL_THRESHOLD))
          (delay-passed (>= blocks-passed (get delay-blocks operation)))
          (not-executed (not (get executed operation)))
        )
        (and
          has-enough-approvals
          delay-passed
          not-executed
        )
      )
      false
    )
  )
)
;; ===== Helper Functions =====

(define-private (is-admin (who principal))
  (or
    (is-eq who (var-get owner))
    (unwrap! (contract-call? .self has-role who ROLE_ADMIN) false)
  )
)

(define-private (contains?
    (needle (string-ascii 32))
    (haystack (list (string-ascii 32)))
  )
  (any (lambda ((item (string-ascii 32))) (is-eq item needle)) haystack)
)

(define-private (contains-principal?
    (needle principal)
    (haystack (list principal))
  )
  (any (lambda ((item principal)) (is-eq item needle)) haystack)
)
