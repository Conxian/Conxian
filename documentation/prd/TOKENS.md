# Tokens

## CXD — Revenue & Staking
- Contract: `contracts/tokens/cxd-token.clar`
- Standard: SIP-010
- Features: emission controller hooks, system pause checks, integration notifications (coordinator hooks disabled by default for enhanced build).

## CXVG — Governance
- Contract: `contracts/tokens/cxvg-token.clar`
- Standard: SIP-010 (mintable)
- Features: minter roles, integration stubs for monitoring and coordination.

## CXLP — Liquidity Provider
- Contract: `contracts/tokens/cxlp-token.clar`
- Standard: SIP-010
- Features: migration configuration, epoch-based migration to CXD via queue, per-user and epoch caps.

### CXLP Migration Queue
- Contract: `contracts/dex/cxlp-migration-queue.clar`
- Features: intent window, duration-weighted allocation, pro-rata settlement, hooks from CXLP transfers.

## CXTR — Creator Economy
- Contract: `contracts/tokens/cxtr-token.clar`
- Features: merit-based distribution scaffolding and contribution tracking.

## CXS — Utility
- Contract: `contracts/tokens/cxs-token.clar`
- Standard: SIP-009 (NFT) for system utility positions.
