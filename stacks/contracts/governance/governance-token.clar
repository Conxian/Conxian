

;; governance-token.clar
;; Implements a SIP-010 fungible token for governance purposes with voting power

;; Traits
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(impl-trait .all-traits.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))

;; Data Variables
(define-data-var token-name (string-ascii 32) "ConxianGovernance")
(define-data-var token-symbol (string-ascii 10) "CXVG")
(define-data-var token-decimals uint u6)
(define-data-var token-supply uint u0)
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-data-var contract-owner principal tx-sender)
(define-data-var total-delegated uint u0)

;; Data Maps
(define-map token-balances
  { account: principal }
  { amount: uint })

(define-map voting-power
  { account: principal }
  { power: uint, last-update: uint })

(define-map delegations
  { delegator: principal, delegate: principal }
  { amount: uint })

;; SIP-010 Functions
(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (get-decimals)
  (ok (var-get token-decimals)))

(define-read-only (get-balance (account principal))
  (ok (default-to u0 (get amount (map-get? token-balances { account: account })))))

(define-read-only (get-total-supply)
  (ok (var-get token-supply)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (let (
      (sender-balance (unwrap! (get-balance sender) ERR_UNAUTHORIZED))
      (recipient-balance (unwrap! (get-balance recipient) ERR_UNAUTHORIZED))
    )
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_FUNDS)
      (map-set token-balances { account: sender } { amount: (- sender-balance amount) })
      (map-set token-balances { account: recipient } { amount: (+ recipient-balance amount) })

      ;; Update voting power
      (try! (update-voting-power sender))
      (try! (update-voting-power recipient))

      (print {
        event: "transfer",
        sender: sender,
        recipient: recipient,
        amount: amount
      })
      (ok true)
    )
  )
)

;; Governance Token Trait Functions
(define-read-only (get-voting-power (account principal))
  (let (
    (balance (unwrap! (get-balance account) (err ERR_UNAUTHORIZED)))
    (delegated-to-me (default-to u0 (get amount (map-get? delegated-amounts { account: account }))))
  )
    (ok (+ balance delegated-to-me))))

(define-read-only (has-voting-power (account principal))
  (let (
    (power (unwrap! (get-voting-power account) (err ERR_UNAUTHORIZED)))
  )
    (ok (> power u0))))

(define-read-only (get-total-voting-power)
  (ok (var-get token-supply)))

(define-public (delegate-voting-power (delegate principal) (amount uint))
  (let (
    (current-balance (unwrap! (get-balance tx-sender) ERR_UNAUTHORIZED))
    (current-delegation (default-to { delegate: tx-sender, amount: u0 } (map-get? delegations { owner: tx-sender })))
  )
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)

    ;; Update delegation record
    (map-set delegations { owner: tx-sender } { delegate: delegate, amount: amount })

    ;; Update delegated amounts
    (map-set delegated-amounts { account: delegate } { amount: (+ (default-to u0 (get amount (map-get? delegated-amounts { account: delegate }))) amount) })
    (map-set delegated-amounts { account: tx-sender } { amount: (- (default-to amount (get amount (map-get? delegated-amounts { account: tx-sender }))) amount) })

    ;; Update voting power
    (try! (update-voting-power tx-sender))
    (try! (update-voting-power delegate))
    (ok true)
  )
)

(define-public (undelegate-voting-power (amount uint))
  (let (
    (current-delegation (unwrap! (map-get? delegations { owner: tx-sender }) (err ERR_UNAUTHORIZED)))
    (delegate (get delegate current-delegation))
    (delegated-amount (get amount current-delegation))
  )
    (asserts! (>= delegated-amount amount) ERR_INSUFFICIENT_FUNDS)

    (if (> amount delegated-amount)
      ;; Undelegate all
      (begin
        (map-delete delegations { owner: tx-sender })
        (map-set delegated-amounts { account: delegate } { amount: (- (default-to u0 (get amount (map-get? delegated-amounts { account: delegate }))) delegated-amount) })
        (map-delete delegated-amounts { account: tx-sender })
      )
      ;; Partial undelegation
      (begin
        (map-set delegations { owner: tx-sender } { delegate: delegate, amount: (- delegated-amount amount) })
        (map-set delegated-amounts { account: delegate } { amount: (- (default-to u0 (get amount (map-get? delegated-amounts { account: delegate }))) amount) })
        (map-set delegated-amounts { account: tx-sender } { amount: (+ (default-to u0 (get amount (map-get? delegated-amounts { account: tx-sender }))) amount) })
      )
    )

    (try! (update-voting-power tx-sender))
    (try! (update-voting-power delegate))
    (ok true)
  )
)

;; Private helper functions
(define-private (update-voting-power (account principal))
  (let (
    (balance (unwrap! (get-balance account) (err ERR_UNAUTHORIZED)))
    (delegated-to-me (default-to u0 (get amount (map-get? delegated-amounts { account: account }))))
    (total-power (+ balance delegated-to-me))
  )
    (map-set voting-power { account: account } { power: total-power, last-update: block-height })
    (ok true)
  )
)

(define-private (get-delegated-to (account principal))
  (default-to u0 (get amount (map-get? delegated-amounts { account: account }))))

(define-private (get-delegated-from (account principal))
  (default-to u0 (get amount (map-get? delegations { owner: account }))))

;; Mint and Burn (for contract owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set token-supply (+ (var-get token-supply) amount))
    (map-set token-balances { account: recipient } { amount: (+ (unwrap! (get-balance recipient) (err u0)) amount) })
    (try! (update-voting-power recipient))
    (print { event: "mint", recipient: recipient, amount: amount })
    (ok true)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((owner-balance (unwrap! (get-balance owner) ERR_UNAUTHORIZED)))
      (asserts! (>= owner-balance amount) ERR_INSUFFICIENT_FUNDS)
      (var-set token-supply (- (var-get token-supply) amount))
      (map-set token-balances { account: owner } { amount: (- owner-balance amount) })
      (try! (update-voting-power owner))
      (print { event: "burn", owner: owner, amount: amount })
      (ok true)
    )
  )
)