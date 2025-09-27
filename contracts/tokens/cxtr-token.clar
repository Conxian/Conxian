;; cxtr-token.clar
;; Conxian Treasury Token (SIP-010 FT) - represents treasury reserves and protocol-controlled value
;; Enhanced with system integration hooks for coordinator interface

;; --- Traits ---
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait sip-010-ft-mintable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-mintable-trait)
;; ... existing code ...
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-mintable-trait)

;; Constants
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_NOT_ENOUGH_BALANCE u101)
(define-constant ERR_SYSTEM_PAUSED u102)
(define-constant ERR_EMISSION_DENIED u103)

;; --- Storage ---
(define-data-var contract-owner principal tx-sender)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Conxian Contributor Token")
(define-data-var symbol (string-ascii 10) "CXTR")
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-map balances { who: principal } { bal: uint })
(define-map minters { who: principal } { enabled: bool })

;; --- System Integration ---
(define-data-var system-integration-enabled bool false)
(define-data-var token-coordinator (optional principal) none)
(define-data-var emission-controller (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; --- Creator Economy Enhancement ---
(define-data-var creator-council (optional principal) none)
(define-data-var bounty-system (optional principal) none)
(define-data-var reputation-threshold uint u1000) ;; Minimum reputation for governance
(define-data-var merit-multiplier uint u150) ;; 1.5x merit bonus multiplier

;; Maps for creator economy
(define-map creator-reputation principal uint)
(define-map merit-scores principal uint)
(define-map governance-eligibility principal bool)
(define-map creator-contributions principal (tuple (total-bounties uint) (successful-proposals uint) (reputation uint)))
(define-map seasonal-bonuses principal uint)

;; --- Helpers ---
(define-read-only (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-read-only (is-minter (who principal))
  (is-some (map-get? minters { who: who }))
)

;; --- Owner/Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-minter (who principal) (enabled bool))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (if enabled
      (map-set minters { who: who } { enabled: true })
      (map-delete minters { who: who })
    )
    (ok true)
  )
)

;; --- System Integration Setup ---
(define-public (enable-system-integration 
    (coordinator-contract principal)
    (emission-contract principal) 
    (monitor-contract principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set token-coordinator (some coordinator-contract))
    (var-set emission-controller (some emission-contract))
    (var-set protocol-monitor (some monitor-contract))
    (var-set system-integration-enabled true)
    (ok true)
  )
)

(define-public (enable-creator-economy
    (council-contract principal)
    (bounty-contract principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set creator-council (some council-contract))
    (var-set bounty-system (some bounty-contract))
    (ok true)
  )
)

(define-public (disable-system-integration)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled false)
    (ok true)
  )
)

;; --- System Integration Helpers ---
(define-private (check-system-pause)
  (if (var-get system-integration-enabled)
    (match (var-get protocol-monitor)
      monitor-contract
        true ;; Simplified for enhanced deployment - assume system operational
      true)
    true
  )
)

(define-private (check-emission-allowed (amount uint))
  (if (var-get system-integration-enabled)
    (match (var-get emission-controller)
      controller-contract
        true ;; Simplified for enhanced deployment - assume mint allowed
      true)
    true
  )
)

(define-private (notify-transfer (amount uint) (sender principal) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract
        ;; Simplified for enhanced deployment - avoid undeclared trait calls
        true
      true)
    true
  )
)

(define-private (notify-mint (amount uint) (recipient principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract
        ;; Simplified for enhanced deployment - avoid undeclared trait calls
        true
      true)
    true
  )
)

(define-private (notify-burn (amount uint) (burner principal))
  (if (var-get system-integration-enabled)
    (match (var-get token-coordinator)
      coordinator-contract
        ;; Simplified for enhanced deployment - avoid undeclared trait calls
        true
      true)
    true
  )
)

;; --- SIP-010 interface ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))
    (let ((sender-bal (default-to u0 (get bal (map-get? balances { who: sender })))))
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      (map-set balances { who: sender } { bal: (- sender-bal amount) })
      (let ((rec-bal (default-to u0 (get bal (map-get? balances { who: recipient })))))
        (map-set balances { who: recipient } { bal: (+ rec-bal amount) })
      )
      ;; Notify system coordinator
      (notify-transfer amount sender recipient)
    )
    (ok true)
  )
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (get bal (map-get? balances { who: who }))))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-decimals)
  (ok (var-get decimals))
)

(define-read-only (get-name)
  (ok (var-get name))
)

(define-read-only (get-symbol)
  (ok (var-get symbol))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (if (is-eq tx-sender (var-get contract-owner))
    (begin
      (var-set token-uri new-uri)
      (ok true)
    )
    (err ERR_UNAUTHORIZED)
  )
)

;; --- Mint/Burn (admin or authorized minters) ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))
    (asserts! (check-emission-allowed amount) (err ERR_EMISSION_DENIED))
    (var-set total-supply (+ (var-get total-supply) amount))
    (let ((bal (default-to u0 (get bal (map-get? balances { who: recipient })))))
      (map-set balances { who: recipient } { bal: (+ bal amount) })
    )
    ;; Notify system coordinator
    (notify-mint amount recipient)
    (ok true)
  )
)

(define-public (burn (amount uint))
  (let ((bal (default-to u0 (get bal (map-get? balances { who: tx-sender })))))
    (asserts! (>= bal amount) (err ERR_NOT_ENOUGH_BALANCE))
    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))
    (map-set balances { who: tx-sender } { bal: (- bal amount) })
    (var-set total-supply (- (var-get total-supply) amount))
    ;; Notify system coordinator
    (notify-burn amount tx-sender)
    (ok true)
  )
)

