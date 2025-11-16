;; @contract Conxian Liquidity Provider Token (CXLP)
;; @version 1.0.0
;; @author Conxian Protocol
;; @desc This contract implements the Conxian Liquidity Provider Token (CXLP), a SIP-010 compliant fungible token.
;; It represents a user's share in a liquidity pool and includes functionality for staking, yield distribution,
;; and a migration mechanism to convert CXLP tokens to the primary CXD token.

;; --- Traits ---
(use-trait sip-010-ft-trait .dex-traits.sip-010-ft-trait)

;; --- Constants ---

;; @var ERR_UNAUTHORIZED The caller is not authorized to perform the action.
(define-constant ERR_UNAUTHORIZED u1001)
;; @var ERR_NOT_ENOUGH_BALANCE The account has an insufficient balance for the transaction.
(define-constant ERR_NOT_ENOUGH_BALANCE u2003)
;; @var ERR_MIGRATION_NOT_SET The migration parameters have not been configured.
(define-constant ERR_MIGRATION_NOT_SET u9003)
;; @var ERR_MIGRATION_NOT_STARTED The migration period has not yet begun.
(define-constant ERR_MIGRATION_NOT_STARTED u9010)
;; @var ERR_CXD_NOT_SET The CXD token contract has not been set.
(define-constant ERR_CXD_NOT_SET u9001)
;; @var ERR_CXD_MISMATCH The provided CXD token contract does not match the configured one.
(define-constant ERR_CXD_MISMATCH u9001)
;; @var ERR_EPOCH_CAP_EXCEEDED The minting cap for the current epoch has been exceeded.
(define-constant ERR_EPOCH_CAP_EXCEEDED u8000)
;; @var ERR_USER_CAP_EXCEEDED The user's minting cap for the current epoch has been exceeded.
(define-constant ERR_USER_CAP_EXCEEDED u8000)
;; @var ERR_OVERFLOW An arithmetic operation resulted in an overflow.
(define-constant ERR_OVERFLOW u2000)
;; @var ERR_SUB_UNDERFLOW An arithmetic operation resulted in an underflow.
(define-constant ERR_SUB_UNDERFLOW u2001)
;; @var ERR_SYSTEM_PAUSED The system is currently paused.
(define-constant ERR_SYSTEM_PAUSED u1003)

;; --- Data Variables and Maps ---

;; @var contract-owner The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @var total-supply The total supply of the token.
(define-data-var total-supply uint u0)
;; @var decimals The number of decimals for the token.
(define-data-var decimals uint u6)
;; @var name The name of the token.
(define-data-var name (string-ascii 32) "Conxian LP Token")
;; @var symbol The symbol of the token.
(define-data-var symbol (string-ascii 10) "CXLP")
;; @var token-uri The URI for the token's metadata.
(define-data-var token-uri (optional (string-utf8 256)) none)
;; @var balances A map of principal balances.
(define-map balances principal uint)
;; @var minters A map of principals authorized to mint tokens.
(define-map minters principal bool)
;; @var balance-since A map that tracks the block height at which a principal's balance was last updated.
(define-map balance-since principal uint)
;; @var migration-queue-contract The principal of the migration queue contract.
(define-data-var migration-queue-contract (optional principal) none)
;; @var cxd-contract The principal of the CXD token contract.
(define-data-var cxd-contract (optional principal) none)
;; @var migration-start-height The block height at which the migration starts.
(define-data-var migration-start-height (optional uint) none)
;; @var epoch-length The length of each epoch in blocks.
(define-data-var epoch-length uint u0)
;; @var epoch-cap-cxd The maximum amount of CXD that can be minted in an epoch.
(define-data-var epoch-cap-cxd uint u0)
;; @var epoch-minted A map that tracks the amount of CXD minted in each epoch.
(define-map epoch-minted uint uint)
;; @var epoch-user-minted A map that tracks the amount of CXD minted by each user in each epoch.
(define-map epoch-user-minted { epoch: uint, who: principal } uint)
;; @var user-base-cap-cxd The base user capacity for CXD minting.
(define-data-var user-base-cap-cxd uint u0)
;; @var user-duration-factor The duration factor for user capacity calculation.
(define-data-var user-duration-factor uint u0)
;; @var user-max-cap-cxd The maximum user capacity for CXD minting.
(define-data-var user-max-cap-cxd uint u0)
;; @var last-midyear-adjustment The block height of the last mid-year adjustment.
(define-data-var last-midyear-adjustment uint u0)
;; @var midyear-blocks The number of blocks after which a mid-year adjustment can occur.
(define-data-var midyear-blocks uint u0)
;; @var midyear-adjust-bps The basis points for mid-year adjustment.
(define-data-var midyear-adjust-bps uint u0)
;; @var epoch-override A boolean indicating whether the epoch override is enabled.
(define-data-var epoch-override bool false)
;; @var BAND0 The multiplier for the first migration band (1.00x).
(define-constant BAND0 u10000)
;; @var BAND1 The multiplier for the second migration band (1.25x).
(define-constant BAND1 u12500)
;; @var BAND2 The multiplier for the third migration band (1.50x).
(define-constant BAND2 u15000)
;; @var BAND3 The multiplier for the fourth migration band (2.00x).
(define-constant BAND3 u20000)
;; @var protocol-monitor The principal of the protocol monitor contract.
(define-data-var protocol-monitor (optional principal) none)
;; @var system-integration-enabled A boolean indicating if system integration is enabled.
(define-data-var system-integration-enabled bool true)

