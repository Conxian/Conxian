;; ===========================================
;; GOVERNANCE TRAITS MODULE
;; ===========================================
;; Governance and voting specific traits
;; Designed for secure proposal execution

;; ===========================================
;; DAO TRAIT
;; ===========================================
(define-trait dao-trait
  (
    (propose ((string-utf8 256) (string-utf8 1024)) (response uint uint))
    (vote (uint uint) (response bool uint))
    (execute-proposal (uint) (response bool uint))
    (get-proposal (uint) (response (optional {
      proposer: principal,
      title: (string-utf8 256),
      description: (string-utf8 1024),
      start-block: uint,
      end-block: uint,
      for-votes: uint,
      against-votes: uint,
      state: uint
    }) uint))
  )
)

;; ===========================================
;; GOVERNANCE TOKEN TRAIT
;; ===========================================
(define-trait governance-token-trait
  (
    (get-voting-power (principal) (response uint uint))
    (get-voting-power-at (principal uint) (response uint uint))
    (delegate (principal) (response bool uint))
    (mint (principal uint) (response bool uint))
  )
)
