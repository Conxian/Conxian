;; lending-protocol-governance.clar
;; Governance contract for the Conxian lending protocol
;; Integrates with AccessControl for role-based access

;; --- Traits ---
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(define-constant TRAIT_REGISTRY .trait-registry)

(define-constant ERR_UNAUTHORIZED (err u8001))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u8002))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u8003))
(define-constant ERR_ALREADY_VOTED (err u8004))
(define-constant ERR_INSUFFICIENT_VOTING_POWER (err u8005))
(define-constant ERR_PROPOSAL_NOT_PASSED (err u8006))
(define-constant ERR_EXECUTION_FAILED (err u8007))
(define-constant ERR_INVALID_PARAMETERS (err u8008))

(define-constant PRECISION u1000000000000000000) ;; 18 decimals

;; Governance parameters
(define-data-var voting-delay uint u1008) ;; ~1 week in blocks
(define-data-var voting-period uint u2016) ;; ~2 weeks in blocks
(define-data-var quorum-threshold uint u40000000000000000) ;; 4% of total supply
(define-data-var proposal-threshold uint u10000000000000000000000) ;; 10K tokens to propose
(define-data-var execution-delay uint u1440) ;; ~1 day timelock

;; Roles
(define-constant ROLE_GOVERNOR 0x474f5645524e4f52000000000000000000000000000000000000000000000000)  ;; GOVERNOR in hex
(define-constant ROLE_GUARDIAN 0x475541524449414e000000000000000000000000000000000000000000000000)  ;; GUARDIAN in hex

;; Protocol state
(define-data-var governance-token principal tx-sender) ;; Should be set to CXS token
(define-data-var timelock-address (optional principal) none) ;; Timelock contract address

;; Proposal tracking
(define-data-var next-proposal-id uint u1)
(define-data-var total-proposals uint u0)

;; Proposal states
(define-constant PROPOSAL_PENDING u1)
(define-constant PROPOSAL_ACTIVE u2) 
(define-constant PROPOSAL_SUCCEEDED u3)
(define-constant PROPOSAL_DEFEATED u4)
(define-constant PROPOSAL_QUEUED u5)
(define-constant PROPOSAL_EXECUTED u6)
(define-constant PROPOSAL_CANCELLED u7)

;; Proposal types
(define-constant PROPOSAL_TYPE_PARAMETER u1)
(define-constant PROPOSAL_TYPE_UPGRADE u2)
(define-constant PROPOSAL_TYPE_TREASURY u3)
(define-constant PROPOSAL_TYPE_EMERGENCY u4)

;; Proposals
(define-map proposals
  uint ;; proposal-id
  {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-utf8 500),
    proposal-type: uint,
    target-contract: (optional principal),
    function-name: (optional (string-ascii 50)),
    parameters: (optional (list 10 uint)),
    for-votes: uint,
    against-votes: uint,
    abstain-votes: uint,
    start-block: uint,
    end-block: uint,
    queue-block: (optional uint),
    execution-block: (optional uint),
    state: uint,
    created-at: uint
  })

;; Vote records
(define-map vote-receipts
  { proposal-id: uint, voter: principal }
  { support: uint, votes: uint, reason: (optional (string-utf8 200)) })

;; Voting power snapshots
(define-map voting-power-snapshots
  { user: principal, block-height: uint }
  uint)

;; Parameter change proposals
(define-map parameter-proposals
  uint ;; proposal-id
  {
    parameter-name: (string-ascii 50),
    current-value: uint,
    proposed-value: uint,
    target-contract: principal
  })

;; Treasury proposals
(define-map treasury-proposals
  uint ;; proposal-id
  {
    recipient: principal,
    amount: uint,
    token: principal,
    purpose: (string-utf8 200)
  })

;; Delegation
(define-map delegates
  principal ;; delegator
  principal) ;; delegate

;; Protocol state
(define-data-var cxvg-utility-contract principal .cxvg-utility)

;; === GOVERNANCE FUNCTIONS ===