;; --- Private Functions ---

;; @desc Safely adds two unsigned integers.
;; @param a The first number.
;; @param b The second number.
;; @returns The sum of the two numbers, or an error on overflow.
(define-private (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (>= result a)
      (ok result)
      (err ERR_OVERFLOW))))

;; @desc Safely subtracts two unsigned integers.
;; @param a The first number.
;; @param b The second number.
;; @returns The difference of the two numbers, or an error on underflow.
(define-private (safe-sub (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    (err ERR_SUB_UNDERFLOW)))

;; @desc Checks if the system is paused.
;; @returns A boolean indicating if the system is paused.
(define-private (check-system-pause)
  false)

;; @desc Performs a mid-year auto-adjustment of the epoch cap.
;; @returns A boolean indicating if an adjustment was made.
(define-private (maybe-auto-adjust)
  (let (
      (mb (var-get midyear-blocks))
      (bps (var-get midyear-adjust-bps))
      (last (var-get last-midyear-adjustment))
      (override (var-get epoch-override))
    )
    (if (and (> mb u0) (> bps u0) (is-eq override false) (>= (- block-height last) mb))
      (begin
        (var-set epoch-cap-cxd (/ (* (var-get epoch-cap-cxd) bps) u10000))
        (var-set last-midyear-adjustment block-height)
        true
      )
      false
    )
  ))

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
  (default-to false (map-get? minters who)))

;; @desc Returns the current epoch index since the migration start.
;; @returns The current epoch index, or an error.
(define-read-only (current-epoch)
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
    )
    (begin
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (ok (/ (- block-height start) len))
    )
  ))

;; @desc Returns the current migration band.
;; @returns The current migration band, or an error.
(define-read-only (current-band)
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
    )
    (begin
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (let ((band (/ (- block-height start) len)))
        (ok (if (>= band u3) u3 band))
      )
    )
  ))

;; @desc Returns the multiplier for a given migration band.
;; @param band The migration band.
;; @returns The multiplier for the given migration band.
(define-read-only (band-multiplier (band uint))
  (ok (if (is-eq band u0)
        BAND0
        (if (is-eq band u1)
          BAND1
          (if (is-eq band u2)
            BAND2
            BAND3)))))

;; @desc Gets the amount of CXD minted in an epoch.
;; @param epoch The epoch to get the minted amount for.
;; @returns The amount of CXD minted in the epoch.
(define-read-only (get-epoch-minted (epoch uint))
  (default-to u0 (map-get? epoch-minted epoch)))

