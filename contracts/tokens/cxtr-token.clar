;; @contract Conxian Treasury Token (CXTR)
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc This contract implements the Conxian Treasury Token (CXTR), a SIP-010 compliant fungible token.
;; It represents the protocol's treasury reserves and is used for funding development,
;; community initiatives, and other ecosystem-building activities.

;; --- Traits ---
(use-trait sip-010-ft-trait .01-sip-standards.sip-010-ft-trait)

;; --- Constants ---

;; @var TRAIT_REGISTRY The principal of the trait registry contract.
(define-constant TRAIT_REGISTRY .trait-registry)
;; @var ERR_UNAUTHORIZED The caller is not authorized to perform the action.
(define-constant ERR_UNAUTHORIZED u1001)
;; @var ERR_NOT_ENOUGH_BALANCE The account has an insufficient balance for the transaction.
(define-constant ERR_NOT_ENOUGH_BALANCE u2003)
;; @var ERR_SYSTEM_PAUSED The system is currently paused.
(define-constant ERR_SYSTEM_PAUSED u1003)
;; @var ERR_EMISSION_DENIED The proposed mint amount is denied.
(define-constant ERR_EMISSION_DENIED u8000)
;; @var ERR_INVALID_PARAMETERS The provided parameters are invalid.
(define-constant ERR_INVALID_PARAMETERS u1005)
;; @var ERR_LENGTH_MISMATCH The lengths of the provided lists do not match.
(define-constant ERR_LENGTH_MISMATCH u1005)

;; --- Data Variables and Maps ---

;; @var contract-owner The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @var total-supply The total supply of the token.
(define-data-var total-supply uint u0)
;; @var decimals The number of decimals for the token.
(define-data-var decimals uint u6)
;; @var name The name of the token.
(define-data-var name (string-ascii 32) "Conxian Contributor Token")
;; @var symbol The symbol of the token.
(define-data-var symbol (string-ascii 10) "CXTR")
;; @var token-uri The URI for the token's metadata.
(define-data-var token-uri (optional (string-utf8 256)) none)
;; @var balances A map of principal balances.
(define-map balances {who: principal} {bal: uint})
;; @var minters A map of principals authorized to mint tokens.
(define-map minters {who: principal} {enabled: bool})
;; @var system-integration-enabled A boolean indicating if system integration is enabled.
(define-data-var system-integration-enabled bool true)
;; @var token-coordinator The principal of the token coordinator contract.
(define-data-var token-coordinator (optional principal) none)
;; @var emission-controller The principal of the emission controller contract.
(define-data-var emission-controller (optional principal) none)
;; @var protocol-monitor The principal of the protocol monitor contract.
(define-data-var protocol-monitor (optional principal) none)
;; @var creator-council The principal of the creator council contract.
(define-data-var creator-council (optional principal) none)
;; @var bounty-system The principal of the bounty system contract.
(define-data-var bounty-system (optional principal) none)
;; @var reputation-threshold The reputation threshold for governance eligibility.
(define-data-var reputation-threshold uint u1000)
;; @var merit-multiplier The multiplier for merit-based rewards.
(define-data-var merit-multiplier uint u150)
;; @var MAX_MERIT_MULTIPLIER The maximum merit multiplier.
(define-constant MAX_MERIT_MULTIPLIER u300)
;; @var creator-reputation A map of creator reputations.
(define-map creator-reputation principal uint)
;; @var merit-scores A map of creator merit scores.
(define-map merit-scores principal uint)
;; @var governance-eligibility A map indicating if a creator is eligible for governance.
(define-map governance-eligibility principal bool)
;; @var creator-contributions A map of creator contributions.
(define-map creator-contributions principal {total-bounties: uint, successful-proposals: uint, reputation: uint})
;; @var seasonal-bonuses A map of seasonal bonuses for creators.
(define-map seasonal-bonuses principal uint)

;; --- Private Functions ---

;; @desc Checks if the system is paused.
;; @returns A boolean indicating if the system is paused.
(define-private (check-system-pause)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor-contract (unwrap! (contract-call? monitor-contract is-paused) false)
      false)
    false))

