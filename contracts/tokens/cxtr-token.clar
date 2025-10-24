;; cxtr-token.clar

;; Conxian Treasury Token (SIP-010 FT) - represents treasury reserves and protocol-controlled value
;; Enhanced with system integration hooks for coordinator interface

;; --- Traits ---

;; --- Constants ---
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait sip_010_ft_trait .all-traits.sip-010-ft-trait)
 .all-traits.sip-010-ft-trait)
(define-constant TRAIT_REGISTRY .trait-registry)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_ENOUGH_BALANCE (err u101))
(define-constant ERR_SYSTEM_PAUSED (err u102))
(define-constant ERR_EMISSION_DENIED (err u103))
(define-constant ERR_INVALID_PARAMETERS (err u104))
(define-constant ERR_LENGTH_MISMATCH (err u105))

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian Contributor Token")
(define-data-var symbol (string-ascii 10) "CXTR")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-map balances {who: principal} {bal: uint})
(define-map minters {who: principal} {enabled: bool})

;; --- System Integration ---
(define-data-var system-integration-enabled bool true)
(define-data-var token-coordinator (optional principal) none)
(define-data-var emission-controller (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; --- Creator Economy Enhancement ---
(define-data-var creator-council (optional principal) none)
(define-data-var bounty-system (optional principal) none)
(define-data-var reputation-threshold uint u1000)
(define-data-var merit-multiplier uint u150)
(define-constant MAX_MERIT_MULTIPLIER u300)

;; Maps for creator economy
(define-map creator-reputation principal uint)
(define-map merit-scores principal uint)
(define-map governance-eligibility principal bool)
(define-map creator-contributions principal {total-bounties: uint, successful-proposals: uint, reputation: uint})
(define-map seasonal-bonuses principal uint)

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner)))

(define-read-only (is-minter (who principal))
  (default-to false (get enabled (map-get? minters {who: who}))))

(define-read-only (is-authorized-system (who principal))
  (or (is-eq (some who) (var-get creator-council))
      (is-eq (some who) (var-get bounty-system))))

;; --- Owner/Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (map-set minters {who: who} {enabled: enabled})
    (ok true)))

;; --- System Integration Setup ---
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

(define-public (enable-creator-economy
    (council-contract principal)
    (bounty-contract principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set creator-council (some council-contract))
    (var-set bounty-system (some bounty-contract))
    (ok true)))

(define-public (disable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set system-integration-enabled false)
    (ok true)))

;; --- System Integration Helpers ---
(define-private (check-system-pause)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor-contract true
      true)
    true))

(define-private (check-emission-allowed (amount uint))
  (if (var-get system-integration-enabled)
    (match (var-get emission-controller)
      controller-contract true
      true)
    true))

(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract true
      true)
    true))

(define-private (notify-mint (amount uint) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract true
      true)
    true))

(define-private (notify-burn (amount uint) (burner principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract true
      true)
    true))

;; --- SIP-010 Interface ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (check-system-pause) ERR_SYSTEM_PAUSED)
    (let ((sender-bal (get bal (default-to {bal: u0} (map-get? balances {who: sender})))))
      (asserts! (>= sender-bal amount) ERR_NOT_ENOUGH_BALANCE)
      (map-set balances {who: sender} {bal: (- sender-bal amount)})
      (let ((rec-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
        (map-set balances {who: recipient} {bal: (+ rec-bal amount)}))
      (notify-transfer amount sender recipient))
    (ok true)))

(define-read-only (get-balance (who principal))
  (ok (get bal (default-to {bal: u0} (map-get? balances {who: who})))))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-decimals)
  (ok (var-get decimals)))

(define-read-only (get-name)
  (ok (var-get name)))

(define-read-only (get-symbol)
  (ok (var-get symbol)))

(define-read-only (get-token-uri)
  (ok (var-get token-uri)))

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)))

;; --- Mint/Burn ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (check-system-pause) ERR_SYSTEM_PAUSED)
    (asserts! (check-emission-allowed amount) ERR_EMISSION_DENIED)
    (var-set total-supply (+ (var-get total-supply) amount))
    (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
      (map-set balances {who: recipient} {bal: (+ bal amount)}))
    (notify-mint amount recipient)
    (ok true)))

(define-public (burn (amount uint))
  (let ((bal (get bal (default-to {bal: u0} (map-get? balances {who: tx-sender})))))
    (asserts! (>= bal amount) ERR_NOT_ENOUGH_BALANCE)
    (asserts! (check-system-pause) ERR_SYSTEM_PAUSED)
    (map-set balances {who: tx-sender} {bal: (- bal amount)})
    (var-set total-supply (- (var-get total-supply) amount))
    (notify-burn amount tx-sender)
    (ok true)))

