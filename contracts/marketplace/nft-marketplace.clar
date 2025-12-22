;; nft-marketplace.clar
;; Comprehensive NFT marketplace for trading position NFTs and other digital assets
;; Supports listings, bids, auctions, and automated market making

(use-trait sip-009-nft-trait .defi-traits.sip-009-nft-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait fee-manager-trait .defi-traits.fee-manager-trait)

(impl-trait .defi-traits.sip-009-nft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_INVALID_LISTING (err u8001))
(define-constant ERR_LISTING_NOT_FOUND (err u8002))
(define-constant ERR_INSUFFICIENT_FUNDS (err u8003))
(define-constant ERR_BID_TOO_LOW (err u8004))
(define-constant ERR_AUCTION_NOT_ENDED (err u8005))
(define-constant ERR_LISTING_EXPIRED (err u8006))
(define-constant ERR_INVALID_NFT (err u8007))
(define-constant ERR_ALREADY_LISTED (err u8008))
;; Position/NFT-specific errors
(define-constant ERR_POSITION_NOT_FOUND (err u8009))

;; Marketplace Constants
(define-constant MARKETPLACE_FEE_BPS u250) ;; 2.5% marketplace fee
(define-constant MIN_LISTING_DURATION u1440000) ;; 100 blocks minimum
(define-constant MAX_LISTING_DURATION u144000000) ;; 10000 blocks maximum
(define-constant MIN_BID_INCREMENT u100) ;; 1% minimum bid increment

;; NFT Type Constants
(define-constant NFT_TYPE_MARKETPLACE_LISTING u1) ;; Active marketplace listing
(define-constant NFT_TYPE_SOLD_POSITION u2) ;; Sold position record
(define-constant NFT_TYPE_BID_CERTIFICATE u3) ;; Bid participation certificate
(define-constant NFT_TYPE_AUCTION_WINNER u4) ;; Auction winner badge
(define-constant NFT_TYPE_TRADING_HISTORY u5) ;; Trading history record

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)
(define-data-var next-listing-id uint u1)
(define-data-var next-auction-id uint u1)
(define-data-var base-token-uri (optional (string-utf8 256)) none)
(define-data-var protocol-fee-switch principal .protocol-fee-switch) ;; Dynamic Fee Switch

;; ===== NFT Definition =====
(define-non-fungible-token marketplace-nft uint)

;; ===== Marketplace Data Structures =====

;; Optimization: Direct Lookup Maps
(define-map listing-by-nft
  {
    nft-contract: principal,
    nft-token-id: uint,
  }
  uint
)
(define-map auction-by-listing
  { listing-id: uint }
  uint
)

;; Active listings
(define-map listings
  { listing-id: uint }
  {
    seller: principal,
    nft-contract: principal,
    nft-token-id: uint,
    price-token: principal,
    price-amount: uint,
    listing-type: uint, ;; 1=sale, 2=auction, 3=offers
    start-block: uint,
    end-block: uint,
    current-bid: (optional {
      bidder: principal,
      amount: uint,
    }),
    bid-count: uint,
    minimum-bid: uint,
    buy-now-price: (optional uint),
    listing-status: uint, ;; 1=active, 2=sold, 3=cancelled, 4=expired
    marketplace-fee: uint,
    seller-revenue: uint,
    created-at: uint,
  }
)

;; Bidding records
(define-map bids
  {
    listing-id: uint,
    bidder: principal,
  }
  {
    amount: uint,
    bid-block: uint,
    is-winning: bool,
    bid-type: uint, ;; 1=regular, 2=buy-now, 3=reserve
  }
)

;; Auction records
(define-map auctions
  { auction-id: uint }
  {
    listing-id: uint,
    seller: principal,
    nft-contract: principal,
    nft-token-id: uint,
    starting-price: uint,
    reserve-price: uint,
    current-high-bid: (optional {
      bidder: principal,
      amount: uint,
    }),
    total-bids: uint,
    start-block: uint,
    end-block: uint,
    auction-status: uint, ;; 1=active, 2=ended, 3=cancelled
    winner: (optional principal),
    final-price: (optional uint),
  }
)

;; Trading history
(define-map trading-history
  { trade-id: uint }
  {
    nft-contract: principal,
    nft-token-id: uint,
    seller: principal,
    buyer: principal,
    price-token: principal,
    price-amount: uint,
    marketplace-fee: uint,
    trade-block: uint,
    trade-type: uint, ;; 1=sale, 2=auction, 3=buy-now
  }
)

