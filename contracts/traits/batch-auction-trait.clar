;; ===========================================
;; BATCH AUCTION TRAIT
;; ===========================================
;; Interface for batch auction mechanisms
;;
;; This trait provides functions for batch-based price discovery
;; where multiple orders are collected and executed at a single price.
;;
;; Example usage:
;;   (use-trait batch-auction .batch-auction-trait.batch-auction-trait)
(define-trait batch-auction-trait
  (
    ;; Submit a bid to the batch auction
    ;; @param amount: amount of tokens to bid
    ;; @param price: bid price
    ;; @return (response uint uint): bid ID and error code
    (submit-bid (uint uint) (response uint uint))

    ;; Cancel a submitted bid
    ;; @param bid-id: bid identifier
    ;; @return (response bool uint): success flag and error code
    (cancel-bid (uint) (response bool uint))

    ;; Execute the batch auction
    ;; @return (response (tuple (clearing-price uint) (total-volume uint) (orders-filled uint)) uint): auction results and error code
    (execute-auction () (response (tuple (clearing-price uint) (total-volume uint) (orders-filled uint)) uint))

    ;; Get auction status
    ;; @return (response (tuple (status (string-ascii 20)) (start-time uint) (end-time uint) (total-bids uint)) uint): status and error code
    (get-auction-status () (response (tuple (status (string-ascii 20)) (start-time uint) (end-time uint) (total-bids uint)) uint))

    ;; Get clearing price for the current batch
    ;; @return (response uint uint): clearing price and error code
    (get-clearing-price () (response uint uint))
  )
)
