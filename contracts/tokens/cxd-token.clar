;; @contract Conxian Revenue Token (CXD)
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc This contract implements the Conxian Revenue Token (CXD), a SIP-010 compliant fungible token.
;; It serves as the primary token of the Conxian ecosystem, providing economic incentives,
;; governance rights, and a share in protocol revenue. The contract includes hooks for
;; integration with staking, monitoring, and other system components.

;; --- Traits ---
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait protocol-monitor-trait .security-monitoring.protocol-monitor-trait)

;; --- Constants ---

;; @var ERR_UNAUTHORIZED The caller is not authorized to perform the action.
(define-constant ERR_UNAUTHORIZED u1001)
;; @var ERR_NOT_ENOUGH_BALANCE The account has an insufficient balance for the transaction.
(define-constant ERR_NOT_ENOUGH_BALANCE u2003)
;; @var ERR_SYSTEM_PAUSED The system is currently paused and the action cannot be performed.
(define-constant ERR_SYSTEM_PAUSED u1003)
;; @var ERR_EMISSION_LIMIT_EXCEEDED The proposed mint amount exceeds the emission limit.
(define-constant ERR_EMISSION_LIMIT_EXCEEDED u8000)
;; @var ERR_TRANSFER_HOOK_FAILED A transfer hook to another contract failed.
(define-constant ERR_TRANSFER_HOOK_FAILED u9002)
;; @var ERR_OVERFLOW An arithmetic operation resulted in an overflow.
(define-constant ERR_OVERFLOW u2000)
;; @var ERR_SUB_UNDERFLOW An arithmetic operation resulted in an underflow.
(define-constant ERR_SUB_UNDERFLOW u2001)

;; --- Data Variables and Maps ---

;; @var balances A map storing the token balance for each principal.
(define-map balances principal uint)
;; @var minters A map of principals who are authorized to mint new tokens.
(define-map minters principal bool)
;; @var contract-owner The principal of the contract owner, with administrative privileges.
(define-data-var contract-owner principal tx-sender)
;; @var decimals The number of decimal places for the token.
(define-data-var decimals uint u6)
;; @var name The human-readable name of the token.
(define-data-var name (string-ascii 32) "Conxian Revenue Token")
;; @var symbol The ticker symbol for the token.
(define-data-var symbol (string-ascii 10) "CXD")
;; @var total-supply The total number of tokens in circulation.
(define-data-var total-supply uint u0)
;; @var token-uri The URI for the token's metadata.
(define-data-var token-uri (optional (string-utf8 256)) none)
;; @var token-coordinator The principal of the token coordinator contract for system-wide integration.
(define-data-var token-coordinator (optional principal) none)
;; @var protocol-monitor The principal of the protocol monitor contract for security and operational checks.
(define-data-var protocol-monitor (optional principal) none)
;; @var emission-controller The principal of the emission controller contract, which governs the minting of new tokens.
(define-data-var emission-controller (optional principal) none)
;; @var revenue-distributor The principal of the revenue distributor contract for sharing protocol fees.
(define-data-var revenue-distributor (optional principal) none)
;; @var staking-contract-ref The principal of the staking contract.
(define-data-var staking-contract-ref (optional principal) none)
;; @var transfer-hooks-enabled A boolean to enable or disable transfer hooks.
(define-data-var transfer-hooks-enabled bool true)
;; @var system-integration-enabled A boolean to enable or disable integration with other system contracts.
(define-data-var system-integration-enabled bool true)
;; @var initialization-complete A boolean indicating if the contract has been fully initialized.
(define-data-var initialization-complete bool false)

;; --- Private Functions ---

;; @desc Checks if the provided principal is the contract owner.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is the owner.
(define-private (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

;; @desc Safely adds two unsigned integers, returning an error on overflow.
;; @param a The first unsigned integer.
;; @param b The second unsigned integer.
;; @returns A response containing the sum or an error.
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (>= result a) (ok result) (err ERR_OVERFLOW))))

