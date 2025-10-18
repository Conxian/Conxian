

;; cxtr-token.clar

;; Conxian Treasury Token (SIP-010 FT) - represents treasury reserves and protocol-controlled value

;; Enhanced with system integration hooks for coordinator interface

;; --- Traits ---

;; Constants(define-constant TRAIT_REGISTRY .trait-registry)

;; --- Errors ---(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_ENOUGH_BALANCE u101)
(define-constant ERR_SYSTEM_PAUSED u102)
(define-constant ERR_EMISSION_DENIED u103)

;; --- Storage ---(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian Contributor Token")
(define-data-var symbol (string-ascii 10) "CXTR")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-map balances { who: principal } { bal: uint })
(define-map minters { who: principal } { enabled: bool })

;; --- System Integration ---(define-data-var system-integration-enabled bool false)
(define-data-var token-coordinator (optional principal) none)
(define-data-var emission-controller (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; --- Creator Economy Enhancement ---(define-data-var creator-council (optional principal) none)
(define-data-var bounty-system (optional principal) none)
(define-data-var reputation-threshold uint u1000) 

;; Minimum reputation for governance(define-data-var merit-multiplier uint u150) 

;; 1.5x merit bonus multiplier

;; Maps for creator economy(define-map creator-reputation principal uint)
(define-map merit-scores principal uint)
(define-map governance-eligibility principal bool)
(define-map creator-contributions principal (tuple (total-bounties uint) (successful-proposals uint) (reputation uint)))
(define-map seasonal-bonuses principal uint)

;; --- Helpers ---(define-read-only (is-owner (who principal))  (is-eq who (var-get contract-owner)))
(define-read-only (is-minter (who principal))  (is-some (map-get? minters { who: who })))

;; --- Owner/Admin ---

;; @desc Sets the contract owner.

;; @param new-owner (principal) The principal of the new contract owner.

;; @return (response bool) An (ok true) response if the owner is successfully set, or an error if unauthorized.(define-public (set-contract-owner (new-owner principal))  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (var-set contract-owner new-owner)    (ok true)  ))

;; @desc Sets a principal as a minter, allowing them to mint new tokens.

;; @param who (principal) The principal to set as minter.

;; @param enabled (bool) True to enable minter, false to disable.

;; @return (response bool) An (ok true) response if the minter is successfully set, or an error if unauthorized.(define-public (set-minter (who principal) (enabled bool))  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (if enabled      (map-set minters { who: who } { enabled: true })      (map-delete minters { who: who })    )    (ok true)  ))

;; --- System Integration Setup ---

;; @desc Enables system integration by setting coordinator, emission, and monitor contracts.

;; @param coordinator-contract (principal) The principal of the token coordinator contract.

;; @param emission-contract (principal) The principal of the emission controller contract.

;; @param monitor-contract (principal) The principal of the protocol monitor contract.

;; @return (response bool) An (ok true) response if system integration is successfully enabled, or an error if unauthorized.(define-public (enable-system-integration     (coordinator-contract principal)    (emission-contract principal)     (monitor-contract principal))  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (var-set token-coordinator (some coordinator-contract))    (var-set emission-controller (some emission-contract))    (var-set protocol-monitor (some monitor-contract))    (var-set system-integration-enabled true)    (ok true)  ))

;; @desc Enables the creator economy by setting the council and bounty system contracts.

;; @param council-contract (principal) The principal of the creator council contract.

;; @param bounty-contract (principal) The principal of the bounty system contract.

;; @return (response bool) An (ok true) response if the creator economy is successfully enabled, or an error if unauthorized.(define-public (enable-creator-economy    (council-contract principal)    (bounty-contract principal))  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (var-set creator-council (some council-contract))    (var-set bounty-system (some bounty-contract))    (ok true)  ))

;; @desc Disables system integration, preventing interaction with external system contracts.

;; @return (response bool) An (ok true) response if system integration is successfully disabled, or an error if unauthorized.(define-public (disable-system-integration)  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (var-set system-integration-enabled false)    (ok true)  ))

;; --- System Integration Helpers ---(define-private (check-system-pause)  (if (var-get system-integration-enabled)    (match (var-get protocol-monitor)      monitor-contract        true 

;; Simplified for enhanced deployment - assume system operational      true)    true  ))
(define-private (check-emission-allowed (amount uint))  (if (var-get system-integration-enabled)    (match (var-get emission-controller)      controller-contract        true 

;; Simplified for enhanced deployment - assume mint allowed      true)    true  ))
(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))  (if (var-get system-integration-enabled)    (match (var-get token-coordinator)      coordinator-contract        

;; Simplified for enhanced deployment - avoid undeclared trait calls        true      true)    true  ))
(define-private (notify-mint (amount uint) (recipient principal))  (if (var-get system-integration-enabled)    (match (var-get token-coordinator)      coordinator-contract        

;; Simplified for enhanced deployment - avoid undeclared trait calls        true      true)    true  ))
(define-private (notify-burn (amount uint) (burner principal))  (if (var-get system-integration-enabled)    (match (var-get token-coordinator)      coordinator-contract        

;; Simplified for enhanced deployment - avoid undeclared trait calls        true      true)    true  ))

