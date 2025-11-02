(impl-trait .all-traits.access-control-trait)

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NFT (err u1002))

(define-data-var admin principal tx-sender)
(define-data-var role-nft (optional principal) none)

(define-map roles { role: (string-ascii 32), account: principal } bool)
(define-map role-token { role: (string-ascii 32), account: principal } uint)

(define-read-only (has-role (role (string-ascii 32)) (account principal))
  (ok (default-to false (map-get? roles {role: role, account: account}))))

(define-public (grant-role (role (string-ascii 32)) (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set roles {role: role, account: account} true)
    (match (var-get role-nft)
      nft-ctr (let ((tid (unwrap! (contract-call? nft-ctr mint-role role account) ERR_NFT)))
                (map-set role-token {role: role, account: account} tid)
                (ok true))
      (ok true))))

(define-public (revoke-role (role (string-ascii 32)) (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set roles {role: role, account: account} false)
    (match (map-get? role-token {role: role, account: account})
      tid (match (var-get role-nft)
            nft-ctr (begin (contract-call? nft-ctr burn-role tid) (ok true))
            (ok true))
      (ok true))))

(define-public (update-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-role-nft (nft principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set role-nft (some nft))
    (ok true)))