(define-data-var next-trade-id uint u1)

;; Enhanced marketplace NFT metadata
(define-map marketplace-nft-metadata
  { token-id: uint }
  {
    owner: principal,
    nft-type: uint,
    listing-id: (optional uint),
    trade-id: (optional uint),
    auction-id: (optional uint),
    achievement-tier: uint, ;; 1=basic, 2=advanced, 3=elite, 4=legendary
    trading-volume: uint,
    successful-trades: uint,
    total-earned: uint,
    marketplace-reputation: uint, ;; 0-1000 reputation score
    special-permissions: (list 10 (string-ascii 50)),
    visual-effects: (list 5 (string-ascii 30)),
    governance-weight: uint,
    revenue-share: uint,
    creation-block: uint,
    last-activity-block: uint,
  }
)

;; User marketplace profiles
(define-map user-marketplace-profiles
  { user: principal }
  {
    total-listings: uint,
    successful-sales: uint,
    total-revenue: uint,
    total-purchases: uint,
    average-sale-price: uint,
    reputation-score: uint,
    preferred-payment-tokens: (list 10 principal),
    special-achievements: (list 20 (string-ascii 50)),
    banned: bool,
    ban-reason: (optional (string-ascii 256)),
  }
)

;; ===== Public Functions =====

;; @desc Creates a new marketplace listing for sale
;; @param nft-contract The NFT contract implementing SIP-009
;; @param nft-token-id The NFT token ID
;; @param price-token The payment token
;; @param price-amount The asking price
;; @param duration The listing duration in blocks
;; @returns Response with listing ID or error
(define-public (create-sale-listing
    (nft-contract <sip-009-nft-trait>)
    (nft-token-id uint)
    (price-token <sip-010-ft-trait>)
    (price-amount uint)
    (duration uint)
  )
  (begin
    (asserts! (> price-amount u0) ERR_INVALID_LISTING)
    (asserts!
      (and (>= duration MIN_LISTING_DURATION) (<= duration MAX_LISTING_DURATION))
      ERR_INVALID_LISTING
    )

    ;; Verify NFT ownership via SIP-009 trait
    (let ((owner-opt (try! (contract-call? nft-contract get-owner nft-token-id))))
      (asserts! (is-some owner-opt) ERR_INVALID_NFT)
      (asserts! (is-eq tx-sender (unwrap-panic owner-opt)) ERR_UNAUTHORIZED)
    )

    ;; Escrow NFT
    (try! (contract-call? nft-contract transfer nft-token-id tx-sender
      (as-contract tx-sender)
    ))

    ;; Check if already listed
    (asserts!
      (is-none (map-get? listing-by-nft {
        nft-contract: (contract-of nft-contract),
        nft-token-id: nft-token-id,
      }))
      ERR_ALREADY_LISTED
    )

    (let (
        (listing-id (var-get next-listing-id))
        (price-principal (contract-of price-token))
        (nft-principal (contract-of nft-contract))
        (marketplace-fee (/ (* price-amount MARKETPLACE_FEE_BPS) u10000))
        (seller-revenue (- price-amount marketplace-fee))
      )
      ;; Create listing
      (map-set listings { listing-id: listing-id } {
        seller: tx-sender,
        nft-contract: nft-principal,
        nft-token-id: nft-token-id,
        price-token: price-principal,
        price-amount: price-amount,
        listing-type: u1, ;; Sale
        start-block: block-height,
        end-block: (+ block-height duration),
        current-bid: none,
        bid-count: u0,
        minimum-bid: price-amount,
        buy-now-price: (some price-amount),
        listing-status: u1, ;; Active
        marketplace-fee: marketplace-fee,
        seller-revenue: seller-revenue,
        created-at: block-height,
      })

      ;; Optimization: Set Lookup Map
      (map-set listing-by-nft {
        nft-contract: nft-principal,
        nft-token-id: nft-token-id,
      }
        listing-id
      )

      ;; Create listing NFT for seller
      (create-listing-nft listing-id tx-sender u1)

      ;; Update user profile
      (update-user-profile-on-list tx-sender)

      (var-set next-listing-id (+ listing-id u1))

      (print {
        event: "sale-listing-created",
        listing-id: listing-id,
        seller: tx-sender,
        nft-contract: nft-contract,
        nft-token-id: nft-token-id,
        price-token: price-principal,
        price-amount: price-amount,
        end-block: (+ block-height duration),
      })

      (ok listing-id)
    )
  )
)