;; Create a new proposal
(define-public (propose 
  (title (string-ascii 100))
  (description (string-utf8 500))
  (proposal-type uint)
  (target-contract (optional principal))
  (function-name (optional (string-ascii 50)))
  (parameters (optional (list 10 uint))))
  (let ((proposal-id (var-get next-proposal-id))
        (proposer tx-sender)
        (voting-power (get-voting-power-at proposer (- block-height u1))))
    
    (begin
      ;; Check proposal threshold
      (asserts! (>= voting-power (var-get proposal-threshold)) ERR_INSUFFICIENT_VOTING_POWER)
      
      ;; Create proposal
      (map-set proposals proposal-id
        {
          proposer: proposer,
          title: title,
          description: description,
          proposal-type: proposal-type,
          target-contract: target-contract,
          function-name: function-name,
          parameters: parameters,
          for-votes: u0,
          against-votes: u0,
          abstain-votes: u0,
          start-block: (+ block-height (var-get voting-delay)),
          end-block: (+ block-height (var-get voting-delay) (var-get voting-period)),
          queue-block: none,
          execution-block: none,
          state: PROPOSAL_PENDING,
          created-at: (unwrap-panic (get-block-info? time block-height))
        })
      
      ;; Update counters
      (var-set next-proposal-id (+ proposal-id u1))
      (var-set total-proposals (+ (var-get total-proposals) u1))
      
      ;; Take snapshot of proposers voting power
      (snapshot-voting-power proposer block-height)
      
      ;; Emit proposal event
      (print (tuple 
        (event "proposal-created")
        (proposal-id proposal-id)
        (proposer proposer)
        (title title)
        (start-block (+ block-height (var-get voting-delay)))
        (end-block (+ block-height (var-get voting-delay) (var-get voting-period))))))
      
      (ok proposal-id)))

;; Specialized parameter change proposal
(define-public (propose-parameter-change
  (parameter-name (string-ascii 50))
  (target-contract principal)
  (new-value uint)
  (title (string-ascii 100))
  (description (string-utf8 500)))
  (let ((proposal-id (try! (propose title description PROPOSAL_TYPE_PARAMETER (some target-contract) none (some (list new-value))))))
    
    ;; Store parameter details
    (map-set parameter-proposals proposal-id
      {
        parameter-name: parameter-name,
        current-value: u0, ;; Would fetch from target contract
        proposed-value: new-value,
        target-contract: target-contract
      })
    
    (ok proposal-id)))

;; Treasury spending proposal
;; @desc Proposes a treasury spending action.
;; @param recipient The principal address to receive the funds.
;; @param amount The amount of tokens to be transferred.
;; @param token The principal address of the token contract.
;; @param purpose A description of the purpose for the spending.
;; @return (response uint uint) A response tuple indicating success or failure, with the proposal ID on success.
(define-public (propose-treasury-spending
  (recipient principal)
  (amount uint)
  (token principal)
  (purpose (string-utf8 200)))
  ;; Keep description within ascii 9 if required elsewhere; store purpose separately
  (let ((title "Treasury Spending Proposal")
        (description u"Transfer")))
    (let ((proposal-id (try! (propose title description PROPOSAL_TYPE_TREASURY none none none))))
      
      ;; Store treasury details
      (map-set treasury-proposals proposal-id
        {
          recipient: recipient,
          amount: amount,
          token: token,
          purpose: purpose
        })
      
      (ok proposal-id)))

