;; =
;; ENCODING UTILITIES
;; =
;; Fixed-width, deterministic encodings for commitments and numeric values.
;;
;; This module provides encoding utilities for creating deterministic hashes
;; of structured data, used primarily for commitments and fixed-width encodings.
;;
;; NOTE: Clarity has no direct uint->BE-buff primitive. For fixed-width encodings,
;; we hash the consensus serialization to 32 bytes using sha256, which is stable.

;; Encodes a uint as a fixed-width 32-byte hash
;; @param n: the unsigned integer to encode
;; @return (response (buff 32) uint): 32-byte hash of the encoded integer and error code
(define-public (u-fixed32 (n uint))
  (ok (sha256 (to-consensus-buff n))))

;; Encodes a commitment for a payment or state transition
;; @param path: list of 20 uint values representing the path
;; @param amount: amount being committed
;; @param min: optional minimum amount (for partial withdrawals)
;; @param rcpt-index: recipient index in the merkle tree
;; @param salt: 32-byte random value to prevent preimage attacks
;; @return (response (buff 32) uint): 32-byte commitment hash and error code
(define-public (encode-commitment
  (path (list 20 uint))
  (amount uint)
  (min (optional uint))
  (rcpt-index uint)
  (salt (buff 32)))
  (let (
    (payload {
      path: path,
      amount: amount,
      min: min,
      rcpt: rcpt-index,
      salt: salt
    }))
    (ok (sha256 (to-consensus-buff payload)))
  )
)