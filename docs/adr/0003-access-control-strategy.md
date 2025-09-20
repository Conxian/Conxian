# 3. Access Control Strategy

## Context and Problem Statement
We need a consistent and secure way to manage access control across all smart contracts in the Conxian protocol.

## Decision
We will implement a role-based access control (RBAC) system with the following roles:

1. **DEFAULT_ADMIN_ROLE**: Can grant and revoke all roles
2. **PAUSER_ROLE**: Can pause the contract in case of emergency
3. **ORACLE_UPDATER**: Can update oracle prices
4. **LIQUIDATOR**: Can perform liquidations
5. **STRATEGIST**: Can manage investment strategies

## Status
Proposed

## Consequences
- Fine-grained permission control
- Better security through principle of least privilege
- More complex role management
- Slightly higher gas costs for access checks