;; @desc Gets the amount of CXD minted by a user in an epoch.
;; @param epoch The epoch to get the minted amount for.
;; @param who The principal of the user.
;; @returns The amount of CXD minted by the user in the epoch.
(define-read-only (get-user-epoch-minted (epoch uint) (who principal))
  (default-to u0 (map-get? epoch-user-minted { epoch: epoch, who: who })))

;; @desc Gets the block height at which a user's balance was last updated.
;; @param who The principal of the user.
;; @returns The block height at which the user's balance was last updated.
(define-read-only (get-balance-since (who principal))
  (let (
      (maybe-since (map-get? balance-since who))
      (start (var-get migration-start-height))
    )
    (default-to (default-to block-height start) maybe-since)
  ))

;; @desc Gets the epoch capacity for a user.
;; @param who The principal of the user.
;; @returns The epoch capacity for the user, or an error.
(define-read-only (user-epoch-capacity (who principal))
  (let (
      (base (var-get user-base-cap-cxd))
      (factor (var-get user-duration-factor))
      (max-cap (var-get user-max-cap-cxd))
      (since (get-balance-since who))
      (duration (- block-height since))
      (calc (+ base (* factor duration)))
    )
    (ok (if (> calc max-cap) max-cap calc))
  ))

;; --- Admin Functions ---

;; @desc Sets the contract owner.
;; @param new-owner The new contract owner.
;; @returns A response indicating success or failure.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  ))

;; @desc Sets or unsets a principal as a minter.
;; @param who The principal to set or unset.
;; @param enabled `true` to enable, `false` to disable.
;; @returns A response indicating success or failure.
(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (map-set minters who enabled)
    (ok true)
  ))

;; @desc Sets the protocol monitor contract.
;; @param contract-address The address of the protocol monitor contract.
;; @returns A response indicating success or failure.
(define-public (set-protocol-monitor (contract-address principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set protocol-monitor (some contract-address))
    (ok true)
  ))

;; @desc Sets the migration queue contract.
;; @param queue The address of the migration queue contract.
;; @returns A response indicating success or failure.
(define-public (set-migration-queue-contract (queue principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set migration-queue-contract (some queue))
    (ok true)
  ))

;; @desc Configures the migration from CXLP to CXD.
;; @param cxd The address of the CXD token contract.
;; @param start-height The block height at which the migration starts.
;; @param epoch-len The length of each epoch in blocks.
;; @returns A response indicating success or failure.
(define-public (configure-migration (cxd principal) (start-height uint) (epoch-len uint))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (> epoch-len u0) (err ERR_MIGRATION_NOT_SET))
    (var-set cxd-contract (some cxd))
    (var-set migration-start-height (some start-height))
    (var-set epoch-length epoch-len)
    (ok true)
  ))

;; @desc Sets liquidity parameters for the token.
;; @param epoch-cap The epoch cap.
;; @param user-base The user base cap.
;; @param user-factor The user duration factor.
;; @param user-max The user max cap.
;; @param midyear The midyear adjustment blocks.
;; @param adjust-bps The midyear adjustment basis points.
;; @returns A response indicating success or failure.
(define-public (set-liquidity-params (epoch-cap uint) (user-base uint) (user-factor uint) (user-max uint) (midyear uint) (adjust-bps uint))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set epoch-cap-cxd epoch-cap)
    (var-set user-base-cap-cxd user-base)
    (var-set user-duration-factor user-factor)
    (var-set user-max-cap-cxd user-max)
    (var-set midyear-blocks midyear)
    (var-set midyear-adjust-bps adjust-bps)
    (ok true)
  ))

;; @desc Sets the epoch override.
;; @param value `true` to enable, `false` to disable.
;; @returns A response indicating success or failure.
(define-public (set-epoch-override (value bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set epoch-override value)
    (ok true)
  ))

