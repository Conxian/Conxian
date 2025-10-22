

;; SIP-009 Non-Fungible Token for Concentrated Liquidity Positions(define-non-fungible-token concentrated-liquidity-positions uint)

;; --- Constants ---(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant CONTRACT_OWNER tx-sender)

;; --- Data Variables ---(define-data-var last-token-id uint u0)
(define-data-var pool-contract principal tx-sender)

;; --- Public Functions ---

;; Initialize the contract with the address of the pool that can mint NFTs(define-public (set-pool-contract (pool principal))  (begin    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)    (var-set pool-contract pool)    (ok true)))

;; Transfer an NFT to a new owner(define-public (transfer (token-id uint) (sender principal) (recipient principal))  (begin    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)    (asserts! (is-some (nft-get-owner? concentrated-liquidity-positions token-id)) (err u404))    (asserts! (is-eq (unwrap! (nft-get-owner? concentrated-liquidity-positions token-id) ERR_NOT_TOKEN_OWNER) sender) ERR_NOT_TOKEN_OWNER)    (nft-transfer? concentrated-liquidity-positions token-id sender recipient)))

;; --- Read-Only Functions ---

;; Get the owner of a specific token(define-read-only (get-owner (token-id uint))  (ok (nft-get-owner? concentrated-liquidity-positions token-id)))

;; Get the last token ID minted(define-read-only (get-last-token-id)  (ok (var-get last-token-id)))

;; Get the token URI(define-read-only (get-token-uri (token-id uint))  (ok (some "https://conxian.io/positions/")))

;; --- Internal Functions ---

;; Mint a new NFT. Can only be called by the pool contract.(define-public (mint (recipient principal))  (begin    (asserts! (is-eq tx-sender (var-get pool-contract)) ERR_UNAUTHORIZED)    (let ((token-id (+ (var-get last-token-id) u1)))      (match (nft-mint? concentrated-liquidity-positions token-id recipient)        success (begin          (var-set last-token-id token-id)          (ok token-id))        (err err-code) (err err-code)))))

;; Burn an NFT. Can only be called by the pool contract.(define-public (burn (token-id uint) (owner principal))  (begin    (asserts! (is-eq tx-sender (var-get pool-contract)) ERR_UNAUTHORIZED)    (try! (nft-burn? concentrated-liquidity-positions token-id owner))    (ok true)))