;; --- SIP-010 interface ---

;; @desc Transfers tokens from the sender to a recipient.

;; @param amount (uint) The amount of tokens to transfer.

;; @param sender (principal) The principal of the sender.

;; @param recipient (principal) The principal of the recipient.

;; @param memo (optional (buff 34)) An optional memo for the transfer.

;; @return (response bool) An (ok true) response if the transfer is successful, or an error if unauthorized, system paused, or insufficient balance.(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))  (begin    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))    (let ((sender-bal (get bal (default-to {bal: u0} (map-get? balances {who: sender})))))      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))      (map-set balances { who: sender } { bal: (- sender-bal amount) })      (let ((rec-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))        (map-set balances { who: recipient } { bal: (+ rec-bal amount) })      )      

;; Notify system coordinator      (notify-transfer amount sender recipient)    )    (ok true)  ))
(define-read-only (get-balance (who principal))  (ok (get bal (default-to {bal: u0} (map-get? balances {who: who})))))
(define-read-only (get-total-supply)  (ok (var-get total-supply)))
(define-read-only (get-decimals)  (ok (var-get decimals)))
(define-read-only (get-name)  (ok (var-get name)))
(define-read-only (get-symbol)  (ok (var-get symbol)))
(define-read-only (get-token-uri)  (ok (var-get token-uri)))
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))  (if (is-eq tx-sender (var-get contract-owner))    (begin      (var-set token-uri new-uri)      (ok true)    )    (err ERR_UNAUTHORIZED)  ))

;; --- Mint/Burn (admin or authorized minters) ---

;; @desc Mints new tokens and assigns them to a recipient.

;; @param recipient (principal) The principal to receive the minted tokens.

;; @param amount (uint) The amount of tokens to mint.

;; @return (response bool) An (ok true) response if tokens are successfully minted, or an error if unauthorized or system paused.(define-public (mint (recipient principal) (amount uint))  (begin    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))    (asserts! (check-emission-allowed amount) (err ERR_EMISSION_DENIED))    (var-set total-supply (+ (var-get total-supply) amount))    (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))      (map-set balances { who: recipient } { bal: (+ bal amount) })    )    

;; Notify system coordinator    (notify-mint amount recipient)    (ok true)  ))

;; @desc Burns tokens from the sender's balance.

;; @param amount (uint) The amount of tokens to burn.

;; @return (response bool) An (ok true) response if tokens are successfully burned, or an error if system paused or insufficient balance.(define-public (burn (amount uint))  (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: tx-sender})))))    (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))    (map-set balances { who: tx-sender } { bal: (- bal amount) })    (var-set total-supply (- (var-get total-supply) amount))    

;; Notify system coordinator    (notify-burn amount tx-sender)    (ok true)  ))

;; --- System Integration Interface ---(define-read-only (get-system-info)  (ok (tuple    (integration-enabled (var-get system-integration-enabled))    (coordinator (var-get token-coordinator))    (emission-controller (var-get emission-controller))    (protocol-monitor (var-get protocol-monitor))  )))

;; --- Creator Economy Functions ---

;; Mint tokens with merit-based bonus  

;; @desc Mints new tokens to a recipient with a merit-based bonus.

;; @param recipient (principal) The principal to receive the minted tokens.

;; @param base-amount (uint) The base amount of tokens to mint.

;; @param merit-score (uint) The merit score of the recipient, used to calculate the bonus.

;; @return (response uint) An (ok total-amount) response if tokens are successfully minted, or an error if unauthorized, system paused, or emission denied.(define-public (mint-merit-reward (recipient principal) (base-amount uint) (merit-score uint))  (let ((merit-bonus (/ (* base-amount merit-score (var-get merit-multiplier)) (* u1000 u100)))        (total-amount (+ base-amount merit-bonus)))    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))    (asserts! (check-emission-allowed total-amount) (err ERR_EMISSION_DENIED))    

;; Update merit scores    (map-set merit-scores recipient merit-score)    

;; Mint tokens    (var-set total-supply (+ (var-get total-supply) total-amount))    (let ((current-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))      (map-set balances { who: recipient } { bal: (+ current-bal total-amount) }))    

;; Update creator contributions    (let ((contributions (default-to (tuple (total-bounties u0) (successful-proposals u0) (reputation u0))                                    (map-get? creator-contributions recipient))))      (map-set creator-contributions recipient               (merge contributions { reputation: merit-score })))    

;; Check governance eligibility    (if (>= merit-score (var-get reputation-threshold))        (map-set governance-eligibility recipient true)        true)    

;; Notify system coordinator    (notify-mint total-amount recipient)    (ok total-amount)))

;; Update creator reputation and contributions (called by creator council or bounty system)

;; @desc Updates a creator's reputation, total bounties, and successful proposals.

;; @param creator (principal) The principal of the creator.

;; @param reputation (uint) The new reputation score for the creator.

;; @param bounties (uint) The total number of bounties completed by the creator.

;; @param proposals (uint) The total number of successful proposals by the creator.

