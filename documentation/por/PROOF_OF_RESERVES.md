# Proof of Reserves (PoR)

This document describes the on-chain Proof of Reserves system implemented in the Conxian protocol.

## Overview

The PoR system enables cryptographic verification of reserve attestations using Merkle proofs. For each supported asset, an auditor updates the on-chain attestation with a Merkle root and metadata. Users and integrators can verify account-level reserves by submitting a leaf hash along with a sibling proof that reconstructs the root.

## Key Concepts

- Attestation: A tuple containing `root (buff 32)`, `total-reserves (uint)`, `updated-at (uint)`, `auditor (principal)`, and `version (uint)` stored per asset.
- Leaf Hash: Off-chain computed hash representing canonical serialization of `(principal, amount)` for the account. The leaf is provided to the contract as `(buff 32)`.
- Merkle Proof: An ordered list of siblings and side information. The contract reconstructs the root via `sha256(concat(...))` according to the proof order and compares it to the attested root.
- Staleness Guard: Integrators can query `is-stale` to detect whether the attestation is older than a configured block threshold.

## Contract Interface

- `set-admin(new-admin)`: Set the admin/auditor principal.
- `set-monitoring(m)`: Optionally register a monitoring contract/principal.
- `set-stale-threshold(blocks)`: Configure staleness threshold in blocks.
- `set-attestation(asset, root, total-reserves, version)`: Update attestation for an asset.
- `get-attestation(asset)`: Read attestation entry.
- `is-stale(asset)`: Check if attestation exceeds staleness threshold.
- `verify-merkle(asset, leaf, proof)`: Pure root reconstruction and equality check.
- `verify-account-reserve(asset, leaf, proof)`: Full verification with staleness guard and optional monitoring print.

## Integration Points

- Lending System: Downstream logic can call `is-stale` before using attested reserves and rely on `verify-account-reserve` to validate specific claims.
- Monitoring: The contract prints an event on successful verification; integrators can wire this to off-chain monitors. Additional hooks can be added if a metrics contract is provided.
- Oracle Aggregator: The staleness guard mirrors the approach used by the Oracle Aggregator v2, providing consistent fallback behavior and detection of outdated data.

## Security and Compliance

- Admin-only updates to attestation prevent unauthorized changes.
- All proofs must match the attested root; otherwise `ResponseErr ERR_INVALID_PROOF` is returned.
- Staleness guard ensures downstream consumers can avoid relying on outdated attestations.

## Testing

- Unit tests cover:
  - Setting attestation and verifying a valid proof.
  - Rejecting invalid proofs.
  - Staleness detection after configured threshold.

## Future Enhancements

- Canonical encoding helper contract for leaf construction (principal and amount), eliminating off-chain construction ambiguity.
- Circuit breaker integration to block updates or verification during detected anomalies.
- Expanded monitoring hooks to record verification metrics in a dedicated metrics contract.
