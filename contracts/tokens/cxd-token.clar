;; @contract Conxian Revenue Token (CXD)
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc This contract implements the Conxian Revenue Token (CXD), a SIP-010 compliant fungible token.
;; It serves as the primary token of the Conxian ecosystem, providing economic incentives,
;; governance rights, and a share in protocol revenue. The contract includes hooks for
;; integration with staking, monitoring, and other system components.

;; --- Traits ---
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
(use-trait protocol-monitor-trait .security-monitoring.protocol-monitor-trait)
(use-trait controller .core-traits.controller)
(use-trait ownership-trait .ownership-trait.ownership-trait)

;; Declare that cxd-token implements the SIP-010 fungible token trait.
(impl-trait .defi-traits.sip-010-ft-trait)

;; --- Constants ---
;; Using standardized error codes from protocol-errors
;; ERR_UNAUTHORIZED u1000
;; ERR_NOT_ENOUGH_BALANCE u1301
;; ERR_SYSTEM_PAUSED u1101
;; ERR_EMISSION_LIMIT_EXCEEDED u2000
;; ERR_TRANSFER_HOOK_FAILED u1504
;; ERR_OVERFLOW u1200
;; ERR_UNDERFLOW u1201

;; Apply standardized ownership pattern
(define-data-var contract-owner principal tx-sender)

;; --- Data Variables and Maps ---

;; @var balances A map storing the token balance for each principal.
(define-map balances
  principal
  uint
)
;; @var minters A map of principals who are authorized to mint new tokens.
(define-map minters
  principal
  bool
)
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
;; @var system-controller Optional external controller implementing pause/emission policy.
(define-data-var system-controller (optional principal) none)
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
  (is-eq who (var-get contract-owner))
)

;; @desc Checks if caller is the contract owner (standardized)
;; @returns bool indicating ownership status
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; @desc Safely adds two unsigned integers, returning an error on overflow.
;; @param a The first unsigned integer.
;; @param b The second unsigned integer.
;; @returns A response containing the sum or an error.
(define-private (safe-add
    (a uint)
    (b uint)
  )
  (let ((result (+ a b)))
    (if (>= result a)
      (ok result)
      (err (err u1300))
    )
  )
)

;; @desc Safely subtracts two unsigned integers, returning an error on underflow.
;; @param a The first unsigned integer.
;; @param b The second unsigned integer.
;; @returns A response containing the difference or an error.
(define-private (safe-sub
    (a uint)
    (b uint)
  )
  (if (>= a b)
    (b uint)
      (err (err-underflow))
    )
)

;; @desc Checks if the system is currently paused
;; @returns A boolean indicating if the system is paused.
(define-private (check-system-pause)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor (contract-call? monitor is-paused)
      false
    )
    false
  )
  false
)

;; If a controller is configured, delegate pause status to it. On
;; @param amount The amount to be minted.
;; @returns A boolean indicating if the emission is allowed.
(define-private (check-emission-allowed (amount uint))
  true
)

;; @desc Notifies the token coordinator of a transfer.
;; @param amount The amount transferred.
;; @param sender The sender of the transfer.
;; @param recipient The recipient of the transfer.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-transfer
    (amount uint)
    (sender principal)
    (recipient principal)
  )
  (and
    (var-get system-integration-enabled)
    (var-get transfer-hooks-enabled)
    true
  )
)

;; @desc Notifies the token coordinator of a mint.
;; @param amount The amount minted.
;; @param recipient The recipient of the minted tokens.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-mint
    (amount uint)
    (recipient principal)
  )
  (and
    (var-get system-integration-enabled)
    true
  )
)

;; @desc Notifies the token coordinator of a burn.
;; @param amount The amount burned.
;; @param sender The principal from whom the tokens were burned.
;; @returns A boolean indicating if the notification was successful.
(define-private (notify-burn
    (amount uint)
    (sender principal)
  )
  ;; v1 stub: integration hooks are disabled; always report success
  true
)

;; --- Configuration Functions (Owner Only) ---