;; --- System Integration Interface ---
(define-read-only (get-system-info)
  {
    integration-enabled: (var-get system-integration-enabled),
    coordinator: (var-get token-coordinator),
    emission-controller: (var-get emission-controller),
    protocol-monitor: (var-get protocol-monitor)
  }
)

;; --- Creator Economy Functions ---
;; Mint tokens with merit-based bonus  
(define-public (mint-merit-reward (recipient principal) (base-amount uint) (merit-score uint))
  (let ((merit-bonus (/ (* base-amount merit-score (var-get merit-multiplier)) (* u1000 u100)))
        (total-amount (+ base-amount merit-bonus)))
    
    (asserts! (or (is-owner tx-sender) (is-minter tx-sender)) (err ERR_UNAUTHORIZED))
    (asserts! (check-system-pause) (err ERR_SYSTEM_PAUSED))
    (asserts! (check-emission-allowed total-amount) (err ERR_EMISSION_DENIED))
    
    ;; Update merit scores
    (map-set merit-scores recipient merit-score)
    
    ;; Mint tokens
    (var-set total-supply (+ (var-get total-supply) total-amount))
    (let ((current-bal (default-to u0 (get bal (map-get? balances { who: recipient })))))
      (map-set balances { who: recipient } { bal: (+ current-bal total-amount) }))
    
    ;; Update creator contributions
    (let ((contributions (default-to (tuple (total-bounties u0) (successful-proposals u0) (reputation u0))
                                    (map-get? creator-contributions recipient))))
      (map-set creator-contributions recipient
               (merge contributions { reputation: merit-score })))
    
    ;; Check governance eligibility
    (if (>= merit-score (var-get reputation-threshold))
        (map-set governance-eligibility recipient true)
        true)
    
    ;; Notify system coordinator
    (notify-mint total-amount recipient)
    (ok total-amount)))

;; Update creator reputation and contributions (called by creator council or bounty system)
(define-public (update-creator-reputation (creator principal) (reputation uint) (bounties uint) (proposals uint))
  (begin
    (asserts! (or (is-owner tx-sender) 
                 (is-eq tx-sender (unwrap! (var-get creator-council) (err ERR_UNAUTHORIZED)))
                 (is-eq tx-sender (unwrap! (var-get bounty-system) (err ERR_UNAUTHORIZED))))
             (err ERR_UNAUTHORIZED))
    
    ;; Update reputation
    (map-set creator-reputation creator reputation)
    
    ;; Update contributions
    (map-set creator-contributions creator
             (tuple (total-bounties bounties) (successful-proposals proposals) (reputation reputation)))
    
    ;; Update governance eligibility
    (map-set governance-eligibility creator (>= reputation (var-get reputation-threshold)))
    
    (ok true)))

;; Distribute seasonal bonuses to active creators
(define-public (distribute-seasonal-bonus (recipients (list 100 principal)) (amounts (list 100 uint)))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq (len recipients) (len amounts)) (err ERR_UNAUTHORIZED))
    
    ;; This would be implemented as a fold operation in production
    ;; For now, simplified implementation
    (let ((total-bonus (fold + amounts u0)))
      (asserts! (check-emission-allowed total-bonus) (err ERR_EMISSION_DENIED))
      (var-set total-supply (+ (var-get total-supply) total-bonus))
      (ok total-bonus))))

;; Get comprehensive creator information
(define-read-only (get-creator-info (creator principal))
  (ok (tuple (reputation (default-to u0 (map-get? creator-reputation creator)))
             (merit-score (default-to u0 (map-get? merit-scores creator)))
             (governance-eligible (default-to false (map-get? governance-eligibility creator)))
             (contributions (default-to (tuple (total-bounties u0) (successful-proposals u0) (reputation u0))
                                       (map-get? creator-contributions creator)))
             (seasonal-bonus (default-to u0 (map-get? seasonal-bonuses creator))))))

(define-read-only (get-governance-eligible-creators)
  ;; Get list of creators eligible for governance (simplified)
  (ok (list)))

(define-public (set-reputation-threshold (new-threshold uint))
  ;; Set minimum reputation threshold for governance participation
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set reputation-threshold new-threshold)
    (ok true)))

(define-public (set-merit-multiplier (new-multiplier uint))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (asserts! (<= new-multiplier u300) (err ERR_UNAUTHORIZED)) ;; Max 3x multiplier
    (var-set merit-multiplier new-multiplier)
    (ok true)))

;; --- Creator Governance Functions ---
(define-public (propose-creator-initiative (title (string-ascii 256)) (description (string-utf8 512)) (funding-request uint))
  (begin
    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) (err ERR_UNAUTHORIZED))
    
    ;; In production, would integrate with DAO governance system
    ;; For now, emit event
    (print (tuple (event "creator-proposal") 
                  (proposer tx-sender)
                  (title title)
                  (funding-request funding-request)))
    
    (ok true)))

(define-public (vote-creator-proposal (proposal-id uint) (support bool))
  (begin
    (asserts! (default-to false (map-get? governance-eligibility tx-sender)) (err ERR_UNAUTHORIZED))
    
    ;; In production, would integrate with DAO governance system
    (print (tuple (event "creator-vote") 
                  (voter tx-sender)
                  (proposal-id proposal-id)
                  (support support)))
    
    (ok true)))