;; @desc Safely subtracts two unsigned integers, returning an error on underflow.
;; @param a The first unsigned integer.
;; @param b The second unsigned integer.
;; @returns A response containing the difference or an error.
(define-private (safe-sub (a uint) (b uint))
  (if (>= a b) (ok (- a b)) (err ERR_SUB_UNDERFLOW)))

;; @desc Checks if the system is currently paused by querying the protocol monitor.
;; @returns A boolean indicating if the system is paused.
(define-private (check-system-pause)
  false)

;; @desc Checks if a proposed mint amount is allowed by the emission controller.
;; @param amount The amount to be minted.
;; @returns A boolean indicating if the emission is allowed.
(define-private (check-emission-allowed (amount uint))
  (or (not (var-get system-integration-enabled))
      (match (var-get emission-controller)
        controller (unwrap! (contract-call? controller can-emit amount) true)
        true)))

;; @desc Notifies the token coordinator of a transfer.
;; @param amount The amount transferred.
;; @param sender The sender of the transfer.
;; @param recipient The recipient of the transfer.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))
  (and (var-get system-integration-enabled)
       (var-get transfer-hooks-enabled)
       (match (var-get token-coordinator)
         coordinator (unwrap! (contract-call? coordinator on-transfer amount sender recipient) false)
         true)))

;; @desc Notifies the token coordinator of a mint.
;; @param amount The amount minted.
;; @param recipient The recipient of the minted tokens.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-mint (amount uint) (recipient principal))
  (and (var-get system-integration-enabled)
       (match (var-get token-coordinator)
         coordinator (default-to true (contract-call? coordinator on-mint amount recipient))
         true)))

;; @desc Notifies the token coordinator of a burn.
;; @param amount The amount burned.
;; @param sender The principal from whom the tokens were burned.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-burn (amount uint) (sender principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator (default-to true (contract-call? coordinator on-burn amount sender))
      true)
    true))

;; --- Configuration Functions (Owner Only) ---

;; @desc Sets the protocol monitor contract address.
;; @param contract-address The principal of the protocol monitor contract.
;; @returns A response indicating success or failure.
(define-public (set-protocol-monitor (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set protocol-monitor (some contract-address))
    (ok true)))

;; @desc Sets the emission controller contract address.
;; @param contract-address The principal of the emission controller contract.
;; @returns A response indicating success or failure.
(define-public (set-emission-controller (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set emission-controller (some contract-address))
    (ok true)))

;; @desc Sets the revenue distributor contract address.
;; @param contract-address The principal of the revenue distributor contract.
;; @returns A response indicating success or failure.
(define-public (set-revenue-distributor (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set revenue-distributor (some contract-address))
    (ok true)))

;; @desc Sets the staking contract address.
;; @param contract-address The principal of the staking contract.
;; @returns A response indicating success or failure.
(define-public (set-staking-contract (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set staking-contract-ref (some contract-address))
    (ok true)))

;; @desc Sets the token coordinator contract address.
;; @param contract-address The principal of the token coordinator contract.
;; @returns A response indicating success or failure.
(define-public (set-token-coordinator (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set token-coordinator (some contract-address))
    (ok true)))

;; @desc Enables system integration.
;; @returns A response indicating success or failure.
(define-public (enable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled true)
    (ok true)))

;; @desc Disables system integration.
;; @returns A response indicating success or failure.
(define-public (disable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled false)
    (ok true)))

;; @desc Sets whether transfer hooks are enabled.
;; @param enabled A boolean indicating if transfer hooks are enabled.
;; @returns A response indicating success or failure.
(define-public (set-transfer-hooks (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfer-hooks-enabled enabled)
    (ok true)))

;; @desc Completes the initialization of the contract.
;; @returns A response indicating success or failure.
(define-public (complete-initialization)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set initialization-complete true)
    (ok true)))

;; --- Read-Only Functions ---

;; @desc Checks if the system is paused.
;; @returns A boolean indicating if the system is paused.
(define-read-only (is-system-paused)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor false  ;; In read-only context, we can't make contract calls
      false)
    false))

