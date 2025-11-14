# Audit Registry System

> **Note:** This `README.md` is auto-generated from the docstrings in the source code. To update this documentation, please edit the docstrings in the corresponding Clarity files.

A decentralized, DAO-governed smart contract audit registry that issues verifiable NFT badges for audited contracts.

## Overview

The Audit Registry system consists of three main components:

1. **Audit Registry Contract (`audit-registry.clar`)**
   - Handles audit submissions
   - Manages DAO voting on audit validity
   - Tracks audit status and metadata

2. **Audit Badge NFT (`audit-badge-nft.clar`)**
   - SIP-009 compliant NFT contract
   - Issues verifiable badges for approved audits
   - Links NFTs to specific audit reports

3. **DAO Integration**
   - Decentralized governance of the audit process
   - Weighted voting based on token holdings
   - Transparent audit approval process

## Features

- **Decentralized Verification**: Audits are verified through DAO voting
- **Immutable Records**: Once approved, audit records cannot be altered
- **Verifiable Badges**: NFTs serve as proof of audit completion
- **Transparent Process**: All votes and decisions are on-chain
- **Flexible Integration**: Can be used by any smart contract ecosystem

## Workflow

1. **Audit Submission**
   - Auditor submits audit details (contract address, report hash, URI)
   - Submission requires staking tokens
   - Audit enters a voting period

2. **DAO Voting**
   - DAO members review and vote on the audit
   - Voting power is proportional to token holdings
   - Quorum and majority rules apply

3. **Audit Finalization**
   - After voting period, audit is approved or rejected
   - Approved audits receive an NFT badge
   - Results are permanently recorded on-chain

4. **Verification**
   - Anyone can verify audit status by checking the registry
   - NFT ownership proves audit completion
   - Historical records are preserved for reference

## Security Considerations

- Only DAO members with sufficient stake can vote
- Voting periods are fixed to prevent manipulation
- Emergency pause functionality for critical issues
- Transparent audit trail of all actions

## Integration

Contracts can check audit status using:

```clarity
(use-trait audit-registry-trait .audit-registry-trait.audit-registry-trait)

;; Check if a contract has a valid audit
(define-read-only (is-audited (contract-address principal))
  (match (contract-call? .audit-registry get-audit-status contract-address)
    status (ok (is-eq (get status status) "approved"))
    (ok false)
  )
)
```

## Testing

Run the test suite with:

```bash
clarinet test --match /audit-registry/
```

## Deployment

1. Deploy the NFT contract
2. Deploy the Audit Registry contract
3. Initialize the registry with the NFT contract address
4. Configure DAO parameters (voting period, quorum, etc.)

## License

MIT
