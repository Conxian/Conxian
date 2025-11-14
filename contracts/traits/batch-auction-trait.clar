;; ===========================================
;; BATCH AUCTION TRAIT
;; ===========================================
;; @desc Interface for batch auction mechanisms.
;; This trait provides functions for batch-based price discovery
;; where multiple orders are collected and executed at a single price.
;;
;; @example
;; (use-trait batch-auction .batch-auction-trait.batch-auction-trait)
(define-trait batch-auction-trait
  (
    ;; @desc Submit a bid to the batch auction.
    ;; @param amount: The amount of tokens to bid.
    ;; @param price: The bid price.
    ;; @returns (response uint uint): The ID of the newly created bid, or an error code.
    (submit-bid (uint uint) (response uint uint))

    ;; @desc Cancel a submitted bid.
    ;; @param bid-id: The identifier of the bid to cancel.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (cancel-bid (uint) (response bool uint))

    ;; @desc Execute the batch auction.
    ;; @returns (response (tuple (clearing-price uint) (total-volume uint) (orders-filled uint)) uint): A tuple containing the auction results, or an error code.
    (execute-auction () (response (tuple (clearing-price uint) (total-volume uint) (orders-filled uint)) uint))

    ;; @desc Get the status of the auction.
    ;; @returns (response (tuple (status (string-ascii 20)) (start-time uint) (end-time uint) (total-bids uint)) uint): A tuple containing the auction status, or an error code.
    (get-auction-status () (response (tuple (status (string-ascii 20)) (start-time uint) (end-time uint) (total-bids uint)) uint))

    ;; @desc Get the clearing price for the current batch.
    ;; @returns (response uint uint): The clearing price, or an error code.
    (get-clearing-price () (response uint uint))
  )
)