;; @desc Creates a new auction listing
;; @param nft-contract The NFT contract implementing SIP-009
;; @param nft-token-id The NFT token ID
;; @param starting-price The starting bid price
;; @param reserve-price The minimum acceptable price
;; @param price-token The payment token
;; @param duration The auction duration in blocks
;; @returns Response with auction ID or error
(define-public (create-auction
    (nft-contract <sip-009-nft-trait>)
    (nft-token-id uint)
    (starting-price uint)
    (reserve-price uint)
    (price-token <sip-010-ft-trait>)
    (duration uint)
  )
  (begin
    (asserts! (> starting-price u0) ERR_INVALID_LISTING)
    (asserts! (>= reserve-price starting-price) ERR_INVALID_LISTING)
    (asserts!
      (and (>= duration MIN_LISTING_DURATION) (<= duration MAX_LISTING_DURATION))
      ERR_INVALID_LISTING
    )

    ;; Verify NFT ownership via SIP-009 trait
    (let ((owner-opt (try! (contract-call? nft-contract get-owner nft-token-id))))
      (asserts! (is-some owner-opt) ERR_INVALID_NFT)
      (asserts! (is-eq tx-sender (unwrap-panic owner-opt)) ERR_UNAUTHORIZED)
    )

    ;; Escrow NFT
    (try! (contract-call? nft-contract transfer nft-token-id tx-sender
      (as-contract tx-sender)
    ))

    ;; Check if already listed
    (asserts!
      (is-none (map-get? listing-by-nft {
        nft-contract: (contract-of nft-contract),
        nft-token-id: nft-token-id,
      }))
      ERR_ALREADY_LISTED
    )

    (let (
        (listing-id (var-get next-listing-id))
        (auction-id (var-get next-auction-id))
        (price-principal (contract-of price-token))
        (nft-principal (contract-of nft-contract))
      )
      ;; Create auction listing
      (map-set listings { listing-id: listing-id } {
        seller: tx-sender,
        nft-contract: nft-principal,
        nft-token-id: nft-token-id,
        price-token: price-principal,
        price-amount: starting-price,
        listing-type: u2, ;; Auction
        start-block: block-height,
        end-block: (+ block-height duration),
        current-bid: none,
        bid-count: u0,
        minimum-bid: starting-price,
        buy-now-price: none,
        listing-status: u1, ;; Active
        marketplace-fee: u0, ;; Calculated at sale
        seller-revenue: u0, ;; Calculated at sale
        created-at: block-height,
      })

      ;; Optimization: Set Lookup Map
      (map-set listing-by-nft {
        nft-contract: nft-principal,
        nft-token-id: nft-token-id,
      }
        listing-id
      )
      (map-set auction-by-listing { listing-id: listing-id } auction-id)

      ;; Create auction record
      (map-set auctions { auction-id: auction-id } {
        listing-id: listing-id,
        seller: tx-sender,
        nft-contract: nft-principal,
        nft-token-id: nft-token-id,
        starting-price: starting-price,
        reserve-price: reserve-price,
        current-high-bid: none,
        total-bids: u0,
        start-block: block-height,
        end-block: (+ block-height duration),
        auction-status: u1, ;; Active
        winner: none,
        final-price: none,
      })

      ;; Create auction NFT for seller
      (create-auction-nft auction-id tx-sender)

      ;; Update user profile
      (update-user-profile-on-list tx-sender)

      (var-set next-listing-id (+ listing-id u1))
      (var-set next-auction-id (+ auction-id u1))

      (print {
        event: "auction-created",
        listing-id: listing-id,
        auction-id: auction-id,
        seller: tx-sender,
        nft-contract: nft-contract,
        nft-token-id: nft-token-id,
        starting-price: starting-price,
        reserve-price: reserve-price,
        end-block: (+ block-height duration),
      })

      (ok auction-id)
    )
  )
)

