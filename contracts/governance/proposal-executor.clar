;; proposal-executor.clar
;;
;; This contract is responsible for the execution of governance proposals.
;; It contains the logic for validating quorums and checking proposal states.
;;

(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u3001))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u3003))
(define-constant ERR_VOTING_CLOSED (err u3004))
(define-constant ERR_QUORUM_NOT_REACHED (err u3006))
(define-constant ERR_PROPOSAL_FAILED (err u3007))

(define-public (execute (proposal-id uint) (quorum-percentage uint))
  (let ((maybe-proposal (try! (contract-call? .proposal-registry get-proposal proposal-id))))
    (match maybe-proposal
      proposal (let (
          (total-votes (+ (get for-votes proposal) (get against-votes proposal)))
          (governance-token-supply (unwrap! (contract-call? .governance-token get-total-supply) (err u999)))
          (quorum (/ (* total-votes u10000) governance-token-supply))
        )
        (begin
          (asserts! (is-eq tx-sender (get proposer proposal)) ERR_UNAUTHORIZED)
          (asserts! (>= burn-block-height (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
          (asserts! (not (get executed proposal)) ERR_VOTING_CLOSED)
          (asserts! (not (get canceled proposal)) ERR_VOTING_CLOSED)
          (asserts! (> (get for-votes proposal) (get against-votes proposal)) ERR_PROPOSAL_FAILED)
          (asserts! (>= quorum quorum-percentage) ERR_QUORUM_NOT_REACHED)
          (try! (contract-call? .proposal-registry set-executed proposal-id))
          (print {
            event: "proposal-executed",
            proposal-id: proposal-id,
            votes-for: (get for-votes proposal),
            votes-against: (get against-votes proposal),
          })
          (ok true)
        )
      )
      ERR_PROPOSAL_NOT_FOUND
    )
  )
)