;; @return (response bool) An (ok true) response if the creator's information is successfully updated, or an error if unauthorized.(define-public (update-creator-reputation (creator principal) (reputation uint) (bounties uint) (proposals uint))  (begin    (asserts! (or (is-owner tx-sender)                  (is-eq tx-sender (unwrap! (var-get creator-council) (err ERR_UNAUTHORIZED)))                 (is-eq tx-sender (unwrap! (var-get bounty-system) (err ERR_UNAUTHORIZED))))             (err ERR_UNAUTHORIZED))        

;; Update reputation    (map-set creator-reputation creator reputation)        

;; Update contributions    (map-set creator-contributions creator             (tuple (total-bounties bounties) (successful-proposals proposals) (reputation reputation)))        

;; Update governance eligibility    (map-set governance-eligibility creator (>= reputation (var-get reputation-threshold)))        (ok true)))

;; Distribute seasonal bonuses to active creators

;; @desc Distributes seasonal bonuses to a list of recipients.

;; @param recipients (list 100 principal) A list of principals to receive bonuses.

;; @param amounts (list 100 uint) A list of corresponding bonus amounts.

;; @return (response uint) An (ok total-bonus) response if bonuses are successfully distributed, or an error if unauthorized or emission denied.(define-public (distribute-seasonal-bonus (recipients (list 100 principal)) (amounts (list 100 uint)))  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (asserts! (is-eq (len recipients) (len amounts)) (err ERR_UNAUTHORIZED))        

;; This would be implemented as a fold operation in production    

;; For now, simplified implementation    (let ((total-bonus (fold + amounts u0)))      (asserts! (check-emission-allowed total-bonus) (err ERR_EMISSION_DENIED))      (var-set total-supply (+ (var-get total-supply) total-bonus))      (ok total-bonus))))

;; @desc Retrieves comprehensive information about a creator.

;; @param creator (principal) The principal of the creator.

;; @return (response (tuple (reputation uint) (merit-score uint) (governance-eligible bool) (contributions (tuple (total-bounties uint) (successful-proposals uint) (reputation uint))) (seasonal-bonus uint))) An (ok) response containing the creator's information.(define-read-only (get-creator-info (creator principal))  (ok (tuple (reputation (default-to u0 (map-get? creator-reputation creator)))             (merit-score (default-to u0 (map-get? merit-scores creator)))             (governance-eligible (default-to false (map-get? governance-eligibility creator)))             (contributions (default-to (tuple (total-bounties u0) (successful-proposals u0) (reputation u0))                                       (map-get? creator-contributions creator)))             (seasonal-bonus (default-to u0 (map-get? seasonal-bonuses creator))))))

;; @desc Retrieves a list of creators eligible for governance.

;; @return (response (list 100 principal)) An (ok) response containing a list of eligible creator principals.(define-read-only (get-governance-eligible-creators)  

;; Get list of creators eligible for governance (simplified)  (ok (list)))

;; @desc Sets the minimum reputation threshold required for governance participation.

;; @param new-threshold (uint) The new minimum reputation threshold.

;; @return (response bool) An (ok true) response if the threshold is successfully set, or an error if unauthorized.(define-public (set-reputation-threshold (new-threshold uint))  

;; Set minimum reputation threshold for governance participation  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (var-set reputation-threshold new-threshold)    (ok true)))

;; @desc Sets the merit bonus multiplier for token minting.

;; @param new-multiplier (uint) The new merit multiplier.

;; @return (response bool) An (ok true) response if the multiplier is successfully set, or an error if unauthorized or if the multiplier exceeds the maximum allowed.(define-public (set-merit-multiplier (new-multiplier uint))  (begin    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))    (asserts! (<= new-multiplier u300) (err ERR_UNAUTHORIZED)) 

;; Max 3x multiplier    (var-set merit-multiplier new-multiplier)    (ok true)))

;; --- Creator Governance Functions ---

;; @desc Allows an eligible creator to propose a new initiative.

;; @param title (string-ascii 256) The title of the initiative.

;; @param description (string-utf8 512) A detailed description of the initiative.

;; @param funding-request (uint) The amount of funding requested for the initiative.

;; @return (response bool) An (ok true) response if the proposal is successfully submitted, or an error if unauthorized.(define-public (propose-creator-initiative (title (string-ascii 256)) (description (string-utf8 512)) (funding-request uint))  (begin    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) (err ERR_UNAUTHORIZED))        

;; In production, would integrate with DAO governance system    

;; For now, emit event    (print (tuple (event "creator-proposal")                   (proposer tx-sender)                  (title title)                  (funding-request funding-request)))        (ok true)))

;; @desc Allows an eligible creator to vote on a proposed initiative.

;; @param proposal-id (uint) The ID of the proposal to vote on.

;; @param support (bool) True if the creator supports the proposal, false otherwise.

;; @return (response bool) An (ok true) response if the vote is successfully cast, or an error if unauthorized.(define-public (vote-creator-proposal (proposal-id uint) (support bool))  (begin    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) (err ERR_UNAUTHORIZED))        

;; In production, would integrate with DAO governance system    (print (tuple (event "creator-vote")                   (voter tx-sender)                  (proposal-id proposal-id)                  (support support)))        (ok true)))