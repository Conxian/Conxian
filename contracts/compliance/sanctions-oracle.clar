;; sanctions-oracle.clar
;; Sanctions screening oracle with Chainhook integration
;; Provides real-time OFAC and international sanctions list screening

(define-constant ERR_UNAUTHORIZED (err u9500))
(define-constant ERR_ALREADY_SCREENED (err u9501))
(define-constant ERR_SCREENING_FAILED (err u9502))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var oracle-admin principal tx-sender)
(define-data-var last-update-block uint u0)

;; --- Sanctions Lists ---
(define-map sanctioned-addresses principal {
  list-name (string 64),
  added-at uint,
  reason (string 256),
})

(define-map screening-results {
  address: principal,
} {
  is-sanctioned bool,
  last-screened uint,
  list-found (string 64),
  confidence uint,  ;; 0-10000 basis points
})

;; --- Chainhook Integration ---
(define-map chainhook-events {
  event-id (string 128),
} {
  address principal,
  sanction-status bool,
  timestamp uint,
  source-list (string 64),
})

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-admin-or-owner)
  (or (is-eq tx-sender (var-get contract-owner))
      (is-eq tx-sender (var-get oracle-admin)))
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-oracle-admin (admin principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set oracle-admin admin)
    (ok true)
  )
)

;; --- Sanctions List Management ---

;; @notice Add an address to sanctions list (oracle admin only)
(define-public (add-sanctioned-address
    (address principal)
    (list-name (string 64))
    (reason (string 256))
  )
  (begin
    (asserts! (is-admin-or-owner) ERR_UNAUTHORIZED)
    (map-set sanctioned-addresses address {
      list-name: list-name,
      added-at: block-height,
      reason: reason,
    })
    (print {
      event: "sanctioned-address-added",
      address: address,
      list-name: list-name,
      reason: reason,
      added-at: block-height,
    })
    (ok true)
  )
)

;; @notice Remove address from sanctions list (oracle admin only)
(define-public (remove-sanctioned-address (address principal))
  (begin
    (asserts! (is-admin-or-owner) ERR_UNAUTHORIZED)
    (map-delete sanctioned-addresses address)
    (print {
      event: "sanctioned-address-removed",
      address: address,
      removed-at: block-height,
    })
    (ok true)
  )
)

;; --- Chainhook Integration ---

;; @notice Process sanctions update from Chainhook
(define-public (process-chainhook-update
    (event-id (string 128))
    (address principal)
    (sanction-status bool)
    (source-list (string 64))
  )
  (begin
    (asserts! (is-admin-or-owner) ERR_UNAUTHORIZED)
    
    ;; Store chainhook event
    (map-set chainhook-events event-id {
      address: address,
      sanction-status: sanction-status,
      timestamp: block-height,
      source-list: source-list,
    })
    
    ;; Update sanctions list based on chainhook data
    (if sanction-status
      (begin
        (map-set sanctioned-addresses address {
          list-name: source-list,
          added-at: block-height,
          reason: "Chainhook automatic detection",
        })
        (print {
          event: "chainhook-sanction-added",
          address: address,
          source-list: source-list,
        })
      )
      (begin
        (map-delete sanctioned-addresses address)
        (print {
          event: "chainhook-sanction-removed",
          address: address,
          source-list: source-list,
        })
      )
    )
    
    (var-set last-update-block block-height)
    (ok true)
  )
)

;; --- Screening Functions ---

;; @notice Screen an address against sanctions lists
(define-public (screen-address (address principal))
  (let ((current-height block-height)
        (sanctioned (map-get? sanctioned-addresses address)))
    (if (some? sanctioned)
      (begin
        (map-set screening-results {address: address} {
          is-sanctioned: true,
          last-screened: current-height,
          list-found: (get list-name (unwrap! sanctioned ERR_SCREENING_FAILED)),
          confidence: u10000,  ;; 100% confidence for direct match
        })
        (print {
          event: "address-screened-sanctioned",
          address: address,
          list-found: (get list-name (unwrap! sanctioned ERR_SCREENING_FAILED)),
          screened-at: current-height,
        })
        (ok true)
      )
      (begin
        (map-set screening-results {address: address} {
          is-sanctioned: false,
          last-screened: current_height,
          list-found: "",
          confidence: u10000,
        })
        (print {
          event: "address-screened-clear",
          address: address,
          screened-at: current-height,
        })
        (ok false)
      )
    )
  )
)

;; --- Read-Only Views ---

(define-read-only (is-sanctioned (address principal))
  (let ((result (map-get? sanctioned-addresses address)))
    (ok (some? result))
  )
)

(define-read-only (get-screening-result (address principal))
  (map-get? screening-results {address: address})
)

(define-read-only (get-sanctioned-addresses (start-index uint) (limit uint))
  (begin
    (var-set last-update-block block-height)
    (ok {
      addresses: (map-get? sanctioned-addresses tx-sender),  ;; Simplified for demo
      total-count: (var-get last-update-block),
    })
  )
)

(define-read-only (get-last-update-block)
  (ok (var-get last-update-block))
)

(define-read-only (get-chainhook-event (event-id (string 128)))
  (map-get? chainhook-events event-id)
)

;; --- Batch Operations ---

;; @notice Batch screen multiple addresses
(define-public (batch-screen-addresses (addresses (list 20 principal)))
  (let ((results (list)))
    (fold batch-screen-helper addresses results)
    (ok results)
  )
)

(define-private (batch-screen-helper (address principal) (results (list 20 bool)))
  (let ((screened (try! (contract-call? .self screen-address address))))
    (append results screened)
  )
)
