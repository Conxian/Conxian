;; constants.clar
;; Centralized constants for the Conxian protocol

;; ===========================================
;; CORE ADDRESSES
;; ===========================================

;; Main contract owner - STP3 Address
(define-constant CONTRACT_OWNER 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6)

;; Core contract addresses
(define-constant ACCESS_CONTROL (concat CONTRACT_OWNER '.access-control))
(define-constant AUDIT_REGISTRY (concat CONTRACT_OWNER '.audit-registry))

;; ===========================================
;; TRAIT REFERENCES
;; ===========================================

(define-constant TRAITS_CONTRACT (concat CONTRACT_OWNER '.traits.all-traits))
(define-constant TRAITS_PREFIX (concat TRAITS_CONTRACT '.'))

;; Core trait references
(define-constant TRAIT_SIP010 (concat TRAITS_PREFIX 'sip-010-ft-trait))
(define-constant TRAIT_ACCESS_CONTROL (concat TRAITS_PREFIX 'access-control-trait))
(define-constant TRAIT_POOL (concat TRAITS_PREFIX 'pool-trait))
(define-constant TRAIT_FACTORY (concat TRAITS_PREFIX 'factory-trait))
(define-constant TRAIT_ROUTER (concat TRAITS_PREFIX 'router-trait))
(define-constant TRAIT_OWNABLE (concat TRAITS_PREFIX 'ownable-trait))
(define-constant TRAIT_PAUSABLE (concat TRAITS_PREFIX 'pausable-trait))
(define-constant TRAIT_ERROR_CODES (concat TRAITS_PREFIX 'error-codes-trait))
(define-constant TRAIT_CONSTANTS (concat TRAITS_PREFIX 'constants-trait))

;; ===========================================
;; COMMON CONSTANTS
;; ===========================================

;; Precision and math
(define-constant PRECISION u100000000)  ;; 8 decimals
(define-constant PERCENT_100 u10000)    ;; 100% in basis points
(define-constant MAX_UINT64 u18446744073709551615)

;; Fee defaults (in basis points: 100 = 1%)
(define-constant DEFAULT_FEE u30)       ;; 0.3%
(define-constant MAX_FEE u1000)         ;; 10% maximum fee
(define-constant FEE_DENOMINATOR u10000)  ;; 100% in basis points

;; Liquidity
(define-constant MINIMUM_LIQUIDITY u1000)
(define-constant MAX_RECURSION_DEPTH u5)

;; ===========================================
;; ERROR CODES
;; ===========================================

;; Common errors (1000-1999)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_PAUSED (err u1002))
(define-constant ERR_INVALID_PARAMETERS (err u1003))
(define-constant ERR_NOT_FOUND (err u1004))
(define-constant ERR_ALREADY_EXISTS (err u1005))
(define-constant ERR_DEADLINE_PASSED (err u1006))
(define-constant ERR_ZERO_AMOUNT (err u1007))

;; Pool-related errors (2000-2999)
(define-constant ERR_POOL_EXISTS (err u2001))
(define-constant ERR_INVALID_TOKENS (err u2002))
(define-constant ERR_POOL_NOT_FOUND (err u2003))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u2004))
(define-constant ERR_SLIPPAGE_TOO_HIGH (err u2005))
(define-constant ERR_INSUFFICIENT_SHARES (err u2006))
(define-constant ERR_ZERO_LIQUIDITY (err u2007))
(define-constant ERR_NOT_INITIALIZED (err u2008))
(define-constant ERR_ALREADY_INITIALIZED (err u2009))

;; Router-related errors (4000-4999)
(define-constant ERR_INVALID_PATH (err u4002))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u4003))
(define-constant ERR_TRANSFER_FAILED (err u4006))
(define-constant ERR_RECURSION_DEPTH (err u4007))
(define-constant ERR_DUPLICATE_TOKENS (err u4009))
(define-constant ERR_INSUFFICIENT_BALANCE (err u4010))
(define-constant ERR_BOND_NOT_MATURE (err u4011))
(define-constant ERR_REENTRANCY (err u4013))

;; ===========================================
;; ROLES
;; ===========================================

(define-constant ROLE_ADMIN "admin")
(define-constant ROLE_PAUSER "pauser")
(define-constant ROLE_MINTER "minter")
(define-constant ROLE_POOL_MANAGER "pool-manager")
(define-constant ROLE_GOVERNANCE "governance")