;; @desc Places a bid on an auction
;; @param listing-id The listing ID
;; @param bid-amount The bid amount
;; @param price-token The payment token trait
;; @returns Response with success status
(define-public (place-bid
    (listing-id uint)
    (bid-amount uint)
    (price-token <sip-010-ft-trait>)
  )
  (let (
      (listing (unwrap! (map-get? listings { listing-id: listing-id })
        ERR_LISTING_NOT_FOUND
      ))
      (auction-info (get-auction-by-listing listing-id))
    )
    (asserts! (is-eq (get listing-type listing) u2) ERR_INVALID_LISTING)
    ;; Must be auction
    (asserts! (is-eq (get listing-status listing) u1) ERR_AUCTION_NOT_ENDED)
    ;; Must be active
    (asserts! (< block-height (get end-block listing)) ERR_AUCTION_NOT_ENDED)
    ;; Must not be expired
    (asserts! (is-eq (contract-of price-token) (get price-token listing))
      ERR_INVALID_LISTING
    )

    ;; Verify auction exists and is active
    (match auction-info
      auction (let (
          (current-high-bid (get current-high-bid auction))
          (minimum-bid (get minimum-bid listing))
        )
        ;; Check bid amount
        (asserts! (>= bid-amount minimum-bid) ERR_BID_TOO_LOW)
        (match current-high-bid
          high-bid
          (asserts! (> bid-amount (get amount high-bid)) ERR_BID_TOO_LOW) ;; Must beat current bid
          true
        )
        ;; First bid

        ;; Transfer bid amount to escrow
        (try! (contract-call? price-token transfer bid-amount tx-sender
          (as-contract tx-sender) none
        ))

        ;; Refund previous high bidder
        (match current-high-bid
          high-bid (as-contract (try! (contract-call? price-token transfer (get amount high-bid) tx-sender
            (get bidder high-bid) none
          )))
          true
        )

        ;; Record bid
        (map-set bids {
          listing-id: listing-id,
          bidder: tx-sender,
        } {
          amount: bid-amount,
          bid-block: block-height,
          is-winning: true,
          bid-type: u1, ;; Regular bid
        })

        ;; Update previous bidder's winning status
        (match current-high-bid
          high-bid (map-set bids {
            listing-id: listing-id,
            bidder: (get bidder high-bid),
          } {
            amount: (get amount high-bid),
            bid-block: block-height,
            is-winning: false,
            bid-type: u1,
          })
          true
        )

        ;; Update auction
        (map-set auctions { auction-id: (get-auction-id-by-listing listing-id) }
          (merge auction {
            current-high-bid: (some {
              bidder: tx-sender,
              amount: bid-amount,
            }),
            total-bids: (+ (get total-bids auction) u1),
          })
        )

        ;; Update listing
        (map-set listings { listing-id: listing-id }
          (merge listing {
            current-bid: (some {
              bidder: tx-sender,
              amount: bid-amount,
            }),
            bid-count: (+ (get bid-count listing) u1),
          })
        )

        ;; Create bid certificate NFT
        (create-bid-certificate-nft listing-id tx-sender bid-amount)

        (print {
          event: "bid-placed",
          listing-id: listing-id,
          bidder: tx-sender,
          bid-amount: bid-amount,
          total-bids: (+ (get total-bids auction) u1),
        })

        (ok true)
      )
      ERR_LISTING_NOT_FOUND
    )
  )
)

;; @desc Executes a buy-now purchase
;; @param listing-id The listing ID
;; @param nft-contract The NFT trait
;; @param price-token The payment token trait
;; @returns Response with success status
(define-public (buy-now
    (listing-id uint)
    (nft-contract <sip-009-nft-trait>)
    (price-token <sip-010-ft-trait>)
  )
  (let ((listing (unwrap! (map-get? listings { listing-id: listing-id }) ERR_LISTING_NOT_FOUND)))
    (asserts! (is-eq (get listing-status listing) u1) ERR_LISTING_NOT_FOUND)
    ;; Must be active
    (asserts! (< block-height (get end-block listing)) ERR_LISTING_EXPIRED)
    ;; Must not be expired
    (asserts! (is-eq (contract-of nft-contract) (get nft-contract listing))
      ERR_INVALID_NFT
    )
    (asserts! (is-eq (contract-of price-token) (get price-token listing))
      ERR_INVALID_LISTING
    )

    (match (get buy-now-price listing)
      buy-now-price (begin
        ;; Transfer funds to escrow
        (try! (contract-call? price-token transfer buy-now-price tx-sender
          (as-contract tx-sender) none
        ))

        ;; Execute sale and propagate its response
        (execute-sale listing-id listing tx-sender buy-now-price u3 nft-contract
          price-token
        )
      )
      ERR_INVALID_LISTING
    )
    ;; No buy-now price set
  )
)