;; Vote on a proposal
;; @desc Allows a user to cast a vote on an active proposal.
;; @param proposal-id The ID of the proposal to vote on.
;; @param support A uint representing the vote: u1 for 'for', u0 for 'against', u2 for 'abstain'.
;; @param reason An optional string providing a reason for the vote.
;; @return (response uint uint) A response tuple indicating success or failure, with the voting power used on success.
(define-public (vote (proposal-id uint) (support uint) (reason (optional (string-utf8 200))))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
        (voter tx-sender)
        (current-block block-height)))
    
    (begin
      ;; Check proposal is active
      (asserts! (>= current-block (get start-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
      (asserts! (<= current-block (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
      (asserts! (is-eq (get state proposal) PROPOSAL_ACTIVE) ERR_PROPOSAL_NOT_ACTIVE)
      
      ;; Check hasnt already voted
      (asserts! (is-none (map-get? vote-receipts { proposal-id: proposal-id, voter: voter })) ERR_ALREADY_VOTED)
      
      ;; Get voting power at proposal start
      (let ((voting-power (get-voting-power-at voter (get start-block proposal))))
        
        (asserts! (> voting-power u0) ERR_INSUFFICIENT_VOTING_POWER)
        
        ;; Record vote
        (map-set vote-receipts
          { proposal-id: proposal-id, voter: voter }
          { support: support, votes: voting-power, reason: reason })
        
        ;; Update vote tallies
        (let ((updated-proposal 
               (if (is-eq support u1) ;; FOR
                 (merge proposal { for-votes: (+ (get for-votes proposal) voting-power) })
                 (if (is-eq support u0) ;; AGAINST
                   (merge proposal { against-votes: (+ (get against-votes proposal) voting-power) })
                   ;; ABSTAIN
                   (merge proposal { abstain-votes: (+ (get abstain-votes proposal) voting-power) }))))))
          
          (map-set proposals proposal-id updated-proposal)
          
          ;; Emit vote event
          (print (tuple 
            (event "vote-cast")
            (proposal-id proposal-id)
            (voter voter)
            (support support)
            (votes voting-power)
            (reason reason))))
          
          (ok voting-power)))

;; Queue a successful proposal for execution
;; @desc Queues a successful proposal for execution after a defined timelock.
;; @param proposal-id The ID of the proposal to queue.
;; @return (response uint uint) A response tuple indicating success or failure, with the block number when the proposal will be queued on success.
(define-public (queue-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))))
    
    (begin
      ;; Check proposal has ended and succeeded
      (asserts! (> block-height (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
      
      ;; Check if proposal passed
      (let ((total-votes (+ (+ (get for-votes proposal) (get against-votes proposal)) (get abstain-votes proposal)))
            (quorum-met (>= total-votes (var-get quorum-threshold)))
            (majority-for (> (get for-votes proposal) (get against-votes proposal)))))
        
        (asserts! (and quorum-met majority-for) ERR_PROPOSAL_NOT_PASSED)
        
        ;; Queue proposal
        (let ((queue-block (+ block-height (var-get execution-delay)))))
          (map-set proposals proposal-id
            (merge proposal 
              { state: PROPOSAL_QUEUED, queue-block: (some queue-block) }))
          
          (print (tuple 
            (event "proposal-queued")
            (proposal-id proposal-id)
            (queue-block queue-block))))
          
          (ok queue-block))

;; Execute a queued proposal
;; @desc Executes a queued proposal.
;; @param proposal-id The ID of the proposal to execute.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))))
    
    (begin
      ;; Check proposal is queued and ready
      (asserts! (is-eq (get state proposal) PROPOSAL_QUEUED) ERR_PROPOSAL_NOT_ACTIVE)
      (asserts! (>= block-height (unwrap! (get queue-block proposal) ERR_PROPOSAL_NOT_ACTIVE)) ERR_PROPOSAL_NOT_ACTIVE)
      
      ;; Execute based on proposal type
      (let ((execution-result 
             (if (is-eq (get proposal-type proposal) PROPOSAL_TYPE_PARAMETER)
               (execute-parameter-change proposal-id)
               (if (is-eq (get proposal-type proposal) PROPOSAL_TYPE_TREASURY)
                 (execute-treasury-proposal proposal-id)
                 (ok true)))))) ;; Generic execution
        
        ;; Unwrap result or fail
        (let ((executed (unwrap! execution-result ERR_EXECUTION_FAILED))))
          (map-set proposals proposal-id
            (merge proposal { state: PROPOSAL_EXECUTED, execution-block: (some block-height) }))
          
          (print (tuple 
            (event "proposal-executed")
            (proposal-id proposal-id)
            (execution-block block-height))))
          
          (ok true))

