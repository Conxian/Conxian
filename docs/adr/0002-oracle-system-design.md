# 2. Oracle System Design

## Context and Problem Statement
We need a reliable oracle system to provide price feeds for various assets in the Conxian DeFi protocol. The system must be secure, decentralized, and resistant to manipulation.

## Decision
We will implement a multi-feed oracle system with the following characteristics:

1. **Multiple Data Sources**: Aggregate prices from multiple independent sources
2. **Deviation Checking**: Reject prices that deviate significantly from the median
3. **Circuit Breaker**: Automatically disable oracle updates if anomalies are detected
4. **Monitoring**: Comprehensive monitoring of oracle health and performance
5. **Emergency Override**: Admin ability to manually set prices in case of emergency

## Status
Implemented

## Consequences
- Increased security through decentralization
- Protection against flash loan attacks
- More reliable price feeds
- Additional complexity in implementation
- Higher gas costs due to multiple price checks