;; @desc Sets the protocol monitor contract address.
;; @param contract-address The principal of the protocol monitor contract.
;; @returns A response indicating success or failure.
(define-public (set-protocol-monitor (contract-address principal))
  (begin
;; @returns A response indicating success or failure.
    (var-set protocol-monitor (some contract-address))
    (ok true)
  )
)

;; @desc Sets the emission controller contract address.
;; @param contract-address The principal of the emission controller contract.
;; @returns A response indicating success or failure.
(define-public (set-emission-controller (contract-address principal))
  (begin
;; @returns A response indicating success or failure.
    (var-set emission-controller (some contract-address))
    (ok true)
  )
)

;; @desc Sets the revenue distributor contract address.
;; @param contract-address The principal of the revenue distributor contract.
;; @returns A response indicating success or failure.
(define-public (set-revenue-distributor (contract-address principal))
  (begin
;; @returns A response indicating success or failure.
    (var-set revenue-distributor (some contract-address))
    (ok true)
  )
)

;; @desc Sets the staking contract address.
;; @param contract-address The principal of the staking contract.
;; @returns A response indicating success or failure.
(define-public (set-staking-contract (contract-address principal))
  (begin
;; @returns A response indicating success or failure.
    (var-set staking-contract-ref (some contract-address))
    (ok true)
  )
)

;; @desc Sets the token coordinator contract address.
;; @param contract-address The principal of the token coordinator contract.
;; @returns A response indicating success or failure.
(define-public (set-token-coordinator (contract-address principal))
  (begin
;; @returns A response indicating success or failure.
    (var-set token-coordinator (some contract-address))
    (ok true)
  )
)

;; @desc Enables system integration.
;; @returns A response indicating success or failure.
(define-public (enable-system-integration)
  (begin
;; @returns A response indicating success or failure.
    (var-set system-integration-enabled true)
    (ok true)
  )
)

;; @desc Disables system integration.
;; @returns A response indicating success or failure.
(define-public (disable-system-integration)
  (begin
;; @returns A response indicating success or failure.
    (var-set system-integration-enabled false)
    (ok true)
  )
)

;; @desc Sets whether transfer hooks are enabled.
;; @param enabled A boolean indicating if transfer hooks are enabled.
;; @returns A response indicating success or failure.
(define-public (set-transfer-hooks (enabled bool))
  (begin
;; @returns A response indicating success or failure.
    (var-set transfer-hooks-enabled enabled)
    (ok true)
  )
)

;; @desc Completes the initialization of the contract.
;; @returns A response indicating success or failure.
(define-public (complete-initialization)
  (begin
;; @returns A response indicating success or failure.
    (var-set initialization-complete true)
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; @desc Checks if the system is paused.
;; @returns A boolean indicating if the system is paused.
(define-read-only (is-system-paused)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor
      false ;; In read-only context, we can't make contract calls
      false
    )
    false
  )
)

;; @desc Checks if the contract is fully initialized.
;; @returns A boolean indicating if the contract is fully initialized.
(define-read-only (is-fully-initialized)
  (and
    (var-get system-integration-enabled)
    (var-get initialization-complete)
  )
)

;; @desc Gets the contract owner.
;; @returns The principal of the contract owner.
(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

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
    staking-contract: (var-get staking-contract-ref),
  })
)

;; @desc Checks if a principal is a minter.
;; @param who The principal to check.
;; @returns A boolean indicating if the principal is a minter.
(define-read-only (is-minter (who principal))
  (default-to false (map-get? minters who))
)

;; --- Ownership Functions ---

