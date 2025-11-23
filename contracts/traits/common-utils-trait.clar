;; common-utils-trait.clar
;; Shared utility functions for Conxian contracts

;; ===== Error Constants =====
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_INVALID_INPUT u105)

;; ===== Mathematical Utilities =====

;; Safe math operations with overflow protection
(define-read-only (safe-add
        (a uint)
        (b uint)
    )
    (if (> (+ a b) a)
        (+ a b)
        (standard-error ERR_INVALID_AMOUNT)
    )
)

(define-read-only (safe-sub
        (a uint)
        (b uint)
    )
    (if (>= a b)
        (- a b)
        (standard-error ERR_INVALID_AMOUNT)
    )
)

(define-read-only (safe-mul
        (a uint)
        (b uint)
    )
    (if (and
            (> a u0)
            (> b u0)
            (>= (/ (* a b) a) b)
        )
        (* a b)
        (standard-error ERR_INVALID_AMOUNT)
    )
)

(define-read-only (safe-div
        (a uint)
        (b uint)
    )
    (if (> b u0)
        (/ a b)
        (standard-error ERR_INVALID_AMOUNT)
    )
)

;; Percentage calculations (scaled by 10000)
(define-read-only (percentage-of
        (amount uint)
        (percentage uint)
    )
    (/ (* amount percentage) u10000)
)

(define-read-only (apply-fee
        (amount uint)
        (fee-rate uint)
    )
    (safe-sub amount (percentage-of amount fee-rate))
)

;; ===== Map Utilities =====

;; Safe map get with default
(define-read-only (map-get-or-default
        (map-name { key: uint })
        (key { key: uint })
        (default-value { value: uint })
    )
    (default-to default-value (map-get? map-name key))
)

;; Update map value with safe math
(define-private (map-update-safe
        (map-name { key: uint })
        (key { key: uint })
        (amount uint)
        (operation (string-ascii 8)) ;; "add" or "sub"
    )
    (let (
            (current-value (default-to u0 (map-get? map-name key)))
            (new-value (if (is-eq operation "add")
                (safe-add current-value amount)
                (safe-sub current-value amount)
            ))
        )
        (map-set map-name key { value: new-value })
        new-value
    )
)

;; ===== Block and Time Utilities =====

(define-constant BLOCKS_PER_YEAR u52560)
(define-constant BLOCKS_PER_DAY u144)

(define-read-only (blocks-to-years (blocks uint))
    (/ blocks BLOCKS_PER_YEAR)
)

(define-read-only (blocks-to-days (blocks uint))
    (/ blocks BLOCKS_PER_DAY)
)

(define-read-only (years-to-blocks (years uint))
    (* years BLOCKS_PER_YEAR)
)

(define-read-only (days-to-blocks (days uint))
    (* days BLOCKS_PER_DAY)
)

;; Check if enough blocks have passed
(define-read-only (blocks-since (start-block uint))
    (- block-height start-block)
)

(define-read-only (is-block-height-reached (target-height uint))
    (>= block-height target-height)
)

;; ===== List Utilities =====

;; Safe list length check
(define-read-only (list-length-safe
        (list-to-check (list 10 uint))
        (max-length uint)
    )
    (if (<= (len list-to-check) max-length)
        (len list-to-check)
        (standard-error ERR_INVALID_INPUT)
    )
)

;; Sum list with safe math
(define-read-only (sum-list-safe (values (list 10 uint)))
    (foldl (lambda (value acc) (safe-add acc value)) values u0)
)

;; ===== Principal Utilities =====

;; Validate principal format
(define-read-only (is-valid-contract-principal (addr principal))
    (and
        (is-some addr)
        (not (is-eq addr tx-sender))
    )
)

;; Generate unique identifier
(define-read-only (generate-id
        (principal-1 principal)
        (principal-2 principal)
        (nonce uint)
    )
    (let (
            (combined (concat (prin-to-buff principal-1) (prin-to-buff principal-2)))
            (with-nonce (concat combined (uint-to-buff nonce)))
        )
        (sha256 with-nonce)
    )
)

;; ===== Event Logging Utilities =====

;; Standardized event structure
(define-read-only (create-event
        (event-type (string-ascii 32))
        (data (buff 256))
    )
    {
        type: event-type,
        data: data,
        block: block-height,
        sender: tx-sender,
        timestamp: (get-block-info? block-height),
    }
)

;; Log standardized event
(define-private (log-event
        (event-type (string-ascii 32))
        (data (buff 256))
    )
    (print (create-event event-type data))
)