;; @desc Ends an auction and transfers NFT to winner
;; @param listing-id The listing ID
;; @param nft-contract The NFT trait
;; @param price-token The payment token trait
;; @returns Response with success status
(define-public (end-auction
    (listing-id uint)
    (nft-contract <sip-009-nft-trait>)
    (price-token <sip-010-ft-trait>)
  )
  (let (
      (listing (unwrap! (map-get? listings { listing-id: listing-id })
        ERR_LISTING_NOT_FOUND
      ))
      (auction-info (get-auction-by-listing listing-id))
    )
    (asserts! (is-eq (get listing-type listing) u2) ERR_INVALID_LISTING)
    ;; Must be auction
    (asserts! (is-eq (get listing-status listing) u1) ERR_AUCTION_NOT_ENDED)
    ;; Must be active
    (asserts! (>= block-height (get end-block listing)) ERR_AUCTION_NOT_ENDED)
    ;; Must be ended
    (asserts! (is-eq (contract-of nft-contract) (get nft-contract listing))
      ERR_INVALID_NFT
    )
    (asserts! (is-eq (contract-of price-token) (get price-token listing))
      ERR_INVALID_LISTING
    )

    ;; Verify auction exists and is active
    (match auction-info
      auction (match (get current-high-bid auction)
        high-bid
        (let ((sale-res (execute-sale listing-id listing (get bidder high-bid)
            (get amount high-bid) u2 nft-contract price-token
          )))
          (begin
            (create-auction-winner-nft (get-auction-id-by-listing listing-id)
              (get bidder high-bid) (get amount high-bid)
            )
            sale-res
          )
        )
        ;; No bids - cancel auction (requires trait, so we call cancel-listing-internal or just cancel here with trait)
        (cancel-listing listing-id nft-contract)
      )
      ERR_LISTING_NOT_FOUND
    )
  )
)

;; @desc Cancels an active listing
;; @param listing-id The listing ID
;; @param nft-contract The NFT trait
;; @returns Response with success status
(define-public (cancel-listing
    (listing-id uint)
    (nft-contract <sip-009-nft-trait>)
  )
  (let ((listing (unwrap! (map-get? listings { listing-id: listing-id }) ERR_LISTING_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get seller listing)) ERR_UNAUTHORIZED)
    ;; Must be seller
    (asserts! (is-eq (get listing-status listing) u1) ERR_LISTING_NOT_FOUND)
    ;; Must be active
    (asserts! (is-eq (contract-of nft-contract) (get nft-contract listing))
      ERR_INVALID_NFT
    )

    ;; Return NFT to seller
    (as-contract (try! (contract-call? nft-contract transfer (get nft-token-id listing) tx-sender
      (get seller listing)
    )))

    ;; Update listing status
    (map-set listings { listing-id: listing-id }
      (merge listing { listing-status: u3 })
    )
    ;; Cancelled

    ;; Update auction if applicable
    (if (is-eq (get listing-type listing) u2)
      (let ((auction-id (get-auction-id-by-listing listing-id)))
        (map-set auctions { auction-id: auction-id } {
          listing-id: listing-id,
          seller: (get seller listing),
          nft-contract: (get nft-contract listing),
          nft-token-id: (get nft-token-id listing),
          starting-price: u0,
          reserve-price: u0,
          current-high-bid: none,
          total-bids: u0,
          start-block: u0,
          end-block: u0,
          auction-status: u3,
          winner: none,
          final-price: none,
        })
      )
      true
    )

    ;; Clean up Optimization Maps
    (map-delete listing-by-nft {
      nft-contract: (get nft-contract listing),
      nft-token-id: (get nft-token-id listing),
    })
    (map-delete auction-by-listing { listing-id: listing-id })

    (print {
      event: "listing-cancelled",
      listing-id: listing-id,
      seller: tx-sender,
      listing-type: (get listing-type listing),
    })

    (ok true)
  )
)

;; ===== SIP-009 Implementation =====

(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (var-get base-token-uri))
)

(define-read-only (get-owner (token-id uint))
  (match (map-get? marketplace-nft-metadata { token-id: token-id })
    nft (ok (some (get owner nft)))
    (ok none)
  )
)

