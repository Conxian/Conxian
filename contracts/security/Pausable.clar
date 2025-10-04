;; Pausable Contract
;; Provides emergency stop mechanism that can be triggered by authorized accounts

(use-trait pausable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.pausable-trait)

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.pausable-trait)

(define-constant ERR_PAUSED (err u200))
(define-constant ERR_NOT_PAUSED (err u201))

(define-data-var paused bool false)

;; ========== Modifiers ==========

(define-private (when-not-paused)
  (asserts! (not (var-get paused)) ERR_PAUSED)
  (ok true)
)

(define-private (when-paused)
  (asserts! (var-get paused) ERR_NOT_PAUSED)
  (ok true)
)

(define-private (only-pauser)
  ;; This would typically check access control, for now just allow anyone
  (ok true)
)

;; ========== External Functions ==========

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

;; ========== Test Helpers ==========

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
