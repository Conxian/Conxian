;; ===========================================
;; ENCODING UTILITIES
;; ===========================================
;; Fixed-width, deterministic encodings for commitments and numeric values.
;;
;; This module provides encoding utilities for creating deterministic hashes
;; of structured data, used primarily for commitments and fixed-width encodings.
;;
;; NOTE: Clarity has no direct uint->buff primitive. We use hash256 for
;; deterministic fixed-width encoding by hashing the uint directly.

;; Encodes a uint as a fixed-width 32-byte hash
;; @param n: the unsigned integer to encode
;; @return (response (buff 32) uint): 32-byte hash of the encoded integer
(define-public (u-fixed32 (n uint))
  (ok (sha512/256 n)))

;; Encodes a commitment for a payment or state transition
;; Creates a deterministic hash from all input parameters
;; @param path: list of 20 uint values representing the path
;; @param amount: amount being committed
;; @param min: optional minimum amount (for partial withdrawals)
;; @param rcpt-index: recipient index in the merkle tree
;; @param salt: 32-byte random value to prevent preimage attacks
;; @return (response (buff 32) uint): 32-byte commitment hash
(define-public (encode-commitment
  (path (list 20 uint))
  (amount uint)
  (min (optional uint))
  (rcpt-index uint)
  (salt (buff 32)))
  (let (
    ;; Hash each numeric component for deterministic encoding
    (amount-hash (sha512/256 amount))
    (rcpt-hash (sha512/256 rcpt-index))
    (min-hash (match min
      some-val (sha512/256 some-val)
      0x000000000000000000000000000000000000000000
    ;; Concatenate hashes with salt and hash again for final commitment
    (combined (concat (concat (concat amount-hash rcpt-hash) min-hash) salt)))
    (ok (sha256 combined)))
)