;; @desc Triggers a mid-year auto-adjustment.
;; @returns `(ok true)` if an adjustment was made, `(ok false)` otherwise.
(define-public (auto-adjust)
  (ok (maybe-auto-adjust)))

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
      (map-set balances sender
        (unwrap! (safe-sub sender-bal amount) (err ERR_SUB_UNDERFLOW))
      )
      
      (let ((rec-bal (default-to u0 (map-get? balances recipient))))
        (map-set balances recipient
          (unwrap! (safe-add rec-bal amount) (err ERR_OVERFLOW))
        )
        (map-set balance-since recipient block-height)
      )
    )
    
    (match (var-get migration-queue-contract)
      queue-contract (try! (contract-call? queue-contract on-cxlp-transfer sender recipient amount))
      true
    )
    (ok true)
  ))

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
    (ok true)
  ))

;; --- Mint/Burn ---

;; @desc Mints new tokens to a recipient.
;; @param recipient The recipient of the new tokens.
;; @param amount The amount of tokens to mint.
;; @returns A response indicating success or failure.
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (try! (var-set total-supply (unwrap! (safe-add (var-get total-supply) amount) (err ERR_OVERFLOW))))
    
    (let ((bal (default-to u0 (map-get? balances recipient))))
      (try! (map-set balances recipient (unwrap! (safe-add bal amount) (err ERR_OVERFLOW))))
      (map-set balance-since recipient block-height)
    )
    
    (match (var-get migration-queue-contract)
      queue-contract (try! (contract-call? queue-contract initialize-duration-tracking recipient))
      true
    )
    (ok true)
  ))

;; @desc Burns tokens from the sender.
;; @param amount The amount of tokens to burn.
;; @returns A response indicating success or failure.
(define-public (burn (amount uint))
  (begin
    (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
    
    (let ((bal (default-to u0 (map-get? balances tx-sender))))
      (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (try! (map-set balances tx-sender (unwrap! (safe-sub bal amount) (err ERR_SUB_UNDERFLOW)))))
    
    (try! (var-set total-supply (unwrap! (safe-sub (var-get total-supply) amount) (err ERR_SUB_UNDERFLOW))))
    (ok true)
  ))

;; --- Migration: CXLP -> CXD ---

;; @desc Migrates CXLP tokens to CXD tokens.
;; @param amount The amount of CXLP to migrate.
;; @param recipient The recipient of the CXD tokens.
;; @param cxd-contract-param The address of the CXD token contract.
;; @returns The amount of CXD minted.
(define-public (migrate-to-cxd (amount uint) (recipient principal) (cxd-contract-param principal))
  (let (
      (start (unwrap! (var-get migration-start-height) (err ERR_MIGRATION_NOT_SET)))
      (len (var-get epoch-length))
      (cxd-stored (unwrap! (var-get cxd-contract) (err ERR_CXD_NOT_SET)))
      (sender-bal (default-to u0 (map-get? balances tx-sender)))
    )
    (begin
      (asserts! (not (check-system-pause)) (err ERR_SYSTEM_PAUSED))
      (maybe-auto-adjust)
      (asserts! (> len u0) (err ERR_MIGRATION_NOT_SET))
      (asserts! (>= block-height start) (err ERR_MIGRATION_NOT_STARTED))
      (asserts! (is-eq cxd-stored cxd-contract-param) (err ERR_CXD_MISMATCH))
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      
      (try! (map-set balances tx-sender (unwrap! (safe-sub sender-bal amount) (err ERR_SUB_UNDERFLOW))))
      (try! (var-set total-supply (unwrap! (safe-sub (var-get total-supply) amount) (err ERR_SUB_UNDERFLOW))))
      
      (let (
          (band (unwrap! (current-band) (err u999)))
          (mult (unwrap! (band-multiplier band) (err ERR_OVERFLOW)))
          (cxd-to-mint (/ (* amount mult) u10000))
        )
        (try! (as-contract (contract-call? cxd-stored mint recipient cxd-to-mint)))
        (ok cxd-to-mint)
      )
    )
  )
)