(define-public (transfer
    (token-id uint)
    (sender principal)
    (recipient principal)
  )
  (match (map-get? marketplace-nft-metadata { token-id: token-id })
    nft-data (begin
      (asserts! (is-eq sender (get owner nft-data)) ERR_UNAUTHORIZED)

      ;; Transfer NFT ownership
      (unwrap! (nft-transfer? marketplace-nft token-id sender recipient)
        ERR_INVALID_NFT
      )

      ;; Update metadata
      (map-set marketplace-nft-metadata { token-id: token-id }
        (merge nft-data {
          owner: recipient,
          last-activity-block: block-height,
        })
      )

      (print {
        event: "marketplace-nft-transferred",
        token-id: token-id,
        from: sender,
        to: recipient,
        nft-type: (get nft-type nft-data),
      })
      (ok true)
    )
    ERR_POSITION_NOT_FOUND
  )
)

;; ===== Private Helper Functions =====

(define-private (execute-sale
    (listing-id uint)
    (listing {
      seller: principal,
      nft-contract: principal,
      nft-token-id: uint,
      price-token: principal,
      price-amount: uint,
      listing-type: uint,
      start-block: uint,
      end-block: uint,
      current-bid: (optional {
        bidder: principal,
        amount: uint,
      }),
      bid-count: uint,
      minimum-bid: uint,
      buy-now-price: (optional uint),
      listing-status: uint,
      marketplace-fee: uint,
      seller-revenue: uint,
      created-at: uint,
    })
    (buyer principal)
    (final-price uint)
    (trade-type uint)
    (nft-contract <sip-009-nft-trait>)
    (price-token <sip-010-ft-trait>)
  )
  (let (
      (marketplace-fee (/ (* final-price MARKETPLACE_FEE_BPS) u10000))
      (seller-revenue (- final-price marketplace-fee))
      (trade-id (var-get next-trade-id))
      (fee-switch (var-get protocol-fee-switch))
    )
    (asserts! (is-eq (contract-of nft-contract) (get nft-contract listing))
      ERR_INVALID_NFT
    )
    (asserts! (is-eq (contract-of price-token) (get price-token listing))
      ERR_INVALID_LISTING
    )

    ;; 1. Transfer NFT to buyer (from escrow)
    (as-contract (try! (contract-call? nft-contract transfer (get nft-token-id listing) tx-sender
      buyer
    )))

    ;; 2. Distribute Funds (from escrow)
    ;; To Seller
    (as-contract (try! (contract-call? price-token transfer seller-revenue tx-sender
      (get seller listing) none
    )))

    ;; To Fee Switch
    (if (> marketplace-fee u0)
      (begin
        (as-contract (try! (contract-call? price-token transfer marketplace-fee tx-sender fee-switch
          none
        )))
        (try! (contract-call? .protocol-fee-switch route-fees price-token
          marketplace-fee false "NFT"
        ))
        true
      )
      false
    )

    ;; Record trade
    (map-set trading-history { trade-id: trade-id } {
      nft-contract: (get nft-contract listing),
      nft-token-id: (get nft-token-id listing),
      seller: (get seller listing),
      buyer: buyer,
      price-token: (get price-token listing),
      price-amount: final-price,
      marketplace-fee: marketplace-fee,
      trade-block: block-height,
      trade-type: trade-type,
    })

    ;; Update listing status
    (map-set listings { listing-id: listing-id }
      (merge listing {
        listing-status: u2,
        seller-revenue: seller-revenue,
      })
    )

    ;; Clean up Optimization Maps
    (map-delete listing-by-nft {
      nft-contract: (get nft-contract listing),
      nft-token-id: (get nft-token-id listing),
    })
    (map-delete auction-by-listing { listing-id: listing-id })

    ;; Update user profiles
    (update-user-profile-on-sale (get seller listing) final-price true)
    (update-user-profile-on-purchase buyer final-price)

    ;; Create sold position NFT
    (create-sold-position-nft trade-id buyer (get nft-contract listing)
      (get nft-token-id listing) final-price
    )

    (var-set next-trade-id (+ trade-id u1))

    (print {
      event: "sale-executed",
      trade-id: trade-id,
      seller: (get seller listing),
      buyer: buyer,
      nft-contract: (get nft-contract listing),
      nft-token-id: (get nft-token-id listing),
      final-price: final-price,
      marketplace-fee: marketplace-fee,
      seller-revenue: seller-revenue,
      trade-type: trade-type,
    })
    (ok true)
  )
)

