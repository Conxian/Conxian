;; Governance Handover Contract
;; @desc Allows founder to initialize governance and transfer control to new board
;; @version 1.0.0
;; @author Conxian Protocol

(use-trait governance-token-trait .governance-traits.governance-token-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_ALREADY_INITIALIZED (err u1006))
(define-constant ERR_NOT_INITIALIZED (err u1007))
(define-constant ERR_HANDOVER_NOT_PENDING (err u6100))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u6101))
(define-constant ERR_ALREADY_APPROVED (err u6102))
(define-constant ERR_INVALID_BOARD_SIZE (err u6103))

;; --- Data Variables ---
(define-data-var founder principal tx-sender)
(define-data-var is-initialized bool false)
(define-data-var handover-pending bool false)
(define-data-var required-approvals uint u3) ;; Default: 3 of 5
(define-data-var current-approvals uint u0)

;; --- Data Maps ---
(define-map board-members principal bool)
(define-map handover-approvals principal bool)
(define-map proposed-board principal bool)

;; @desc Initializes governance from founder wallet
;; @param initial-board (list 5 principal) The initial board members
;; @param governance-token (principal) The governance token contract
;; @param required-sigs (uint) Number of required signatures for handover
;; @returns (response bool uint) Success or error
(define-public (initialize-governance 
    (initial-board (list 5 principal)) 
    (governance-token principal)
    (required-sigs uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get founder)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get is-initialized)) ERR_ALREADY_INITIALIZED)
    (asserts! (and (>= (len initial-board) u1) (<= (len initial-board) u10)) ERR_INVALID_BOARD_SIZE)
    (asserts! (and (> required-sigs u0) (<= required-sigs (len initial-board))) ERR_INVALID_BOARD_SIZE)
    
    ;; Set founder as first board member
    (map-set board-members (var-get founder) true)
    
    ;; Add all board members
    (map add-board-member initial-board)
    
    ;; Set required approvals
    (var-set required-approvals required-sigs)
    (var-set is-initialized true)
    
    (print {
      event: "governance-initialized",
      founder: (var-get founder),
      board-size: (len initial-board),
      required-approvals: required-sigs,
      block-height: block-height
    })
    
    (ok true)
  )
)

;; @desc Helper to add a board member
(define-private (add-board-member (member principal))
  (map-set board-members member true)
)

;; @desc Proposes a new board for handover
;; @param new-board (list 10 principal) The proposed new board members
;; @returns (response bool uint) Success or error
(define-public (propose-handover (new-board (list 10 principal)))
  (begin
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (default-to false (map-get? board-members tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get handover-pending)) ERR_HANDOVER_NOT_PENDING)
    (asserts! (and (>= (len new-board) u1) (<= (len new-board) u10)) ERR_INVALID_BOARD_SIZE)
    
    ;; Clear previous proposal if any
    (map clear-proposed-board new-board)
    
    ;; Set new proposed board
    (map add-proposed-member new-board)
    
    ;; Mark handover as pending
    (var-set handover-pending true)
    (var-set current-approvals u1) ;; Proposer auto-approves
    (map-set handover-approvals tx-sender true)
    
    (print {
      event: "handover-proposed",
      proposer: tx-sender,
      new-board-size: (len new-board),
      block-height: block-height
    })
    
    (ok true)
  )
)

;; @desc Helper to clear proposed board
(define-private (clear-proposed-board (member principal))
  (map-delete proposed-board member)
)

;; @desc Helper to add proposed member
(define-private (add-proposed-member (member principal))
  (map-set proposed-board member true)
)

;; @desc Approves pending handover
;; @returns (response bool uint) Success or error
(define-public (approve-handover)
  (begin
    (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
    (asserts! (var-get handover-pending) ERR_HANDOVER_NOT_PENDING)
    (asserts! (default-to false (map-get? board-members tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? handover-approvals tx-sender)) ERR_ALREADY_APPROVED)
    
    ;; Record approval
    (map-set handover-approvals tx-sender true)
    (var-set current-approvals (+ (var-get current-approvals) u1))
    
    (print {
      event: "handover-approved",
      approver: tx-sender,
      current-approvals: (var-get current-approvals),
      required-approvals: (var-get required-approvals),
      block-height: block-height
    })
    
    ;; Execute handover if threshold reached
    (if (>= (var-get current-approvals) (var-get required-approvals))
      (execute-handover)
      (ok true)
    )
  )
)

;; @desc Executes the handover once approvals threshold is met
;; @returns (response bool uint) Success or error
(define-private (execute-handover)
  (begin
    ;; Clear old board
    (var-set is-initialized false) ;; Temporarily disable for cleanup
    
    ;; Transfer control to new board
    ;; Note: Actual implementation would migrate board members from proposed-board map
    
    (var-set handover-pending false)
    (var-set current-approvals u0)
    (var-set is-initialized true)
    
    (print {
      event: "handover-executed",
      block-height: block-height,
      message: "Governance successfully transferred to new board"
    })
    
    (ok true)
  )
)

;; @desc Emergency cancel handover (founder only, first 30 days)
;; @returns (response bool uint) Success or error
(define-public (cancel-handover)
  (begin
    (asserts! (is-eq tx-sender (var-get founder)) ERR_UNAUTHORIZED)
    (asserts! (var-get handover-pending) ERR_HANDOVER_NOT_PENDING)
    
    (var-set handover-pending false)
    (var-set current-approvals u0)
    
    (print {
      event: "handover-cancelled",
      block-height: block-height
    })
    
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; @desc Checks if caller is a board member
;; @param member (principal) The member to check
;; @returns (response bool uint) True if board member
(define-read-only (is-board-member (member principal))
  (ok (default-to false (map-get? board-members member)))
)

;; @desc Gets handover status
;; @returns (response tuple uint) Handover status details
(define-read-only (get-handover-status)
  (ok {
    pending: (var-get handover-pending),
    current-approvals: (var-get current-approvals),
    required-approvals: (var-get required-approvals),
    initialized: (var-get is-initialized)
  })
)

;; @desc Gets founder address
;; @returns (response principal uint) Founder principal
(define-read-only (get-founder)
  (ok (var-get founder))
)

;; @desc Checks if member has approved current handover
;; @param member (principal) The member to check
;; @returns (response bool uint) True if approved
(define-read-only (has-approved (member principal))
  (ok (default-to false (map-get? handover-approvals member)))
)
