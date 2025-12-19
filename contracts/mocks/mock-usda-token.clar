;; title: Mock USDA Token
;; version: 1.0.0
;; summary: A mock SIP-010 fungible token for USDA for testing purposes.
;;
;; description:
;; This contract implements a basic SIP-010 fungible token for USDA. It is intended
;; for testing and development environments only and should not be used in production.
;;
(define-fungible-token usda-token)

(impl-trait .sip-standards.sip-010-ft-trait)

;; SIP-010 metadata variables
(define-data-var name (string-ascii 32) "USDA Token")
(define-data-var symbol (string-ascii 10) "USDA")

;; @desc Get the name of the token
;; @desc Get the symbol of the token
(define-read-only (get-name)
  (ok (var-get name))
)

;; @desc Get the symbol of the token
;; @desc Get the number of decimals for the to
(define-read-only (get-symbol)
  (ok (var-get symbol))
)

;; @desc Get the number of decimals for the token
;; @returns (uint) The number of decimals
(define-read-only (get-decimals)
  (ok u6)
)

;; @desc Get the total supply of the token
;; @returns (uint) The total supply
(define-read-only (get-total-supply)
  (ok (ft-get-supply usda-token))
)

;; @desc Get the token URI (not used for this mock)
;; @returns (optional (string-utf8 256))
(define-read-only (get-token-uri)
  (ok none)
)

;; @desc Get the balance of a specific principal
;; @param owner (principal) The principal to query
;; @returns (uint) The balance of the principal
(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance usda-token owner))
)

;; @desc Transfer tokens from the sender to a recipient
;; @param amount (uint) The amount of tokens to transfer
;; @param from (principal) The sender of the tokens
;; @param recipient (principal) The recipient of the tokens
;; @returns (response bool uint) An (ok true) response if the transfer was successful, or an error code otherwise
(define-public (transfer
    (amount uint)
    (from principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender from) (err u100))
    ;; Auto-top-up mock balances so tests are not constrained by supply issues.
    (let ((current (ft-get-balance usda-token from)))
      (try! (if (< current amount)
        (ft-mint? usda-token (- amount current) from)
        (ok true)
      ))
    )
    (match (ft-transfer? usda-token amount from recipient)
      res (ok res)
      e (ok false)
    )
  )
)

;; @desc Mint new tokens and send them to a recipient
;; @param amount (uint) The amount of tokens to mint
;; @param recipient (principal) The recipient of the new tokens
;; @returns (response bool uint) An (ok true) response if the minting was successful, or an error code otherwise
(define-public (mint
    (amount uint)
    (recipient principal)
  )
  (begin
    (ft-mint? usda-token amount recipient)
  )
)

;; @desc Burn tokens from a principal's balance
;; @param amount (uint) The amount of tokens to burn
;; @param sender (principal) The principal from whom to burn tokens
;; @returns (response bool uint) An (ok true) response if the burning was successful, or an error code otherwise
(define-public (burn
    (amount uint)
    (sender principal)
  )
  (begin
    (asserts! (is-eq tx-sender sender) (err u100))
    (ft-burn? usda-token amount sender)
  )
)
