

(use-trait pausable-trait .all-traits.pausable-trait)
(use-trait pausable_trait .all-traits.pausable-trait)
(use-trait pausable-trait .all-traits.pausable-trait)
(define-constant ERR_PAUSED (err u200))
(define-constant ERR_NOT_PAUSED (err u201))
(define-data-var paused bool false)

(define-private (when-not-paused)
  (asserts! (not (var-get paused)) ERR_PAUSED)
  (ok true)
)

(define-private (when-paused)
  (asserts! (var-get paused) ERR_NOT_PAUSED)
  (ok true)
)

(define-private (only-pauser)
  

;; For now allow anyone; integrate access-control later
  (ok true)
)

(define-read-only (is-paused)
  (ok (var-get paused))
)

(define-public (pause)
  (begin
    (try! (only-pauser))
    (var-set paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (try! (only-pauser))
    (var-set paused false)
    (ok true)
  )
)

(define-public (test-when-not-paused)
  (begin
    (try! (when-not-paused))
    (ok true)
  )
)

(define-public (test-when-paused)
  (begin
    (try! (when-paused))
    (ok true)
  )
)