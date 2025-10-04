;; governance-signature-verifier.clar
;; Governance signature verification using SIP-018 implementation
;; Handles proposal signing and verification for governance operations

;; --- Traits ---
(use-trait sip-018-trait .all-traits.sip-018-trait)
(impl-trait .all-traits.sip-018-trait)

;; Constants
(define-constant TRAIT_REGISTRY ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)

;; --- Constants ---
(define-constant ERR_INVALID_PROPOSAL (err u8001))
(define-constant ERR_EXPIRED_PROPOSAL (err u8002))
(define-constant ERR_INSUFFICIENT_VOTING_POWER (err u8003))
(define-constant ERR_ALREADY_SIGNED (err u8004))

(define-constant governance .lending-protocol-governance)
(define-constant signed-data-base .signed-data-base)

;; --- Storage ---
(define-map signed-proposals
    { proposal-id: uint }
    {
        signatures: (list 100 (buff 65)),
        signing-power: uint,
        expiry: uint
    })

;; --- Public Functions ---

(define-public (submit-proposal-signature
    (proposal-id uint)
    (signature (buff 65))
    (structured-data (buff 1024)))
    (let
        (
            (proposal (unwrap! (get-proposal-details proposal-id) ERR_INVALID_PROPOSAL))
            (voting-power (try! (contract-call? governance get-voting-power tx-sender)))
        )
        ;; Verify the signature
        (try! (verify-structured-data structured-data signature tx-sender))

        ;; Check expiry
        (asserts! (< block-height (get expiry proposal)) ERR_EXPIRED_PROPOSAL)

        ;; Check if already signed
        (asserts! (not (has-signed? proposal-id tx-sender)) ERR_ALREADY_SIGNED)

        ;; Update signatures
        (try! (add-signature proposal-id signature voting-power))

        ;; Emit event
        (print {
            event: "proposal-signed",
            proposal-id: proposal-id,
            signer: tx-sender,
            voting-power: voting-power,
            block-height: block-height
        })

        (ok true)))

;; --- Read Only Functions ---

(define-read-only (get-proposal-signatures (proposal-id uint))
    (map-get? signed-proposals { proposal-id: proposal-id }))

(define-read-only (has-signed? (proposal-id uint) (signer principal))
    (let
        ((proposal (unwrap! (get-proposal-details proposal-id) false)))
        (default-to
            false
            (contract-call? signed-data-base has-signature proposal-id signer))))

(define-read-only (get-proposal-signing-power (proposal-id uint))
    (ok (get signing-power
        (default-to
            { signatures: (list), signing-power: u0, expiry: u0 }
            (map-get? signed-proposals { proposal-id: proposal-id })))))

;; --- Private Functions ---

(define-private (add-signature (proposal-id uint) (signature (buff 65)) (voting-power uint))
    (let
        ((current-state (default-to
            { signatures: (list), signing-power: u0, expiry: u0 }
            (map-get? signed-proposals { proposal-id: proposal-id }))))

        (map-set signed-proposals
            { proposal-id: proposal-id }
            {
                signatures: (unwrap! (as-max-len?
                    (append (get signatures current-state) signature)
                    u100) ERR_INVALID_PROPOSAL),
                signing-power: (+ (get signing-power current-state) voting-power),
                expiry: (get expiry current-state)
            })
        (ok true)))

(define-private (get-proposal-details (proposal-id uint))
    (contract-call? governance get-proposal proposal-id))

;; --- SIP-018 Implementation ---

(define-public (verify-signature (message (buff 1024)) (signature (buff 65)) (signer principal))
    (contract-call? signed-data-base verify-signature message signature signer))

(define-public (verify-structured-data (structured-data (buff 1024)) (signature (buff 65)) (signer principal))
    (contract-call? signed-data-base verify-structured-data structured-data signature signer))

(define-public (get-domain-separator)
    (contract-call? signed-data-base get-domain-separator))

(define-public (get-structured-data-version)
    (contract-call? signed-data-base get-structured-data-version))