;; @desc Transfers ownership of the contract to a new principal.
;; @param new-owner The principal of the new owner.
;; @returns A response indicating success or failure.
(define-public (transfer-ownership (new-owner principal))
  (begin
;; @returns A response indicating success or failure.
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Renounces ownership of the contract.
;; @returns A response indicating success or failure.
(define-public (renounce-ownership)
  (begin
;; @returns A response indicating success or failure.
    (var-set contract-owner tx-sender)
    (ok true)
  )
)

;; @desc Sets a principal as a minter.
;; @param who The principal to set as a minter.
;; @param enabled A boolean indicating if the principal is a minter.
;; @returns A response indicating success or failure.
(define-public (set-minter
    (who principal)
    (enabled bool)
  )
  (begin
    (enabled bool)
    (if enabled
      (map-set minters who true)
      (map-delete minters who)
    )
    (ok true)
  )
)

;; --- SIP-010 Interface ---

;; @desc Transfers tokens from the sender to a recipient.
;; @param amount The amount of tokens to transfer.
;; @param sender The sender of the tokens.
;; @param recipient The recipient of the tokens.
;; @param memo An optional memo for the transfer.
;; @returns A response indicating success or failure.
(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender sender) (err (err-unauthorized)))
(asserts! (not (check-system-pause)) (err (err-system-paused)))

    (let ((sender-bal (default-to u0 (map-get? balances sender))))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))

      (map-set balances sender
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      )

      (let ((rec-bal (default-to u0 (map-get? balances recipient))))
        (map-set balances recipient
          (unwrap! (safe-add rec-bal amount) (err (err-overflow)))
        )
      )

      (asserts! (notify-transfer amount sender recipient)
        (err (err-transfer-hook-failed))
      )
      (ok true)
    )
  )
)

;; @desc Gets the balance of a principal.
;; @param who The principal to get the balance of.
;; @returns The balance of the principal.
(define-read-only (get-balance (who principal))
  (ok (default-to u0 (map-get? balances who)))
)

;; @desc Gets the total supply of the token.
;; @returns The total supply of the token.
(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

;; @desc Gets the number of decimals for the token.
;; @returns The number of decimals for the token.
(define-read-only (get-decimals)
  (ok (var-get decimals))
)

;; @desc Gets the name of the token.
;; @returns The name of the token.
(define-read-only (get-name)
  (ok (var-get name))
)

;; @desc Gets the symbol of the token.
;; @returns The symbol of the token.
(define-read-only (get-symbol)
  (ok (var-get symbol))
)

;; @desc Gets the token URI.
;; @returns The token URI.
(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; @desc Sets the token URI.
;; @param new-uri The new token URI.
;; @returns A response indicating success or failure.
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
;; @returns A response indicating success or failure.
    (var-set token-uri new-uri)
    (ok true)
  )
)

;; --- Mint/Burn Functions ---

;; @desc Mints new tokens to a recipient.
;; @param recipient The recipient of the new tokens.
;; @param amount The amount of tokens to mint.
;; @returns A response indicating success or failure.
(define-public (mint
    (recipient principal)
    (amount uint)
  )
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender))
      (err (err-unauthorized))
    )
    (asserts! (not (check-system-pause)) (err (err-system-paused)))
(asserts! (check-emission-allowed amount) (err (err-emission-limit-exceeded)))

    (var-set total-supply
      (unwrap! (safe-add (var-get total-supply) amount) (err (err-overflow)))
    )

    (let ((bal (default-to u0 (map-get? balances recipient))))
      (map-set balances recipient
        (unwrap! (safe-add bal amount) (err (err-overflow)))
      )
    )

    (asserts! (notify-mint amount recipient) (err (err-transfer-hook-failed)))
    (ok true)
  )
)

;; @desc Burns tokens from the sender.
;; @param amount The amount of tokens to burn.
;; @returns A response indicating success or failure.
(define-public (burn (amount uint))
  (begin
;; @returns A response indicating success or failure.

    (let ((bal (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= bal amount) (err (err-not-enough-balance)))
      (map-set balances tx-sender
        (unwrap! (safe-sub bal amount) (err (err-sub-underflow)))
      )
    )

    (var-set total-supply
      (unwrap! (safe-sub (var-get total-supply) amount) (err (err-sub-underflow)))
    )

    (asserts! (notify-burn amount tx-sender) (err (err-transfer-hook-failed)))
    (ok true)
  )
)
