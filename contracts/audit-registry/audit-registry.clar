;; @desc DAO-based contract security audit registry.
;; This contract handles audit submissions, DAO voting, and NFT badge issuance.

;; --- Traits ---
(use-trait dao .governance-traits.dao-trait)

;; @constants
;; @var CONTRACT_OWNER: The principal of the contract owner.
(define-constant CONTRACT_OWNER tx-sender)
;; @var ERR_UNAUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_UNAUTHORIZED (err u1001))
;; @var ERR_AUDIT_NOT_FOUND: The specified audit was not found.
(define-constant ERR_AUDIT_NOT_FOUND (err u4000))
;; @var ERR_INVALID_STATUS: The specified status is invalid.
(define-constant ERR_INVALID_STATUS (err u1005))
;; @var ERR_VOTING_CLOSED: The voting period for the specified audit has closed.
(define-constant ERR_VOTING_CLOSED (err u6002))
;; @var ERR_ALREADY_VOTED: The caller has already voted on the specified audit.
(define-constant ERR_ALREADY_VOTED (err u6001))
;; @var ERR_INSUFFICIENT_STAKE: The caller has an insufficient stake to perform this action.
(define-constant ERR_INSUFFICIENT_STAKE (err u6003))
;; @var ERR_INVALID_VOTE_WEIGHT: The vote weight is invalid.
(define-constant ERR_INVALID_VOTE_WEIGHT (err u6003))
;; @var ERR_VOTING_ACTIVE: The voting period for the specified audit is still active.
(define-constant ERR_VOTING_ACTIVE (err u6001))

;; @data-vars
;; @var next-audit-id: The ID of the next audit to be submitted.
(define-data-var next-audit-id uint u1)
;; @var min-stake-amount: The minimum stake amount required to submit an audit.
(define-data-var min-stake-amount uint u100000000) ;; 100 STX in microSTX
;; @var voting-period: The length of the voting period in blocks.
(define-data-var voting-period uint u1209600) ;; ~7 days in blocks
;; @var dao-contract: The principal of the DAO contract.
(define-data-var dao-contract (optional principal) none)
;; @var quorum-threshold: The quorum threshold for a vote to pass, in basis points.
(define-data-var quorum-threshold uint u5000) ;; 50% in basis points
;; @var audits: A map of audit IDs to their data.
(define-map audits
  { id: uint }
  {
    contract-address: principal,
    audit-hash: (string-ascii 64),
    auditor: principal,
    report-uri: (string-utf8 256),
    timestamp: uint,
    status: {
      status: (string-ascii 22),
      reason: (optional (string-utf8 500)),
    },
    votes: {
      for: uint,
      against: uint,
      total-weight: uint,
    },
    voting-ends: uint,
    finalized: bool,
  }
)
;; @var voter-records: A map that tracks the votes of each voter for each audit.
(define-map voter-records
  {
    audit-id: uint,
    voter: principal,
  }
  {
    vote: bool,
    weight: uint,
    timestamp: uint,
  }
)
;; @var staked-amounts: A map that tracks the staked amounts of each staker.
(define-map staked-amounts
  { staker: principal }
  {
    amount: uint,
    last-vote: uint,
  }
)

;; --- Private Helper Functions ---
;; @desc Get the voting weight of a voter.
;; @param voter: The principal of the voter.
;; @returns (response uint uint): The voting weight of the voter, or a default weight if the DAO contract is not configured or the call fails.
(define-private (get-voting-weight (voter principal))
  (match (var-get dao-contract)
    dao
    ;; Temporarily simplify until dao trait is available
    (ok u1) ;; Default weight
    (ok u1)
  )
)
;; Default weight if no DAO configured

;; @desc Check if a voter has already voted on an audit.
;; @param audit-id: The ID of the audit.
;; @param voter: The principal of the voter.
;; @returns (bool): True if the voter has already voted, false otherwise.
(define-private (has-voted
    (audit-id uint)
    (voter principal)
  )
  (is-some (map-get? voter-records {
    audit-id: audit-id,
    voter: voter,
  }))
)

;; @desc Calculate if the quorum for an audit has been met.
;; @param for-votes: The number of "for" votes.
;; @param against-votes: The number of "against" votes.
;; @returns (bool): True if the quorum has been met, false otherwise.
(define-private (calculate-quorum-met
    (for-votes uint)
    (against-votes uint)
  )
  (let ((total-votes (+ for-votes against-votes)))
    (and
      (> total-votes u0)
      (>= (* for-votes u10000) (* total-votes (var-get quorum-threshold)))
    )
  )
)