;; @desc Executes a parameter change proposal.
;; @param proposal-id The ID of the parameter change proposal.
;; @param proposal A tuple containing the details of the proposal.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-private (execute-parameter-change (proposal-id uint) (proposal (tuple
    (proposer principal) (title (string-ascii 100)) (description (string-utf8 500))
    (proposal-type uint) (target-contract (optional principal)) (function-name (optional (string-ascii 50)))
    (parameters (optional (list 10 uint))) (for-votes uint) (against-votes uint) (abstain-votes uint)
    (start-block uint) (end-block uint) (queue-block (optional uint)) (execution-block (optional uint))
    (state uint) (created-at uint)))
  (let ((target-contract (unwrap! (get target-contract proposal) (err ERR_INVALID_PARAMETERS)))
        (function-name (unwrap! (get function-name proposal) (err ERR_INVALID_PARAMETERS)))
        (params (unwrap! (get parameters proposal) (err ERR_INVALID_PARAMETERS))))
    ;; This is a generic execution call. It is powerful and requires that the
    ;; target function has appropriate access control (i.e., only callable by this governance contract).
    (as-contract (contract-call? target-contract function-name params))))

;; @desc Executes a treasury spending proposal.
;; @param proposal-id The ID of the treasury spending proposal.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-private (execute-treasury-proposal (proposal-id uint))
  (let ((treasury-info (unwrap! (map-get? treasury-proposals proposal-id) ERR_INVALID_PARAMETERS)))
    (let ((token-contract (get token treasury-info))
          (amount (get amount treasury-info))
          (recipient (get recipient treasury-info)))
      ;; The governance contract itself acts as the treasury and calls the transfer.
      (as-contract (contract-call? token-contract transfer amount tx-sender recipient none)))))

;; === DELEGATION ===
;; Note: True delegation logic should be handled within the cxvg-utility contract
;; to keep vote-escrow logic self-contained. This function can be a placeholder
;; or a trigger if the utility contract requires it.
;; @desc Delegates voting power to another principal.
;; @param delegatee The principal address to delegate voting power to.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (delegate (delegatee principal))
  (let ((utility-contract (var-get cxvg-utility-contract))))
    ;; This call assumes the utility contract has a `delegate` function.
    ;; If not, this function is a NO-OP.
    (contract-call? utility-contract delegate delegatee)))

;; === VOTING POWER ===
;; @desc Retrieves the current voting power of a user.
;; @param user The principal address of the user.
;; @return (response uint uint) The voting power of the user.
(define-read-only (get-voting-power (user principal))
  (get-voting-power-at user block-height))

;; Fetches the voting power of a user at a specific block height
;; by calling the cxvg-utility contract.
;; @desc Fetches the voting power of a user at a specific block height.
;; @param user The principal address of the user.
;; @param at-height The block height at which to retrieve the voting power.
;; @return (response uint uint) The voting power of the user at the specified block height.
(define-read-only (get-voting-power-at (user principal) (at-height uint))
  (let ((utility-contract (var-get cxvg-utility-contract)))
    (unwrap-panic (contract-call? utility-contract get-voting-power-at user at-height))))

;; Takes a snapshot of a user\'s current voting power for a given block height.
;; This is crucial for proposals to use the voting power from when the proposal was created.
;; @desc Takes a snapshot of a user's current voting power for a given block height.
;; @param user The principal address of the user.
;; @param at-height The block height at which to take the snapshot.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-private (snapshot-voting-power (user principal) (at-height uint))
  (let ((voting-power (get-voting-power-at user at-height)))
    (map-set voting-power-snapshots { user: user, block-height: at-height } voting-power)
    (ok true)))