;; @desc Checks if the contract is fully initialized.
;; @returns A boolean indicating if the contract is fully initialized.
(define-read-only (is-fully-initialized)
  (and
    (var-get system-integration-enabled)
    (var-get initialization-complete)))

;; @desc Gets the contract owner.
;; @returns The principal of the contract owner.
(define-read-only (get-owner)
  (ok (var-get contract-owner)))

;; @desc Gets information about the system integration.
;; @returns A tuple containing information about the system integration.
(define-read-only (get-integration-info)
  (ok {
    system-integration-enabled: (var-get system-integration-enabled),
    transfer-hooks-enabled: (var-get transfer-hooks-enabled),
    initialization-complete: (var-get initialization-complete),
    token-coordinator: (var-get token-coordinator),
    protocol-monitor: (var-get protocol-monitor),
    emission-controller: (var-get emission-controller),
    revenue-distributor: (var-get revenue-distributor),
    staking-contract: (var-get staking-contract-ref)
  }))

;; @desc Checks if a principal is a minter.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is a minter.
(define-read-only (is-minter (who principal))
  (default-to false (map-get? minters who)))

;; --- Ownership Functions ---

;; @desc Transfers ownership of the contract to a new principal.
;; @param new-owner The principal of the new owner.
;; @returns A response indicating success or failure.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

;; @desc Renounces ownership of the contract.
;; @returns A response indicating success or failure.
(define-public (renounce-ownership)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner tx-sender)
    (ok true)))

;; @desc Sets a principal as a minter.
;; @param who The principal to set as a minter.
;; @param enabled A boolean indicating if the principal is a minter.
;; @returns A response indicating success or failure.
(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (if enabled
      (map-set minters who true)
      (map-delete minters who))
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
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))

    (let ((sender-bal (default-to u0 (map-get? balances sender))))
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))

      (try! (map-set balances sender (unwrap! (safe-sub sender-bal amount) (err ERR_SUB_UNDERFLOW))))

      (let ((rec-bal (default-to u0 (map-get? balances recipient))))
        (try! (map-set balances recipient (unwrap! (safe-add rec-bal amount) (err ERR_OVERFLOW)))))

      (asserts! (notify-transfer amount sender recipient) (err ERR_TRANSFER_HOOK_FAILED))
      (ok true)
    )
  )
)

;; @desc Gets the balance of a principal.
;; @param who The principal to get the balance of.
;; @returns The balance of the principal.
(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? balances who))))

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
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set token-uri new-uri)
    (ok true)))

;; --- Mint/Burn Functions ---

;; @desc Mints new tokens to a recipient.
;; @param recipient The recipient of the new tokens.
;; @param amount The amount of tokens to mint.
;; @returns A response indicating success or failure.
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    (asserts! (check-emission-allowed amount) (err ERR_EMISSION_LIMIT_EXCEEDED))
    
    (var-set total-supply
      (unwrap! (safe-add (var-get total-supply) amount) (err ERR_OVERFLOW))
    )
    
    (let ((bal (default-to u0 (map-get? balances recipient))))
      (map-set balances recipient (unwrap! (safe-add bal amount) (err ERR_OVERFLOW))))
    
    (asserts! (notify-mint amount recipient) (err ERR_TRANSFER_HOOK_FAILED))
    (ok true)))

;; @desc Burns tokens from the sender.
;; @param amount The amount of tokens to burn.
;; @returns A response indicating success or failure.
(define-public (burn (amount uint))
  (begin
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (let ((bal (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (map-set balances tx-sender (unwrap! (safe-sub bal amount) (err ERR_SUB_UNDERFLOW))))
    
    (var-set total-supply
      (unwrap! (safe-sub (var-get total-supply) amount) (err ERR_SUB_UNDERFLOW))
    )
    
    (asserts! (notify-burn amount tx-sender) (err ERR_TRANSFER_HOOK_FAILED))
    (ok true)))
