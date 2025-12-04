;; @contract DIA Oracle Mock
;; @version 1.0.0
;; @desc Mock implementation of DIA Oracle for testing and devnet.

(define-read-only (get-value (key (string-ascii 32)))
    (if true
        (ok {
            value: u100000000000, ;; 1000 * 10^8
            timestamp: block-height
        })
        (err u1) ;; Force error type inference
    )
)
