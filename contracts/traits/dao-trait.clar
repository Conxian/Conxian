;; dao-trait.clar
;; Defines the interface for DAO functionality

(define-trait dao-trait
  ;; Check if an address has voting power
  (has-voting-power (address principal) (response bool uint))
  
  ;; Get the voting power of an address
  (get-voting-power (address principal) (response uint uint))
  
  ;; Get the total voting power
  (get-total-voting-power () (response uint uint))
  
  ;; Delegate voting power to another address
  (delegate (delegatee principal) (response bool uint))
  
  ;; Undelegate voting power
  (undelegate () (response bool uint))
  
  ;; Execute a proposal
  (execute-proposal (proposal-id uint) (response bool uint))
  
  ;; Vote on a proposal
  (vote (proposal-id uint) (support bool) (response bool uint))
  
  ;; Get proposal details
  (get-proposal (proposal-id uint) 
    (response {
      id: uint,
      proposer: principal,
      start-block: uint,
      end-block: uint,
      for-votes: uint,
      against-votes: uint,
      executed: bool,
      canceled: bool
    } uint)
  )
)
