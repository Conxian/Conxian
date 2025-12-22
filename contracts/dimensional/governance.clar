;; governance.clar
;; Governance and parameter management for dimensional engine

;; Trait imports (ensure centralized traits are available; remove duplicates)
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
;; (use-trait dimensional-core-trait .dimensional.dimensional-trait)
;; (use-trait governance-token-trait .traits.governance.governance-token-trait)
;; (use-trait governance-trait .traits folder.governance-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_PARAM (err u5001))
(define-constant ERR_VOTING_NOT_ACTIVE (err u5002))
(define-constant ERR_ALREADY_VOTED (err u5003))
(define-constant ERR_VOTING_CLOSED (err u5004))
(define-constant ERR_INSUFFICIENT_BALANCE (err u5005))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u5006))
(define-constant ERR_PROPOSAL_FAILED (err u5007))

(define-constant CONTRACT_OWNER tx-sender)

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var governance-token principal tx-sender)
(define-data-var voting-delay uint u1440000)
(define-data-var voting-period uint u10368000)
(define-data-var proposal-threshold uint u100000000)
(define-data-var next-proposal-id uint u1)

;; ===== Data Maps =====

;; Proposal data structure
(define-map proposals
  { id: uint }
  {
    proposer: principal,
    target: principal,
    function: (string-ascii 50),
    args: (list 10 {
      name: (string-ascii 50),
      value: (string-utf8 1024),
    }),
    start-block: uint,
    end-block: uint,
    for-votes: uint,
    against-votes: uint,
    executed: bool,
    canceled: bool,
  }
)

;; Voter information
(define-map votes
  {
    proposal-id: uint,
    voter: principal,
  }
  {
    support: bool,
    votes: uint,
  }
)

;; Track if address has voted on a proposal
(define-map has-voted
  {
    proposal-id: uint,
    voter: principal,
  }
  bool
)

;; ===== Private Functions =====

(define-private (is-voting-active (proposal {
  proposer: principal,
  target: principal,
  function: (string-ascii 50),
  args: (list 10 {
    name: (string-ascii 50),
    value: (string-utf8 1024),
  }),
  start-block: uint,
  end-block: uint,
  for-votes: uint,
  against-votes: uint,
  executed: bool,
  canceled: bool,
}))
  (and
    (>= block-height (get start-block proposal))
    (<= block-height (get end-block proposal))
    (not (get canceled proposal))
  )
)

(define-private (is-proposal-successful (proposal {
  proposer: principal,
  target: principal,
  function: (string-ascii 50),
  args: (list 10 {
    name: (string-ascii 50),
    value: (string-utf8 1024),
  }),
  start-block: uint,
  end-block: uint,
  for-votes: uint,
  against-votes: uint,
  executed: bool,
  canceled: bool,
}))
  (> (get for-votes proposal) (get against-votes proposal))
)

(define-private (update-vote-count
    (proposal-id uint)
    (proposal {
      proposer: principal,
      target: principal,
      function: (string-ascii 50),
      args: (list 10 {
        name: (string-ascii 50),
        value: (string-utf8 1024),
      }),
      start-block: uint,
      end-block: uint,
      for-votes: uint,
      against-votes: uint,
      executed: bool,
      canceled: bool,
    })
    (support bool)
    (weight uint)
  )
  (if support
    (map-set proposals { id: proposal-id }
      (merge proposal { for-votes: (+ (get for-votes proposal) weight) })
    )
    (map-set proposals { id: proposal-id }
      (merge proposal { against-votes: (+ (get against-votes proposal) weight) })
    )
  )
)

;; ===== Public Functions =====

;; @desc Create a new proposal
(define-public (create-proposal
    (target principal)
    (function (string-ascii 50))
    (args (list 10 {
      name: (string-ascii 50),
      value: (string-utf8 1024),
    }))
  )
  (let ((proposal-id (var-get next-proposal-id)))
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)

    (map-set proposals { id: proposal-id } {
      proposer: tx-sender,
      target: target,
      function: function,
      args: args,
      start-block: (+ block-height (var-get voting-delay)),
      end-block: (+ block-height (var-get voting-delay) (var-get voting-period)),
      for-votes: u0,
      against-votes: u0,
      executed: false,
      canceled: false,
    })

    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

;; @desc Cast a vote on a proposal
(define-public (cast-vote
    (proposal-id uint)
    (support bool)
  )
  (let (
      (proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
      (voter-has-voted (default-to false
        (map-get? has-voted {
          proposal-id: proposal-id,
          voter: tx-sender,
        })
      ))
      (weight u1)
    )
    (asserts! (is-voting-active proposal) ERR_VOTING_NOT_ACTIVE)
    (asserts! (not voter-has-voted) ERR_ALREADY_VOTED)

    (update-vote-count proposal-id proposal support weight)

    (map-set votes {
      proposal-id: proposal-id,
      voter: tx-sender,
    } {
      support: support,
      votes: weight,
    })

    (map-set has-voted {
      proposal-id: proposal-id,
      voter: tx-sender,
    }
      true
    )

    (ok true)
  )
)

;; @desc Execute a successful proposal
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get end-block proposal)) ERR_VOTING_NOT_ACTIVE)
    (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
    (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
    (asserts! (is-proposal-successful proposal) ERR_PROPOSAL_FAILED)

    (map-set proposals { id: proposal-id } (merge proposal { executed: true }))

    (ok true)
  )
)

;; @desc Cancel a proposal
(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
    (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)

    (map-set proposals { id: proposal-id } (merge proposal { canceled: true }))

    (ok true)
  )
)

;; ===== Read-Only Functions =====

(define-read-only (get-proposal (proposal-id uint))
  (ok (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND))
)

(define-read-only (get-vote
    (proposal-id uint)
    (voter principal)
  )
  (ok (unwrap! (map-get? votes {
    proposal-id: proposal-id,
    voter: voter,
  })
    ERR_PROPOSAL_NOT_FOUND
  ))
)

(define-read-only (has-user-voted
    (proposal-id uint)
    (voter principal)
  )
  (default-to false
    (map-get? has-voted {
      proposal-id: proposal-id,
      voter: voter,
    })
  )
)

(define-read-only (get-voting-status (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { id: proposal-id }) ERR_PROPOSAL_NOT_FOUND)))
    (ok {
      for-votes: (get for-votes proposal),
      against-votes: (get against-votes proposal),
      total-votes: (+ (get for-votes proposal) (get against-votes proposal)),
      start-block: (get start-block proposal),
      end-block: (get end-block proposal),
      executed: (get executed proposal),
      canceled: (get canceled proposal),
      is-active: (is-voting-active proposal),
      is-successful: (is-proposal-successful proposal),
    })
  )
)

(define-read-only (get-next-proposal-id)
  (ok (var-get next-proposal-id))
)

(define-read-only (get-governance-params)
  (ok {
    owner: (var-get owner),
    governance-token: (var-get governance-token),
    voting-delay: (var-get voting-delay),
    voting-period: (var-get voting-period),
    proposal-threshold: (var-get proposal-threshold),
  })
)
