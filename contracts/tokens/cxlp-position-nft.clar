;; cxlp-position-nft.clar
;; Minimal LP position NFT for Conxian Protocol, aligned with CXLP and governance design.
;; Initial version: SIP-009 compatible metadata and ownership with CXLP transfers
;; for open/close, but no pool math or valuation yet.

;; --- Traits ---

(use-trait sip-009-nft-trait .sip-standards.sip-009-nft-trait)
(impl-trait .sip-standards.sip-009-nft-trait)

;; --- Constants ---

(define-constant ERR_UNAUTHORIZED u7100)
(define-constant ERR_NOT_OWNER u7101)
(define-constant ERR_TRANSFER_DISABLED u7102)
(define-constant ERR_NO_SUCH_POSITION u7103)

;; --- Data Variables & Maps ---

(define-data-var contract-owner principal tx-sender)
(define-data-var next-position-id uint u0)
(define-data-var transfers-enabled bool false)

(define-map position-owners uint principal)
(define-map positions
  uint
  {
    pool-id: uint,
    cxlp-amount: uint,
    created-at: uint,
    last-updated-at: uint
  }
)

;; Optional metadata URIs per position, used to satisfy SIP-009 get-token-uri.
(define-map token-uris uint (optional (string-utf8 256)))

;; --- Private Helpers ---

(define-private (is-owner (who principal))
  (is-eq who (var-get contract-owner))
)

(define-private (check-system-pause)
  false)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (enable-transfers)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfers-enabled true)
    (ok true)))

(define-public (disable-transfers)
  (begin
    (asserts! (is-owner tx-sender) (err ERR_UNAUTHORIZED))
    (var-set transfers-enabled false)
    (ok true)))

;; --- Position Lifecycle ---

;; Creates a new LP position NFT by transferring CXLP from the caller to this
;; contract and recording basic metadata. The `owner` must be the tx-sender.
(define-public (create-position
    (owner principal)
    (pool-id uint)
    (cxlp-amount uint)
  )
  (let ((position-id (+ (var-get next-position-id) u1)))
    (begin
      (asserts! (is-eq owner tx-sender) (err ERR_UNAUTHORIZED))
      (asserts! (> cxlp-amount u0) (err ERR_NO_SUCH_POSITION))
      (asserts! (not (check-system-pause)) (err ERR_TRANSFER_DISABLED))

      ;; Transfer CXLP from the user to this contract.
      ;; CXLP.transfer enforces tx-sender == sender. Here, tx-sender == owner,
      ;; so we can call transfer directly from the owner to this contract.
      (try! (contract-call? .cxlp-token transfer cxlp-amount owner .cxlp-position-nft none))

      (var-set next-position-id position-id)
      (map-set position-owners position-id owner)
      (map-set positions position-id {
        pool-id: pool-id,
        cxlp-amount: cxlp-amount,
        created-at: block-height,
        last-updated-at: block-height
      })
      (print {
        event: "cxlp-position-created",
        position-id: position-id,
        owner: owner,
        pool-id: pool-id,
        cxlp-amount: cxlp-amount,
      })
      (ok position-id))))

;; Closes an LP position, transferring the recorded CXLP amount back from this
;; contract to the recorded owner. Callable by the owner or contract-owner.
(define-public (close-position (position-id uint))
  (let (
        (owner (unwrap! (map-get? position-owners position-id) (err ERR_NO_SUCH_POSITION)))
        (position (unwrap! (map-get? positions position-id) (err ERR_NO_SUCH_POSITION)))
       )
    (begin
      (asserts! (or (is-owner tx-sender) (is-eq tx-sender owner)) (err ERR_NOT_OWNER))
      (asserts! (not (check-system-pause)) (err ERR_TRANSFER_DISABLED))

      ;; Transfer CXLP back from this contract to the owner.
      ;; Inside as-contract, tx-sender becomes .cxlp-position-nft, which must
      ;; match the sender argument for CXLP.transfer.
      (try! (as-contract
              (contract-call? .cxlp-token transfer
                (get cxlp-amount position)
                .cxlp-position-nft
                owner
                none)))

      (map-delete position-owners position-id)
      (map-delete positions position-id)
      (print {
        event: "cxlp-position-closed",
        position-id: position-id,
        owner: owner,
        cxlp-amount: (get cxlp-amount position),
      })
      (ok true))))

;; --- SIP-009-style Interface (minimal) ---

(define-public (transfer
    (position-id uint)
    (sender principal)
    (recipient principal)
  )
  (let ((owner (unwrap! (map-get? position-owners position-id) (err ERR_NO_SUCH_POSITION))))
    (begin
      (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
      (asserts! (is-eq sender owner) (err ERR_NOT_OWNER))
      (asserts! (var-get transfers-enabled) (err ERR_TRANSFER_DISABLED))
      (asserts! (not (check-system-pause)) (err ERR_TRANSFER_DISABLED))
      (map-set position-owners position-id recipient)
      (print {
        event: "cxlp-position-transferred",
        position-id: position-id,
        from: sender,
        to: recipient,
      })
      (ok true))))

;; --- Read-Only Views ---

(define-read-only (get-position (position-id uint))
  (map-get? positions position-id))

;; SIP-009: get-owner(token-id)
(define-read-only (get-owner (position-id uint))
  (ok (map-get? position-owners position-id)))

;; SIP-009: get-last-token-id()
(define-read-only (get-last-token-id)
  (ok (var-get next-position-id)))

;; SIP-009: get-token-uri(token-id)
(define-read-only (get-token-uri (position-id uint))
  (ok (default-to none (map-get? token-uris position-id))))

(define-read-only (get-transfers-enabled)
  (ok (var-get transfers-enabled)))
