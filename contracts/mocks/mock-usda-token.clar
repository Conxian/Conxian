;; title: Mock USDA Token
;; version: 1.0.0
;; summary: A mock SIP-010 fungible token for USDA for testing purposes.
;;
;; description:
;; This contract implements a basic SIP-010 fungible token for USDA. It is intended
;; for testing and development environments only and should not be used in production.
;;
(define-fungible-token usda-token)

;; @desc Get the name of the token
;; @returns (string-ascii 10) The token name
(define-read-only (get-name)
  (ok "USDA"))

;; @desc Get the symbol of the token
;; @returns (string-ascii 4) The token symbol
(define-read-only (get-symbol)
  (ok "USDA"))

;; @desc Get the number of decimals for the token
;; @returns (uint) The number of decimals
(define-read-only (get-decimals)
  (ok u6))

;; @desc Get the total supply of the token
;; @returns (uint) The total supply
(define-read-only (get-total-supply)
  (ok (ft-get-supply usda-token)))

;; @desc Get the balance of a specific principal
;; @param owner (principal) The principal to query
;; @returns (uint) The balance of the principal
(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance usda-token owner)))

;; @desc Transfer tokens from the sender to a recipient
;; @param amount (uint) The amount of tokens to transfer
;; @param sender (principal) The sender of the tokens
;; @param recipient (principal) The recipient of the tokens
;; @returns (response bool uint) An (ok true) response if the transfer was successful, or an error code otherwise
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err u100))
    (ft-transfer? usda-token amount sender recipient)))

;; @desc Mint new tokens and send them to a recipient
;; @param amount (uint) The amount of tokens to mint
;; @param recipient (principal) The recipient of the new tokens
;; @returns (response bool uint) An (ok true) response if the minting was successful, or an error code otherwise
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender .deployer) (err u101))
    (ft-mint? usda-token amount recipient)))

;; @desc Burn tokens from a principal's balance
;; @param amount (uint) The amount of tokens to burn
;; @param sender (principal) The principal from whom to burn tokens
;; @returns (response bool uint) An (ok true) response if the burning was successful, or an error code otherwise
(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err u100))
    (ft-burn? usda-token amount sender)))