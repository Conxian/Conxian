# Oracle Integration Guide

This document outlines the oracle system architecture and integration with the Conxian lending protocol.

## Overview

The oracle system provides secure and reliable price feeds for assets in the Conxian protocol. It's designed with security, reliability, and decentralization in mind.

## Oracle Contract

### Key Features

- **Price Freshness**: Ensures prices are updated within a defined threshold
- **Admin Controls**: Secure admin functions for managing the oracle
- **Price Freezing**: Ability to freeze specific asset prices in case of emergencies
- **Decentralized Updates**: Support for multiple price feed providers
- **Multiple Price Feeds**: Supports multiple price feeds per token for redundancy
- **Deviation Checks**: Ensures prices don't deviate beyond configured thresholds
- **Staleness Protection**: Identifies and handles stale price data
- **Emergency Override**: Admin can manually override prices in emergencies
- **Feed Management**: Add/remove price feeds dynamically

### Contract Interface

```clarity
;; Oracle trait definition
(define-trait oracle-trait
  (
    ;; Get the current price of an asset in USD with 18 decimals
    (get-price (asset principal)) (response uint uint)
    
    ;; Get the last update time of an asset's price
    (get-last-update (asset principal)) (response uint uint)
    
    ;; Check if an asset's price is fresh (not stale)
    (is-price-fresh (asset principal)) (response bool uint)
    
    ;; Get the price with freshness check
    (get-price-fresh (asset principal)) (response uint uint)
    
    ;; Set the price of an asset (admin only)
    (set-price (asset principal) (price uint)) (response bool uint)
    
    ;; Set the oracle contract address (admin only)
    (set-oracle-contract (contract principal)) (response bool uint)
    
    ;; Get the oracle contract address
    (get-oracle-contract) (response (optional principal) uint)
  )
)
```

### Contracts

- **`oracle-trait.clar`**: Defines the standard interface for oracles
- **`dimensional-oracle.clar`**: Main implementation of the oracle system
- **`mock-oracle.clar`**: Mock implementation for testing

## Integration with Lending System

The lending system integrates with the oracle through the following functions:

### Price Fetching

```clarity
;; Get the price of an asset with validation
(define-read-only (get-asset-price (asset principal))
  (let (
      (oracle (unwrap! (get-oracle-contract) (err u1007)))  ;; ERR_INVALID_ORACLE
      (price (unwrap! (contract-call? oracle get-price-fresh asset) (err u1008)))  ;; ERR_PRICE_FETCH_FAILED
    )
    (ok price)
  )
)
```

### Health Factor Calculation

Health factors are calculated using oracle prices to determine the safety of user positions:

```clarity
(define-private (get-health-factor (user principal))
  (let (
      (collateral-value (unwrap! (get-total-collateral-value user) (err u1013)))  
      (debt-value (unwrap! (get-total-debt-value user) (err u1014)))
    )
    (if (<= debt-value u0)
      (ok MAX_UINT256)  ;; No debt means maximum health factor
      (ok (/ (* collateral-value PRECISION_18) debt-value))
    )
  )
)
```

## Circuit Breaker

The Circuit Breaker pattern protects the system from cascading failures.

### Key Features

- **Automatic Tripping**: Automatically opens the circuit when failure threshold is exceeded
- **Half-Open State**: Tests if the underlying issue is resolved before closing the circuit
- **Configurable Thresholds**: Adjustable failure rates and reset timeouts
- **Operation-Specific**: Can monitor different operations independently

### Contracts

- **`circuit-breaker-trait.clar`**: Defines the circuit breaker interface
- **`circuit-breaker.clar`**: Implementation of the circuit breaker pattern

## Monitoring System

The Monitoring system tracks system health and events.

### Key Features

- **Event Logging**: Capture and query system events with different severity levels
- **Health Status**: Track component health status and uptime
- **Alerting**: Configure alert thresholds for different components
- **Historical Data**: Query historical events for analysis

### Contracts

- **`monitoring-trait.clar`**: Defines the monitoring interface
- **`system-monitor.clar`**: Implementation of the monitoring system

## Security Considerations

### Price Freshness
- Prices are considered stale after 24 hours
- Stale prices will cause transactions to revert
- Emergency procedures are in place to handle oracle failures

### Admin Controls
- Oracle admin can update prices and manage the contract
- Price freezing prevents manipulation during emergencies
- Oracle contract address can be updated if needed

### Risk Parameters
- Minimum and maximum price bounds
- Staleness thresholds
- Collateral factors applied to asset values

## Testing

### Test Cases

1. **Price Updates**
   - Admin can update prices
   - Non-admin cannot update prices
   - Price updates emit events

2. **Price Freshness**
   - Fresh prices are accepted
   - Stale prices are rejected
   - Staleness threshold is enforced

3. **Integration Tests**
   - Health factor calculations use oracle prices
   - Liquidations trigger on price movements
   - Position health updates with price changes

## Emergency Procedures

### Oracle Failure
1. Pause the lending system
2. Deploy new oracle contract if needed
3. Update oracle contract reference
4. Resume operations

### Price Manipulation
1. Freeze affected asset prices
2. Investigate and resolve the issue
3. Update prices from trusted sources
4. Unfreeze when resolved

## Deployment

1. Deploy the oracle contract
2. Set initial prices
3. Configure the lending system with the oracle address
4. Monitor price feeds and system health