;; @desc Checks if an emission is allowed.
;; @param amount The amount of the emission.
;; @returns A boolean indicating if the emission is allowed.
(define-private (check-emission-allowed (amount uint))
  (if (var-get system-integration-enabled)
    (match (var-get emission-controller)
      controller-contract (unwrap! (contract-call? controller-contract can-emit amount) true)
      true)
    true))

;; @desc Notifies the token coordinator of a transfer.
;; @param amount The amount of the transfer.
;; @param sender The sender of the transfer.
;; @param recipient The recipient of the transfer.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract (unwrap! (contract-call? coordinator-contract on-transfer amount sender recipient) false)
      true)
    true))

;; @desc Notifies the token coordinator of a mint.
;; @param amount The amount of the mint.
;; @param recipient The recipient of the mint.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-mint (amount uint) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract (unwrap! (contract-call? coordinator-contract on-mint amount recipient) true)
      true)
    true))

;; @desc Notifies the token coordinator of a burn.
;; @param amount The amount of the burn.
;; @param burner The burner of the tokens.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-burn (amount uint) (burner principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract (unwrap! (contract-call? coordinator-contract on-burn amount burner) true)
      true)
    true))

;; @desc Helper to sum uint values when folding lists.
(define-private (sum-uint
    (value uint)
    (acc uint)
  )
  (+ acc value)
)

;; @desc Applies a seasonal bonus to a single recipient while iterating through the list.
(define-private (apply-seasonal-bonus
    (recipient principal)
    (state {
      amounts: (list 100 uint),
      index: uint,
    })
  )
  (let (
      (bonus (unwrap! (element-at (get amounts state) (get index state))
        ERR_INVALID_PARAMETERS
      ))
      (current-bal (get bal (default-to { bal: u0 } (map-get? balances { who: recipient }))))
    )
    (map-set balances { who: recipient } { bal: (+ current-bal bonus) })
    (map-set seasonal-bonuses recipient bonus)
    {
      amounts: (get amounts state),
      index: (+ (get index state) u1),
    }
  )
)

;; --- Read-Only Functions ---

;; @desc Checks if a principal is the contract owner.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is the owner.
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

;; @desc Checks if a principal is a minter.

;; --- Read-Only Functions ---

;; @desc Checks if a principal is the contract owner.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is the owner.
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

;; @desc Checks if a principal is a minter.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is a minter.
(define-read-only (is-minter (who principal))
  (default-to false (get enabled (map-get? minters {who: who}))))

;; @desc Checks if a principal is an authorized system contract.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is an authorized system contract.
(define-read-only (is-authorized-system (who principal))
  (or (is-eq (some who) (var-get creator-council))
      (is-eq (some who) (var-get bounty-system))))

;; --- Admin Functions ---

;; @desc Sets the contract owner.
;; @param new-owner The new contract owner.
;; @returns A response indicating success or failure.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

;; @desc Sets a principal as a minter.
;; @param who The principal to set as a minter.
;; @param enabled `true` to enable, `false` to disable.
;; @returns A response indicating success or failure.
(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (map-set minters {who: who} {enabled: enabled})
    (ok true)))

;; @desc Enables system integration.
;; @param coordinator-contract The address of the token coordinator contract.
;; @param emission-contract The address of the emission controller contract.
;; @param monitor-contract The address of the protocol monitor contract.
;; @returns A response indicating success or failure.
(define-public (enable-system-integration
    (coordinator-contract principal)
    (emission-contract principal)
    (monitor-contract principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set token-coordinator (some coordinator-contract))
    (var-set emission-controller (some emission-contract))
    (var-set protocol-monitor (some monitor-contract))
    (var-set system-integration-enabled true)
    (ok true)))

;; @desc Enables the creator economy.
;; @param council-contract The address of the creator council contract.
;; @param bounty-contract The address of the bounty system contract.
;; @returns A response indicating success or failure.
(define-public (enable-creator-economy
    (council-contract principal)
    (bounty-contract principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set creator-council (some council-contract))
    (var-set bounty-system (some bounty-contract))
    (ok true)))

;; @desc Disables system integration.
;; @returns A response indicating success or failure.
(define-public (disable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set system-integration-enabled false)
    (ok true)))

;; --- SIP-010 Interface ---