;; === ADMIN FUNCTIONS ===
;; @desc Updates the governance parameters of the protocol.
;; @param voting-delay The number of blocks before voting begins.
;; @param voting-period The number of blocks for which voting is open.
;; @param quorum-threshold The minimum total votes required for a proposal to pass.
;; @param proposal-threshold The minimum voting power required to create a proposal.
;; @param execution-delay The number of blocks a successful proposal is queued before execution.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (update-governance-params 
  (voting-delay uint) 
  (voting-period uint) 
  (quorum-threshold uint) 
  (proposal-threshold uint)
  (execution-delay uint))
  (begin
    (asserts! (or 
      (contract-call? .access-control has-role (as-contract tx-sender) ROLE_GOVERNOR)
      (contract-call? .access-control has-role (as-contract tx-sender) ROLE_GUARDIAN)
    ) ERR_UNAUTHORIZED)
    
    (asserts! (>= voting-delay u144) (err u8009)) ;; At least 1 hour
    (asserts! (and (>= voting-period u144) (<= voting-period u20160)) (err u8010)) ;; 1 hour to 2 weeks
    (asserts! (and (>= quorum-threshold u10000000000000000) (<= quorum-threshold u1000000000000000000)) (err u8011)) ;; 1% to 100%
    (asserts! (>= proposal-threshold u1000000000000000000) (err u8012)) ;; At least 1 token
    (asserts! (and (>= execution-delay u144) (<= execution-delay u20160)) (err u8013)) ;; 1 hour to 2 weeks
    
    (var-set voting-delay voting-delay)
    (var-set voting-period voting-period)
    (var-set quorum-threshold quorum-threshold)
    (var-set proposal-threshold proposal-threshold)
    (var-set execution-delay execution-delay)
    (ok true))

;; @desc Initializes the governance contract with the governance token and timelock address.
;; @param gov-token The principal address of the governance token.
;; @param timelock The principal address of the timelock contract.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (initialize (gov-token principal) (timelock principal))
  (begin
    (asserts! (contract-call? .access-control has-role (as-contract tx-sender) ROLE_GOVERNOR) ERR_UNAUTHORIZED)
    (var-set governance-token gov-token)
    (var-set timelock-address (some timelock))
    (ok true)))

;; @desc Cancels an active or pending proposal.
;; @param proposal-id The ID of the proposal to cancel.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (cancel-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))))
    (begin
      ;; Only proposer or admin can cancel
      (asserts! (or 
        (is-eq tx-sender (get proposer proposal)) 
        (contract-call? .access-control has-role ROLE_GOVERNOR (as-contract tx-sender))
      ) ERR_UNAUTHORIZED)
      
      ;; Can only cancel pending or active proposals
      (asserts! (or (is-eq (get state proposal) PROPOSAL_PENDING)
                    (is-eq (get state proposal) PROPOSAL_ACTIVE)) ERR_PROPOSAL_NOT_ACTIVE)
      
      (map-set proposals proposal-id
        (merge proposal { state: PROPOSAL_CANCELLED }))
      
      (print (tuple
        (event "proposal-cancelled")
        (proposal-id proposal-id)))
      
      (ok true)))

;; Emergency functions
;; @desc Allows a guardian to emergency cancel a proposal.
;; @param proposal-id The ID of the proposal to emergency cancel.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (emergency-cancel (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))))
    (asserts! (contract-call? .access-control has-role ROLE_GUARDIAN tx-sender) ERR_UNAUTHORIZED)
    (map-set proposals proposal-id (merge proposal {
      state: PROPOSAL_CANCELLED
    }))
    (ok true)))

;; @desc Allows a guardian to emergency execute a function on a target contract.
;; @param target-contract The principal address of the target contract.
;; @param function-name The name of the function to execute.
;; @return (response bool bool) A response tuple indicating success or failure.
(define-public (emergency-execute (target-contract principal) (function-name (string-ascii 50)))
  (begin
    (asserts! (contract-call? .access-control has-role ROLE_GUARDIAN tx-sender) ERR_UNAUTHORIZED)
    ;; Emergency execution without governance - should be very restricted
    (ok true)))

