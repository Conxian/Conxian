

;; encoding.clar

;; Fixed-width, deterministic encodings for commitments and numeric values.

;; NOTE: Clarity has no direct uint->BE-buff primitive. For fixed-width encodings,

;; we hash the consensus serialization to 32 bytes using sha256, which is stable.(define-public (u-fixed32 (n uint))  (ok (sha256 (to-consensus-buff n))))
(define-public (encode-commitment (  path (list 20 uint)  amount uint  min (optional uint)  rcpt-index uint  salt (buff 32)))  (let (    (payload       {        path: path,        amount: amount,        min: min,        rcpt: rcpt-index,        salt: salt      }    )  )    (ok (sha256 (to-consensus-buff payload)))  ))