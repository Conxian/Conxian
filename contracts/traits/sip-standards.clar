;; SIP Standards Traits - Production Module

;; ===========================================
;; SIP-010: FUNGIBLE TOKEN STANDARD
;; ===========================================
(define-trait sip-010-ft-trait (
  (transfer
    (uint principal principal (optional (buff 34)))
    (response bool uint)
  )
  (get-name
    ()
    (response (string-ascii 32) uint)
  )
  (get-symbol
    ()
    (response (string-ascii 10) uint)
  )
  (get-decimals
    ()
    (response uint uint)
  )
  (get-balance
    (principal)
    (response uint uint)
  )
  (get-total-supply
    ()
    (response uint uint)
  )
  (get-token-uri
    ()
    (response (optional (string-utf8 256)) uint)
  )
))

;; ===========================================
;; SIP-009: NFT STANDARD
;; ===========================================
(define-trait sip-009-nft-trait (
  (get-last-token-id
    ()
    (response uint uint)
  )
  (get-token-uri
    (uint)
    (response (optional (string-utf8 256)) uint)
  )
  (get-owner
    (uint)
    (response (optional principal) uint)
  )
  (transfer
    (uint principal principal)
    (response bool uint)
  )
))

;; ===========================================
;; SIP-018: METADATA STANDARD
;; ===========================================
(define-trait sip-018-metadata-trait (
  (get-token-uri
    ()
    (response (optional (string-utf8 256)) uint)
  )
))

;; ===========================================
;; FT-MINTABLE TRAIT (Extension)
;; ===========================================
(define-trait ft-mintable-trait (
  (mint
    (uint principal)
    (response bool uint)
  )
  (burn
    (uint principal)
    (response bool uint)
  )
))