;; --- System Integration Interface ---
(define-read-only (get-system-info)
  (ok {
    integration-enabled: (var-get system-integration-enabled),
    coordinator: (var-get token-coordinator),
    emission-controller: (var-get emission-controller),
    protocol-monitor: (var-get protocol-monitor)}))

;; --- Creator Economy Functions ---
(define-public (mint-merit-reward (recipient principal) (base-amount uint) (merit-score uint))
  (let ((merit-bonus (/ (* base-amount merit-score (var-get merit-multiplier)) u100000))
        (total-amount (+ base-amount merit-bonus)))
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (check-system-pause) ERR_SYSTEM_PAUSED)
    (asserts! (check-emission-allowed total-amount) ERR_EMISSION_DENIED)
    (map-set merit-scores recipient merit-score)
    (var-set total-supply (+ (var-get total-supply) total-amount))
    (let ((current-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
      (map-set balances {who: recipient} {bal: (+ current-bal total-amount)}))
    (let ((contributions (default-to {total-bounties: u0, successful-proposals: u0, reputation: u0}
                                     (map-get? creator-contributions recipient))))
      (map-set creator-contributions recipient
               (merge contributions {reputation: merit-score})))
    (if (>= merit-score (var-get reputation-threshold))
        (map-set governance-eligibility recipient true)
        true)
    (notify-mint total-amount recipient)
    (ok total-amount)))

(define-public (update-creator-reputation (creator principal) (reputation uint) (bounties uint) (proposals uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-authorized-system tx-sender)) ERR_UNAUTHORIZED)
    (map-set creator-reputation creator reputation)
    (map-set creator-contributions creator
             {total-bounties: bounties, successful-proposals: proposals, reputation: reputation})
    (map-set governance-eligibility creator (>= reputation (var-get reputation-threshold)))
    (ok true)))

(define-private (distribute-bonus-iter (recipient principal) (state {amounts: (list 100 uint), index: uint, total: uint}))
  (let ((amounts-list (get amounts state))
        (idx (get index state))
        (amount (unwrap! (element-at amounts-list idx) state)))
    (let ((current-bal (get bal (default-to {bal: u0} (map-get? balances {who: recipient})))))
      (map-set balances {who: recipient} {bal: (+ current-bal amount)})
      (map-set seasonal-bonuses recipient amount))
    {amounts: amounts-list, index: (+ idx u1), total: (+ (get total state) amount)}))

(define-public (distribute-seasonal-bonus (recipients (list 100 principal)) (amounts (list 100 uint)))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (len recipients) (len amounts)) ERR_LENGTH_MISMATCH)
    (let ((result (fold distribute-bonus-iter recipients {amounts: amounts, index: u0, total: u0}))
          (total-bonus (get total result)))
      (asserts! (check-emission-allowed total-bonus) ERR_EMISSION_DENIED)
      (var-set total-supply (+ (var-get total-supply) total-bonus))
      (ok total-bonus))))

(define-read-only (get-creator-info (creator principal))
  (ok {
    reputation: (default-to u0 (map-get? creator-reputation creator)),
    merit-score: (default-to u0 (map-get? merit-scores creator)),
    governance-eligible: (default-to false (map-get? governance-eligibility creator)),
    contributions: (default-to {total-bounties: u0, successful-proposals: u0, reputation: u0}
                              (map-get? creator-contributions creator)),
    seasonal-bonus: (default-to u0 (map-get? seasonal-bonuses creator))}))

(define-read-only (get-governance-eligible-creators)
  (ok (list)))

(define-public (set-reputation-threshold (new-threshold uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (var-set reputation-threshold new-threshold)
    (ok true)))

(define-public (set-merit-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= new-multiplier MAX_MERIT_MULTIPLIER) ERR_INVALID_PARAMETERS)
    (var-set merit-multiplier new-multiplier)
    (ok true)))

;; --- Creator Governance Functions ---
(define-public (propose-creator-initiative (title (string-ascii 256)) (description (string-utf8 512)) (funding-request uint))
  (begin
    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) ERR_UNAUTHORIZED)
    (print {event: "creator-proposal", proposer: tx-sender, title: title, funding-request: funding-request})
    (ok true)))

(define-public (vote-creator-proposal (proposal-id uint) (support bool))
  (begin
    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) ERR_UNAUTHORIZED)
    (print {event: "creator-vote", voter: tx-sender, proposal-id: proposal-id, support: support})
    (ok true)))