;; @desc Transfers tokens from the sender to a recipient.
;; @param amount The amount of tokens to transfer.
;; @param sender The sender of the tokens.
;; @param recipient The recipient of the tokens.
;; @param memo An optional memo for the transfer.
;; @returns A response indicating success or failure.
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (not (check-system-pause)) ERR_SYSTEM_PAUSED)
    (let ((sender-bal (get bal (default-to {bal: u0} (map-get? balances {who: sender})))))
      (asserts! (>= sender-bal amount) ERR_NOT_ENOUGH_BALANCE)
      (try! (map-set balances {who: sender} {bal: (- sender-bal amount)}))
      (let ((rec-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
        (try! (map-set balances {who: recipient} {bal: (+ rec-bal amount)})))
      (asserts! (notify-transfer amount sender recipient) (err u0)))
    (ok true)))

;; @desc Gets the balance of a principal.
;; @param who The principal to get the balance of.
;; @returns The balance of the principal.
(define-read-only (get-balance (who principal))
  (ok (get bal (default-to {bal: u0} (map-get? balances {who: who})))))

;; @desc Gets the total supply of the token.
;; @returns The total supply of the token.
(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

;; @desc Gets the number of decimals for the token.
;; @returns The number of decimals for the token.
(define-read-only (get-decimals)
  (ok (var-get decimals)))

;; @desc Gets the name of the token.
;; @returns The name of the token.
(define-read-only (get-name)
  (ok (var-get name)))

;; @desc Gets the symbol of the token.
;; @returns The symbol of the token.
(define-read-only (get-symbol)
  (ok (var-get symbol)))

;; @desc Gets the token URI.
;; @returns The token URI.
(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

;; @desc Sets the token URI.
;; @param new-uri The new token URI.
;; @returns A response indicating success or failure.
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)))

;; --- Mint/Burn ---

;; @desc Mints new tokens to a recipient.
;; @param recipient The recipient of the new tokens.
;; @param amount The amount of tokens to mint.
;; @returns A response indicating success or failure.
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (check-system-pause)) ERR_SYSTEM_PAUSED)
    (asserts! (check-emission-allowed amount) ERR_EMISSION_DENIED)
    (try! (var-set total-supply (+ (var-get total-supply) amount)))
    (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
      (try! (map-set balances {who: recipient} {bal: (+ bal amount)})))
    (asserts! (notify-mint amount recipient) (err u0))
    (ok true)))

;; @desc Burns tokens from the sender.
;; @param amount The amount of tokens to burn.
;; @returns A response indicating success or failure.
(define-public (burn (amount uint))
  (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: tx-sender})))))
    (asserts! (>= bal amount) ERR_NOT_ENOUGH_BALANCE)
    (asserts! (not (check-system-pause)) ERR_SYSTEM_PAUSED)
    (try! (map-set balances {who: tx-sender} {bal: (- bal amount)}))
    (try! (var-set total-supply (- (var-get total-supply) amount)))
    (asserts! (notify-burn amount tx-sender) (err u0))
    (ok true)))

;; --- System Integration Interface ---

;; @desc Gets information about the system integration.
;; @returns A tuple containing information about the system integration.
(define-read-only (get-system-info)
  (ok {
    integration-enabled: (var-get system-integration-enabled),
    coordinator: (var-get token-coordinator),
    emission-controller: (var-get emission-controller),
    protocol-monitor: (var-get protocol-monitor)}))

;; --- Creator Economy Functions ---

;; @desc Mints a merit-based reward to a creator.
;; @param recipient The recipient of the reward.
;; @param base-amount The base amount of the reward.
;; @param merit-score The merit score of the creator.
;; @returns The total amount of the reward.
(define-public (mint-merit-reward (recipient principal) (base-amount uint) (merit-score uint))
  (let ((merit-bonus (/ (* base-amount merit-score (var-get merit-multiplier)) u100000))
        (total-amount (+ base-amount merit-bonus)))
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (check-system-pause)) ERR_SYSTEM_PAUSED)
    (asserts! (check-emission-allowed total-amount) ERR_EMISSION_DENIED)
    (map-set merit-scores recipient merit-score)
    (try! (var-set total-supply (+ (var-get total-supply) total-amount)))
    (let ((current-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
      (try! (map-set balances {who: recipient} {bal: (+ current-bal total-amount)})))
    (let ((contributions (default-to {total-bounties: u0, successful-proposals: u0, reputation: u0}
                                     (map-get? creator-contributions recipient))))
      (map-set creator-contributions recipient
               (merge contributions {reputation: merit-score})))
    (if (>= merit-score (var-get reputation-threshold))
        (map-set governance-eligibility recipient true)
        true)
    (asserts! (notify-mint total-amount recipient) (err u0))
    (ok total-amount)))

