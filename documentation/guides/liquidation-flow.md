# Liquidation Flow Documentation

## Overview

This document outlines the liquidation process in the Conxian protocol, including the interactions between different components and the sequence of operations.

## Key Components

### 1. Liquidation Manager

- Main contract handling liquidation logic
- Implements `liquidation-trait`
- Manages whitelisted assets and keepers
- Handles emergency liquidations

### 2. Lending System

- Manages user positions and collateral
- Implements position health checks
- Handles debt and collateral adjustments

## Liquidation Process

### Standard Liquidation

1. **Initiation**:
   - Any user can call `liquidate-position`
   - System checks if position is underwater
   - Validates liquidation parameters

2. **Execution**:
   - Transfers debt tokens from liquidator
   - Updates borrower's debt and collateral
   - Transfers collateral to liquidator
   - Applies liquidation incentive

3. **Completion**:
   - Updates system state
   - Emits liquidation event
   - Updates global statistics

### Emergency Liquidation (Admin-Only)

1. **Initiation**:
   - Only callable by admin
   - Bypasses some checks for emergency situations
   - Can liquidate up to 100% of position

2. **Execution**:
   - Similar to standard liquidation
   - Additional access control checks
   - Special event logging

## Interfaces

### Liquidation Trait

```clarity
(define-trait liquidation-trait
  (
    ;; Check if position can be liquidated
    (can-liquidate-position 
      (borrower principal) 
      (debt-asset principal) 
      (collateral-asset principal)
    ) (response bool uint)
    
    ;; Liquidate a position
    (liquidate-position
      (borrower principal)
      (debt-asset principal)
      (collateral-asset principal)
      (debt-amount uint)
      (max-collateral-amount uint)
    ) (response (tuple (debt-repaid uint) (collateral-seized uint)) uint)
    
    ;; Other functions...
  )
)
```

## Error Codes

See `error-codes.md` for a complete list of error codes and their meanings.

## Security Considerations

- Always validate input parameters
- Use reentrancy guards where appropriate
- Implement proper access control
- Emit events for important state changes
- Consider front-running risks
