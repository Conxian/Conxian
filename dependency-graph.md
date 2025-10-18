### access-control
- No explicit dependencies found.

### bond-issuance-system
- `backing-asset`
- `payment-token`
- `yield-token`

### comprehensive-lending-system
- `access-control`
- `asset`
- `fixed-point-math`
- `interest-rate-model`
- `lending-system-trait`
- `math-lib-advanced`
- `oracle`

### concentrated-liquidity-pool
- `dex-pool`
- `dim-registry`

### cxd-staking
- `cxd-token`
- `ft-mintable-trait`
- `revenue-token`
- `sip-010-trait`

### cxd-token
- `ft-mintable-trait`
- `monitor-trait`
- `sip-010-trait`

### CXLP-migration-queue
- `cxd-token`
- `CXLP-token`
- `sip-010-trait`

### CXLP-token
- `cxd`
- `ft-mintable-trait`
- `sip-010-trait`

### cxs-token
- `sip-009-trait`
- `sip-010-trait`

### cxtr-token
- `ft-mintable-trait`
- `monitor-trait`
- `sip-010-trait`

### cxvg-token
- `ft-mintable-trait`
- `sip-010-trait`

### cxvg-utility
- `cxvg-token`
- `sip-010-trait`

### dex-factory
- `access-control`
- `access-control-trait`
- `access-principal`
- `dex-pool`
- `sip-010-trait`

### dex-pool
- `dex-factory`
- `sip-010-trait`

### dex-router
- `dex-factory`
- `dex-pool`
- `fixed-point-math`
- `math-lib-advanced`
- `pool-ctr`
- `sip-010-trait`
- `token`

### dim-metrics
- `dim-registry`

### dim-oracle-automation
- `dim-registry`
- `dimensional-oracle-trait`

### dim-registry
- `dex-factory`
- `dim-registry-trait`

### dim-revenue-adapter
- `coordinator-contract`
- `distributor-contract`
- `metrics-contract`
- `monitor-contract`
- `payment-token`
- `reward-token`

### dim-yield-stake
- `dim-metrics`
- `sip-010-trait`
- `token`

### enhanced-flash-loan-vault
- `asset`
- `fixed-point-math`
- `flash-loan-receiver-trait`
- `math-lib-advanced`
- `receiver`

### enhanced-yield-strategy
- `sip-010-trait`
- `token-system-coordinator`

### enterprise-loan-manager
- `bond-contract-ref`
- `collateral-asset`
- `lending-system-trait`
- `loan-asset`
- `precision-calculator-trait`
- `sip-010-trait`
- `yield-contract`

### fixed-point-math
- `math-lib-advanced`

### flash-loan-receiver-trait
- No explicit dependencies found.

### interest-rate-model
- `fixed-point-math`

### lending-protocol-governance
- `access-control`
- `access-control-trait`
- `comprehensive-lending-system`
- `loan-liquidation-manager`

### lending-system-trait
- `flash-loan-receiver-trait`

### liquidation-manager
- `lending-system`

### liquidation-trait
- `standard-constants-trait`

### liquidity-optimization-engine
- `sip-010-trait`

### loan-liquidation-manager
- `comprehensive-lending-system`
- `dex-factory`
- `fixed-point-math`
- `lending-protocol-governance`
- `lending-system`

### math-lib-advanced
- No explicit dependencies found.

### mock-token
- `ft-mintable-trait`
- `sip-010-trait`

### oracle
- `dex-factory`

### precision-calculator
- `fixed-point-math`
- `math-lib-advanced`

### protocol-invariant-monitor
- `monitor-trait`
- `sip-010-trait`
- `staking-trait`

### revenue-distributor
- `revenue-token`
- `sip-010-trait`
- `staking-trait`

### sbtc-bond-integration
- `SBTC_MAINNET`
- `enhanced-yield-strategy`
- `sbtc-integration`

### sbtc-flash-loan-extension
- `asset`
- `bond-issuance-system`
- `receiver`

### sbtc-flash-loan-vault
- `asset`
- `receiver`

### sbtc-integration
- `sbtc-token`

### sbtc-lending-integration
- `asset`
- `collateral-asset`
- `sbtc-integration`

### sbtc-lending-system
- `asset`
- `collateral-asset`
- `repay-asset`

### timelock-controller
- No explicit dependencies found.

### token-emission-controller
- `ft-mintable-trait`
- `sip-010-trait`
- `token-contract`

### token-system-coordinator
- `comprehensive-lending-system`
- `cxd-staking`
- `cxd-token`
- `CXLP-migration-queue`
- `cxs-token`
- `cxvg-utility`
- `ft-mintable-trait`
- `lending-protocol-governance`
- `protocol-invariant-monitor`
- `revenue-distributor`
- `sip-010-trait`
- `token-emission-controller`

### tokenized-bond
- `payment-token`
- `sip-010-trait`

### tokenized-bond-adapter
- `coordinator-contract`
- `distributor-contract`
- `monitor-contract`
- `payment-token`
- `sip-010-trait`
- `token`
- `tokenized-bond`

### vault
- `asset`
- `comprehensive-lending-system`
- `enhanced-flash-loan-vault`

### wormhole-integration
- `sip-010-trait`
- `token`

### yield-distribution-engine
- `dex-factory`
