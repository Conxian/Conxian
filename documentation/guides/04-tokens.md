# Contract Guide: Protocol Tokens (SIP-010)

**Primary Contracts:** `contracts/cxvg-token.clar`, `contracts/cxd-token.clar`, `contracts/CXLP-token.clar`, `contracts/cxtr-token.clar`, `contracts/cxs-token.clar`

## 1. Introduction

The Conxian ecosystem utilizes a multi-token model to facilitate governance, reward liquidity providers, and incentivize contributors. All protocol tokens adhere to the Stacks `SIP-010` standard for fungible tokens. This guide provides an overview of each token's purpose and utility within the protocol.

The primary tokens are:

- **CXVG Token (`cxvg-token`):** The core governance token (no direct revenue share).
- **CXD Token (`cxd-token`):** The main token; accrues protocol revenue to holders.
- **CXLP Token (`CXLP-token`):** The liquidity provider (LP) token.
- **CXTR Token (`cxtr-token`):** A merit-based rewards token for contributors.
- **CXS Token (`cxs-token`):** A soulbound (non-transferable) reputation token for contributors (SIP-009 NFT).

## 2. Token Details

### CXVG Token (`cxvg-token.clar`)

- **Purpose:** `CXVG` is the main governance token of the Conxian protocol. Its primary role is to give holders a say in the future direction of the platform.
- **Utility:**
  - **Revenue Share:** None; protocol revenue accrues to `CXD` holders.
  - **Governance:** CXVG confers governance rights; a separate `.CXVG` may be derived if the DAO adopts that model.
- **How to Acquire:**
  - Governance rewards and DAO programs (if approved).
  - Purchasing on the open market (DEX).
  - Community incentives.

### CXD Token (`cxd-token.clar`)

- **Purpose:** `CXD` is the revenue/tokenomics token of the protocol; it receives protocol revenue distributions.
- **Utility:**
  - **Revenue Accrual:** 80% of protocol revenue is distributed to `CXD` holders.
  - **DAO-Controlled Supply:** Soft cap 1B with emissions/deflation governed within guardrails.
- **How to Acquire:**
  - Migrating from `CXLP` via epoch bands.
  - DAO emissions/reserve allocations (if approved).
  - Secondary markets (DEX).

### CXLP Token (`CXLP-token.clar`)

- **Purpose:** `CXLP` is a reward token for users who provide liquidity to the Conxian protocol, either by depositing into the main vault or by adding liquidity to the DEX.
- **Utility:**
  - **Migration to CXD:** `CXLP` tokens can be converted into `CXD` tokens across 4 epoch bands (1.0x → up to 2.0x), bounded and timelocked. Requires `CXLP-token` configuration and authorizing the `CXLP-token` contract as a minter in `cxd-token`.
  - **Yield Farming:** `CXLP` can be staked in yield farms to earn additional rewards.
- **How to Acquire:**
  - Automatically earned by depositing assets into the `vault.clar` contract.
  - Earned by providing liquidity to pools in the Conxian DEX.

#### Migration Liquidity Controls (Epoch-Based)

- **Epoch Bands:** Migration from `CXLP` to `CXD` is enabled after `configure-migration(cxd, start-height, epoch-len)` and uses 4 bands with multipliers 1.00x → 2.00x.
- **Per-Epoch Cap (CXD minted):** Owner/DAO can set a global epoch cap for `CXD` minted via `set-liquidity-params(epoch-cap, user-base, user-factor, user-max, midyear, adjust-bps)`.
  - When non-zero, the contract enforces `epoch-minted + cxd-out <= epoch-cap` or `ERR_EPOCH_CAP_EXCEEDED`.
- **Per-User Allowance (long-term first):** Each user has an allowance weighted by holding duration: `user-cap = min(user-base + user-factor * duration, user-max)`; duration is measured since their last receipt/mint.
  - Enforced per epoch: `user-epoch-minted + cxd-out <= user-cap` or `ERR_USER_CAP_EXCEEDED`.
  - Encourages long-term holding to migrate earlier and in larger tranches.
- **Auto vs Manual Adjustments:**
  - Auto: `auto-adjust()` can be called by anyone; it increases `epoch-cap` by `adjust-bps` every `midyear` blocks if not overridden.
  - Manual override: Owner/DAO can pause auto-adjust with `set-epoch-override(bool)` and reconfigure via `set-liquidity-params(...)`.
- **User Authorization:** All actions are user-signed. `migrate-to-cxd(amount, recipient, cxd)` burns `CXLP` from `tx-sender` and mints `CXD` to `recipient` via a trait-typed call to the configured `CXD` contract.
- **Traits:** Migration uses a minimal mintable FT trait `contracts/traits/ft-mintable-trait.clar`; `cxd-token.clar` implements this trait for dynamic minting.
- **Errors:**
  - `u102 ERR_MIGRATION_NOT_SET`, `u103 ERR_MIGRATION_NOT_STARTED`
  - `u104 ERR_CXD_NOT_SET`, `u105 ERR_CXD_MISMATCH`
  - `u106 ERR_EPOCH_CAP_EXCEEDED`, `u107 ERR_USER_CAP_EXCEEDED`

### Governance Token (`CXVG.clar`) (planned)

- **Purpose:** This is the specific token used for voting in the `dao-governance.clar` contract.
- **Utility:**
  - **Voting Power:** The number of `CXVG` you hold determines your voting power in DAO proposals.
  - **Proposal Creation:** A minimum balance of `CXVG` is required to create a new proposal.
- **How to Acquire:**
  - Typically acquired by staking or locking `CXVG` tokens. This separation allows for more flexible governance models (e.g., time-weighted voting power based on lock duration).

### CXTR Token (`cxtr-token.clar`)

- **Purpose:** A unique, merit-based token designed to reward individuals who contribute to the Conxian ecosystem through non-financial means.
- **Utility:**
  - **Bounties:** Awarded for completing development bounties, fixing bugs, or creating new features.
  - **Community Contributions:** Can be awarded for creating documentation, tutorials, providing community support, or other valuable contributions.
  - **Reputation:** Serves as an on-chain record of a user's positive contributions to the protocol.
- **How to Acquire:**
  - Awarded by the DAO through the `bounty-system.clar` (planned) or by direct grants for valuable work.

### CXS Token (`cxs-token.clar`)

- **Purpose:** A soulbound (non-transferable) reputation NFT used to recognize identity and long-term contributions.
- **Utility:**
  - **Non-Transferable:** Transfers disabled to maintain soulbound semantics.
  - **Reputation/Identity:** Can be used by off-chain systems and UIs to show verified contributor status.
  - **Metadata:** Optional per-token URI for badge metadata.
- **How to Acquire:**
  - Minted by DAO/admin to a contributor’s principal; burnable by admin or owner for revocation.
- **Implementation:** Conforms to SIP-009 via `contracts/traits/sip-009-trait.clar`.

## 3. Token Interaction Flow

The tokens are designed to work together to create a balanced and sustainable economic system.

1. **Users provide liquidity** (to the vault or DEX) and receive **`CXLP`** tokens as a reward.
2. **`CXLP` holders can choose to migrate** their tokens to **`CXD`** tokens to gain revenue exposure; governance rights are via **`CXVG`**.
3. **`CXVG` holders vote** on DAO proposals (optionally via derived `CXVG` if adopted).
4. **Contributors perform work**, complete bounties, and are rewarded with **`CXTR`**; the DAO may also issue **`CXS`** soulbound badges to recognize reputation.

This system aligns the incentives of different user groups: liquidity providers are rewarded, long-term holders govern the protocol, and valuable contributors are recognized and compensated.