(define-private (create-listing-nft
    (listing-id uint)
    (owner principal)
    (nft-type uint)
  )
  (let ((token-id (var-get next-token-id)))
    (map-set marketplace-nft-metadata { token-id: token-id } {
      owner: owner,
      nft-type: nft-type,
      listing-id: (some listing-id),
      trade-id: none,
      auction-id: none,
      achievement-tier: u1,
      trading-volume: u0,
      successful-trades: u0,
      total-earned: u0,
      marketplace-reputation: u500,
      special-permissions: (list "listing-access" "sales-tracking"),
      visual-effects: (list "standard-border"),
      governance-weight: u1000,
      revenue-share: u100,
      creation-block: block-height,
      last-activity-block: block-height,
    })

    (mint-nft token-id owner)
    (var-set next-token-id (+ token-id u1))
  )
)

(define-private (create-auction-nft
    (auction-id uint)
    (owner principal)
  )
  (let ((token-id (var-get next-token-id)))
    (map-set marketplace-nft-metadata { token-id: token-id } {
      owner: owner,
      nft-type: NFT_TYPE_AUCTION_WINNER,
      listing-id: none,
      trade-id: none,
      auction-id: (some auction-id),
      achievement-tier: u2,
      trading-volume: u0,
      successful-trades: u0,
      total-earned: u0,
      marketplace-reputation: u600,
      special-permissions: (list "auction-access" "bidding-priority"),
      visual-effects: (list "silver-border" "animated-hammer"),
      governance-weight: u1200,
      revenue-share: u150,
      creation-block: block-height,
      last-activity-block: block-height,
    })

    (mint-nft token-id owner)
    (var-set next-token-id (+ token-id u1))
  )
)

(define-private (create-bid-certificate-nft
    (listing-id uint)
    (bidder principal)
    (bid-amount uint)
  )
  (let ((token-id (var-get next-token-id)))
    (map-set marketplace-nft-metadata { token-id: token-id } {
      owner: bidder,
      nft-type: NFT_TYPE_BID_CERTIFICATE,
      listing-id: (some listing-id),
      trade-id: none,
      auction-id: none,
      achievement-tier: u1,
      trading-volume: bid-amount,
      successful-trades: u0,
      total-earned: u0,
      marketplace-reputation: u550,
      special-permissions: (list "bid-access" "auction-tracking"),
      visual-effects: (list "bronze-border" "bid-animation"),
      governance-weight: u1100,
      revenue-share: u120,
      creation-block: block-height,
      last-activity-block: block-height,
    })

    (mint-nft token-id bidder)
    (var-set next-token-id (+ token-id u1))
  )
)

(define-private (create-auction-winner-nft
    (auction-id uint)
    (winner principal)
    (final-price uint)
  )
  (let ((token-id (var-get next-token-id)))
    (map-set marketplace-nft-metadata { token-id: token-id } {
      owner: winner,
      nft-type: NFT_TYPE_AUCTION_WINNER,
      listing-id: none,
      trade-id: none,
      auction-id: (some auction-id),
      achievement-tier: u3,
      trading-volume: final-price,
      successful-trades: u1,
      total-earned: u0,
      marketplace-reputation: u800,
      special-permissions: (list "winner-access" "exclusive-auctions" "priority-listing"),
      visual-effects: (list "golden-border" "crown-animation" "confetti-effect"),
      governance-weight: u1500,
      revenue-share: u200,
      creation-block: block-height,
      last-activity-block: block-height,
    })

    (mint-nft token-id winner)
    (var-set next-token-id (+ token-id u1))
  )
)

(define-private (create-sold-position-nft
    (trade-id uint)
    (buyer principal)
    (nft-contract principal)
    (nft-token-id uint)
    (price uint)
  )
  (let ((token-id (var-get next-token-id)))
    (map-set marketplace-nft-metadata { token-id: token-id } {
      owner: buyer,
      nft-type: NFT_TYPE_SOLD_POSITION,
      listing-id: none,
      trade-id: (some trade-id),
      auction-id: none,
      achievement-tier: u2,
      trading-volume: price,
      successful-trades: u1,
      total-earned: u0,
      marketplace-reputation: u650,
      special-permissions: (list "ownership-access" "resale-rights"),
      visual-effects: (list "purchase-animation" "ownership-border"),
      governance-weight: u1300,
      revenue-share: u160,
      creation-block: block-height,
      last-activity-block: block-height,
    })

    (mint-nft token-id buyer)
    (var-set next-token-id (+ token-id u1))
  )
)

(define-private (mint-nft
    (token-id uint)
    (recipient principal)
  )
  (unwrap! (nft-mint? marketplace-nft token-id recipient) false)
)

