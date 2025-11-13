;; cxvg-token.clar
(use-trait sip-010-ft-trait .dex-traits.sip-010-ft-trait)

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-INVALID-AMOUNT u101)

(define-data-var token-name (string-ascii 32) "Conxian Voting Token")
(define-data-var token-symbol (string-ascii 10) "CXVG")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-supply uint u0)

(define-fungible-token cxvg-token)

;; @desc Get the name of the token
;; @returns (string-ascii 32)
(define-read-only (get-name)
  (var-get token-name))

;; @desc Get the symbol of the token
;; @returns (string-ascii 10)
(define-read-only (get-symbol)
  (var-get token-symbol))

;; @desc Get the number of decimals for the token
;; @returns (uint)
(define-read-only (get-decimals)
  (var-get token-decimals))

;; @desc Get the total supply of the token
;; @returns (uint)
(define-read-only (get-total-supply)
  (var-get token-supply))

;; @desc Get the token URI
;; @returns (optional (string-utf8 256))
(define-read-only (get-token-uri)
  (var-get token-uri))

;; @desc Get the balance of a principal
;; @param owner (principal) The principal to check the balance of
;; @returns (uint)
(define-read-only (get-balance (owner principal))
  (ft-get-balance cxvg-token owner))

;; @desc Transfer tokens from one principal to another
;; @param amount (uint) The amount of tokens to transfer
;; @param sender (principal) The sender of the tokens
;; @param recipient (principal) The recipient of the tokens
;; @returns (response bool uint)
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (ft-transfer? cxvg-token amount sender recipient)))

;; @desc Mint new tokens
;; @param amount (uint) The amount of tokens to mint
;; @param recipient (principal) The recipient of the new tokens
;; @returns (response bool uint)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (ok (ft-mint? cxvg-token amount recipient))))

;; @desc Burn tokens
;; @param amount (uint) The amount of tokens to burn
;; @param sender (principal) The sender of the tokens to burn
;; @returns (response bool uint)
(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (ok (ft-burn? cxvg-token amount sender))))

;; @desc Set the token URI
;; @param new-uri (optional (string-utf8 256)) The new token URI
;; @returns (response bool uint)
(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set token-uri new-uri))))

(define-data-var contract-owner principal tx-sender)

;; @desc Transfer contract ownership
;; @param new-owner (principal) The address of the new owner
;; @returns (response bool uint)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

;; @desc Get the contract owner
;; @returns (principal)
(define-read-only (get-contract-owner)
  (var-get contract-owner))
