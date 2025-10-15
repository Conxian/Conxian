# Conxian Trait Implementation Guide

## Overview
This guide explains how to implement and use traits in the Conxian protocol.

## Key Concepts
- **Centralized Traits**: All traits are defined in `contracts/traits/all-traits.clar`
- **Versioning**: Each trait has a version accessible via `get-trait-version`
- **Discovery**: Use `get-all-traits` to discover available traits

## Implementation Steps
1. **Import the trait**:
   ```clarity
   (use-trait my-trait .all-traits.my-trait)
   ```

2. **Implement the trait**:
   ```clarity
   (impl-trait .all-traits.my-trait)
   ```

3. **Use trait types**:
   ```clarity
   (define-public (my-function (param <my-trait>))
     ...
   )
   ```

## Best Practices
- Always reference traits via `.all-traits`
- Check trait versions for compatibility
- Use the discovery function to build flexible systems

## Examples
See `contracts/governance/governance-token.clar` for a reference implementation.