(define-private (is-nft-listed
    (nft-contract principal)
    (nft-token-id uint)
  )
  ;; Check if NFT is currently listed using direct lookup map
  (is-some (map-get? listing-by-nft {
    nft-contract: nft-contract,
    nft-token-id: nft-token-id,
  }))
)

(define-private (get-auction-by-listing (listing-id uint))
  (match (map-get? auction-by-listing { listing-id: listing-id })
    auction-id (map-get? auctions { auction-id: auction-id })
    none
  )
)

(define-private (get-auction-id-by-listing (listing-id uint))
  (default-to u0 (map-get? auction-by-listing { listing-id: listing-id }))
)

(define-private (get-listing-id (listing {
  listing-id: uint,
  seller: principal,
  nft-contract: principal,
  nft-token-id: uint,
  price-token: principal,
  price-amount: uint,
  listing-type: uint,
  start-block: uint,
  end-block: uint,
  current-bid: (optional {
    bidder: principal,
    amount: uint,
  }),
  bid-count: uint,
  minimum-bid: uint,
  buy-now-price: (optional uint),
  listing-status: uint,
  marketplace-fee: uint,
  seller-revenue: uint,
  created-at: uint,
}))
  (get listing-id listing)
)

(define-private (get-listing-id-by-listing (listing-id uint))
  listing-id
)

(define-private (update-user-profile-on-list (user principal))
  (let ((profile (default-to {
      total-listings: u0,
      successful-sales: u0,
      total-revenue: u0,
      total-purchases: u0,
      average-sale-price: u0,
      reputation-score: u500,
      preferred-payment-tokens: (list),
      special-achievements: (list),
      banned: false,
      ban-reason: none,
    }
      (map-get? user-marketplace-profiles { user: user })
    )))
    (map-set user-marketplace-profiles { user: user }
      (merge profile { total-listings: (+ (get total-listings profile) u1) })
    )
  )
)

(define-private (update-user-profile-on-sale
    (seller principal)
    (revenue uint)
    (success bool)
  )
  (let ((profile (default-to {
      total-listings: u0,
      successful-sales: u0,
      total-revenue: u0,
      total-purchases: u0,
      average-sale-price: u0,
      reputation-score: u500,
      preferred-payment-tokens: (list),
      special-achievements: (list),
      banned: false,
      ban-reason: none,
    }
      (map-get? user-marketplace-profiles { user: seller })
    )))
    (map-set user-marketplace-profiles { user: seller }
      (merge profile {
        total-revenue: (+ (get total-revenue profile) revenue),
        successful-sales: (if success
          (+ (get successful-sales profile) u1)
          (get successful-sales profile)
        ),
        average-sale-price: (/ (+ (get total-revenue profile) revenue)
          (+ (get successful-sales profile)
            (if success
              u1
              u0
            ))
        ),
        reputation-score: (if success
          (+ (get reputation-score profile) u50)
          (- (get reputation-score profile) u25)
        ),
      })
    )
  )
)

(define-private (update-user-profile-on-purchase
    (buyer principal)
    (amount uint)
  )
  (let ((profile (default-to {
      total-listings: u0,
      successful-sales: u0,
      total-revenue: u0,
      total-purchases: u0,
      average-sale-price: u0,
      reputation-score: u500,
      preferred-payment-tokens: (list),
      special-achievements: (list),
      banned: false,
      ban-reason: none,
    }
      (map-get? user-marketplace-profiles { user: buyer })
    )))
    (map-set user-marketplace-profiles { user: buyer }
      (merge profile {
        total-purchases: (+ (get total-purchases profile) u1),
        reputation-score: (+ (get reputation-score profile) u10),
      })
    )
  )
)

;; ===== Read-Only Functions =====

(define-read-only (get-listing (listing-id uint))
  (map-get? listings { listing-id: listing-id })
)

(define-read-only (get-auction (auction-id uint))
  (map-get? auctions { auction-id: auction-id })
)

(define-read-only (get-trade (trade-id uint))
  (map-get? trading-history { trade-id: trade-id })
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-marketplace-profiles { user: user })
)

(define-read-only (get-active-listings)
  (map-listings)
)

(define-read-only (get-user-bids (user principal))
  (map-bids)
)

(define-read-only (get-nft-metadata (token-id uint))
  (map-get? marketplace-nft-metadata { token-id: token-id })
)

;; Mock map functions for brevity (would be implemented with proper map iteration)
(define-private (map-listings)
  (list)
)
(define-private (map-auctions)
  (list)
)
(define-private (map-bids)
  (list)
)