;; --- Public Functions ---
;; @desc Submit a new audit.
;; @param contract-address: The address of the contract that was audited.
;; @param audit-hash: The hash of the audit report.
;; @param report-uri: The URI of the audit report.
;; @returns (response uint uint): The ID of the new audit, or an error code.
(define-public (submit-audit
    (contract-address principal)
    (audit-hash (string-ascii 64))
    (report-uri (string-utf8 256))
  )
  (let (
      (audit-id (var-get next-audit-id))
      (caller tx-sender)
    )
    ;; Validate DAO voting power if configured
    ;; Validate DAO voting power if configured
    ;; (match (var-get dao-contract) ... ) - skipped for now

    (map-set audits { id: audit-id } {
      contract-address: contract-address,
      audit-hash: audit-hash,
      auditor: caller,
      report-uri: report-uri,
      timestamp: block-height,
      status: {
        status: "pending",
        reason: none,
      },
      votes: {
        for: u0,
        against: u0,
        total-weight: u0,
      },
      voting-ends: (+ block-height (var-get voting-period)),
      finalized: false,
    })

    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

;; @desc Vote on an audit.
;; @param audit-id: The ID of the audit to vote on.
;; @param approve: A boolean indicating whether to approve or reject the audit.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (vote
    (audit-id uint)
    (approve bool)
  )
  (let (
      (caller tx-sender)
      (audit (unwrap! (map-get? audits { id: audit-id }) ERR_AUDIT_NOT_FOUND))
      (vote-weight (unwrap! (get-voting-weight caller) ERR_INVALID_VOTE_WEIGHT))
    )
    (asserts! (<= block-height (get voting-ends audit)) ERR_VOTING_CLOSED)
    (asserts! (not (get finalized audit)) ERR_VOTING_CLOSED)
    (asserts! (not (has-voted audit-id caller)) ERR_ALREADY_VOTED)

    ;; Record the vote
    (map-set voter-records {
      audit-id: audit-id,
      voter: caller,
    } {
      vote: approve,
      weight: vote-weight,
      timestamp: block-height,
    })

    ;; Update audit votes
    (let ((current-votes (get votes audit)))
      (map-set audits { id: audit-id }
        (merge audit { votes: {
          for: (if approve
            (+ (get for current-votes) vote-weight)
            (get for current-votes)
          ),
          against: (if approve
            (get against current-votes)
            (+ (get against current-votes) vote-weight)
          ),
          total-weight: (+ (get total-weight current-votes) vote-weight),
        } }
        ))
    )

    (ok true)
  )
)

;; @desc Finalize an audit.
;; @param audit-id: The ID of the audit to finalize.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (finalize-audit (audit-id uint))
  (let (
      (audit (unwrap! (map-get? audits { id: audit-id }) ERR_AUDIT_NOT_FOUND))
      (votes (get votes audit))
    )
    (asserts! (> block-height (get voting-ends audit)) ERR_VOTING_ACTIVE)
    (asserts! (not (get finalized audit)) ERR_INVALID_STATUS)

    (let (
        (quorum-met (calculate-quorum-met (get for votes) (get against votes)))
        (approved (>= (get for votes) (get against votes)))
      )
      (if (and quorum-met approved)
        (begin
          (map-set audits { id: audit-id }
            (merge audit {
              status: {
                status: "approved",
                reason: none,
              },
              finalized: true,
            })
          )
          ;; Mint NFT for successful audit
          (try! (contract-call? .audit-badge-nft mint audit-id (get report-uri audit)
            (get auditor audit)
          ))
          true
        )
        (map-set audits { id: audit-id }
          (merge audit {
            status: {
              status: "rejected",
              reason: (some (if quorum-met
                u"Majority voted against"
                u"Quorum not met"
              )),
            },
            finalized: true,
          })
        )
      )

      (ok true)
    )
  )
)

;; --- Read-only Functions ---
;; @desc Get the data for an audit.
;; @param audit-id: The ID of the audit.
;; @returns (response { ... } uint): A tuple containing the audit data, or an error code.
(define-read-only (get-audit (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok audit)
    (err ERR_AUDIT_NOT_FOUND)
  )
)

;; @desc Get the status of an audit.
;; @param audit-id: The ID of the audit.
;; @returns (response { ... } uint): A tuple containing the audit status, or an error code.
(define-read-only (get-audit-status (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok (get status audit))
    (err ERR_AUDIT_NOT_FOUND)
  )
)

;; @desc Get the votes for an audit.
;; @param audit-id: The ID of the audit.
;; @returns (response { ... } uint): A tuple containing the audit votes, or an error code.
(define-read-only (get-audit-votes (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (ok (get votes audit))
    (err ERR_AUDIT_NOT_FOUND)
  )
)

;; @desc Get the record of a voter for an audit.
;; @param audit-id: The ID of the audit.
;; @param voter: The principal of the voter.
;; @returns (response (optional { ... }) uint): A tuple containing the voter record, or none if not found.
(define-read-only (get-voter-record
    (audit-id uint)
    (voter principal)
  )
  (ok (map-get? voter-records {
    audit-id: audit-id,
    voter: voter,
  }))
)

;; @desc Get the quorum status for an audit.
;; @param audit-id: The ID of the audit.
;; @returns (response { ... } uint): A tuple containing the quorum status, or an error code.
(define-read-only (get-quorum-status (audit-id uint))
  (match (map-get? audits { id: audit-id })
    audit (let ((votes (get votes audit)))
      (ok {
        quorum-met: (calculate-quorum-met (get for votes) (get against votes)),
        for-votes: (get for votes),
        against-votes: (get against votes),
        total-weight: (get total-weight votes),
      })
    )
    (err ERR_AUDIT_NOT_FOUND)
  )
)

;; --- Admin Functions ---
;; @desc Set the voting period.
;; @param blocks: The new voting period in blocks.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-voting-period (blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set voting-period blocks)
    (ok true)
  )
)

;; @desc Set the quorum threshold.
;; @param threshold: The new quorum threshold in basis points.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-quorum-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= threshold u10000) ERR_INVALID_STATUS)
    (var-set quorum-threshold threshold)
    (ok true)
  )
)

;; @desc Pause an audit in an emergency.
;; @param audit-id: The ID of the audit.
;; @param reason: The reason for the pause.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (emergency-pause-audit
    (audit-id uint)
    (reason (string-utf8 500))
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (let ((audit (unwrap! (map-get? audits { id: audit-id }) ERR_AUDIT_NOT_FOUND)))
      (map-set audits { id: audit-id }
        (merge audit {
          status: {
            status: "paused",
            reason: (some reason),
          },
          finalized: true,
        })
      )
      (ok true)
    )
  )
)

;; @desc Initialize the contract.
;; @param maybe-dao: An optional principal of the DAO contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (initialize (maybe-dao (optional principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set dao-contract maybe-dao)
    (ok true)
  )
)