;; @desc Updates the reputation of a creator.
;; @param creator The creator to update.
;; @param reputation The new reputation.
;; @param bounties The new number of bounties.
;; @param proposals The new number of successful proposals.
;; @returns A response indicating success or failure.
(define-public (update-creator-reputation (creator principal) (reputation uint) (bounties uint) (proposals uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-authorized-system tx-sender)) ERR_UNAUTHORIZED)
    (map-set creator-reputation creator reputation)
    (map-set creator-contributions creator
             {total-bounties: bounties, successful-proposals: proposals, reputation: reputation})
    (map-set governance-eligibility creator (>= reputation (var-get reputation-threshold)))
    (ok true)))

;; @desc Distributes a seasonal bonus to creators.
;; @param recipients A list of recipient principals.
;; @param amounts A list of bonus amounts.
;; @returns The total amount of the bonuses.
(define-public (distribute-seasonal-bonus (recipients (list 100 principal)) (amounts (list 100 uint)))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len recipients) (len amounts)) ERR_LENGTH_MISMATCH)
    (let ((total-bonus (fold sum-uint amounts u0)))
      (asserts! (check-emission-allowed total-bonus) ERR_EMISSION_DENIED)
      (fold apply-seasonal-bonus recipients {
        amounts: amounts,
        index: u0,
      })
(var-set total-supply (+ (var-get total-supply) total-bonus))
      (ok total-bonus))))

;; @desc Gets information about a creator.
;; @param creator The principal of the creator.
;; @returns A tuple containing information about the creator.
(define-read-only (get-creator-info (creator principal))
  (ok {
    reputation: (default-to u0 (map-get? creator-reputation creator)),
    merit-score: (default-to u0 (map-get? merit-scores creator)),
    governance-eligible: (default-to false (map-get? governance-eligibility creator)),
    contributions: (default-to {total-bounties: u0, successful-proposals: u0, reputation: u0}
                              (map-get? creator-contributions creator)),
    seasonal-bonus: (default-to u0 (map-get? seasonal-bonuses creator))}))

;; @desc Gets a list of governance-eligible creators.
;; @returns A list of governance-eligible creators.
(define-read-only (get-governance-eligible-creators)
  (ok (list)))

;; @desc Sets the reputation threshold for governance eligibility.
;; @param new-threshold The new reputation threshold.
;; @returns A response indicating success or failure.
(define-public (set-reputation-threshold (new-threshold uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set reputation-threshold new-threshold)
    (ok true)))

;; @desc Sets the merit multiplier for merit-based rewards.
;; @param new-multiplier The new merit multiplier.
;; @returns A response indicating success or failure.
(define-public (set-merit-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= new-multiplier MAX_MERIT_MULTIPLIER) ERR_INVALID_PARAMETERS)
    (var-set merit-multiplier new-multiplier)
    (ok true)))

;; --- Creator Governance Functions ---

;; @desc Proposes a creator initiative.
;; @param title The title of the proposal.
;; @param description A description of the proposal.
;; @param funding-request The amount of funding requested.
;; @returns A response indicating success or failure.
(define-public (propose-creator-initiative (title (string-ascii 256)) (description (string-utf8 512)) (funding-request uint))
  (begin
    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) ERR_UNAUTHORIZED)
    (print {event: "creator-proposal", proposer: tx-sender, title: title, funding-request: funding-request})
    (ok true)))

;; @desc Votes on a creator proposal.
;; @param proposal-id The ID of the proposal.
;; @param support `true` to support, `false` to oppose.
;; @returns A response indicating success or failure.
(define-public (vote-creator-proposal (proposal-id uint) (support bool))
  (begin
    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) ERR_UNAUTHORIZED)
    (print {event: "creator-vote", voter: tx-sender, proposal-id: proposal-id, support: support})
    (ok true)))
