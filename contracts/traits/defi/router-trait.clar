(define-trait router-trait
  (
    (swap-exact-tokens-for-tokens (amount-in uint) (path (list 10 principal)) (recipient principal) (deadline uint) (response (list 10 uint) (err uint)))
    (swap-tokens-for-exact-tokens (amount-out uint) (path (list 10 principal)) (recipient principal) (deadline uint) (response (list 10 uint) (err uint)))
    (get-amounts-out (amount-in uint) (path (list 10 principal)) (response (list 10 uint) (err uint)))
    (get-amounts-in (amount-out uint) (path (list 10 principal)) (response (list 10 uint) (err uint)))
  )
)
