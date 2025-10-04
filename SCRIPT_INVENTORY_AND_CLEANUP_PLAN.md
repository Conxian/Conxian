# Script Inventory & Cleanup Plan

**Date**: 2025-10-04 12:28 UTC+2  
**Total Scripts**: 85 items in /scripts directory  
**Status**: Analysis in progress

---

## 📊 SCRIPT INVENTORY

### Current Session Scripts (KEEP - Recently Created/Updated)

**Fix Scripts** (Working, Tested):
1. `fix-all-hardcoded-principals.ps1` - ✅ KEEP (Tested, 49 fixes)
2. `fix-remaining-syntax-errors.ps1` - ✅ KEEP (Tested, 17 fixes)
3. `fix-final-errors-for-deployment.ps1` - ✅ KEEP (Deployment prep)

**Deployment Scripts** (Working):
4. `gui_deployer.py` - ✅ KEEP (Main GUI, enhanced with pre-checks & logging)
5. `sdk_deploy_contracts.ts` - ✅ KEEP (SDK deployment)
6. `deploy_from_clarinet_list.js` - ✅ KEEP (Clarinet-based deployment)

**Governance Scripts** (Working):
7. `initialize-deployer-governance.ps1` - ✅ KEEP (DAO governance setup)
8. `transfer-to-dao-multisig.ps1` - ⚠️  CHECK (Created but not committed)

**Testing Scripts** (Working):
9. `test-gui-deployer.ps1` - ✅ KEEP (17-test validation suite)

**Utility Scripts** (Working):
10. `generate_wallets.js` - ✅ KEEP (Wallet generation)
11. `verify_contracts.py` - ✅ KEEP (Contract verification)
12. `sync_clarinet_contracts.py` - ✅ KEEP (Clarinet sync)

---

## 🔍 ANALYSIS CATEGORIES

### Category 1: Duplicate Fix Scripts (REVIEW NEEDED)

**Potentially Obsolete**:
- `fix-final-errors.ps1` vs `fix-final-errors-for-deployment.ps1`
- `fix-remaining-issues.ps1` vs `fix-remaining-syntax-errors.ps1`
- `fix-import-paths.ps1` - May be superseded
- `fix-test-imports.ps1` - May be obsolete
- `fix-token-imports.ps1` - May be obsolete
- `fix-trait-quotes.ps1` - May be obsolete
- `fix-trait-quotes.js` - JavaScript version duplicate
- `fix-impl-trait.js` - May be obsolete

**Action**: Read each to determine if superseded by current working scripts

---

### Category 2: Deployment Scripts (REVIEW NEEDED)

**Multiple Deploy Scripts**:
- `deploy-testnet.ps1` - ✅ Keep (PowerShell version)
- `deploy-testnet.sh` - ⚠️  Bash duplicate?
- `deploy-mainnet.sh` - ⚠️  For future use
- `deploy-enhanced.ps1` - ⚠️  What does it do?
- `deploy-enhanced-contracts.sh` - ⚠️  Bash version?
- `deploy-tokenomics.ps1` - ⚠️  Specific deploy script
- `deploy-tokenomics.sh` - ⚠️  Bash duplicate?
- `deploy-tokens.ps1` - ⚠️  Token-specific
- `deploy-access-control.ts` - ⚠️  Specific contract
- `deploy-oracle-system.ts` - ⚠️  Specific system
- `deploy-with-hiro.sh` - ⚠️  Alternative method?
- `auto-deploy.sh` - ⚠️  Auto deployment?
- `production-deployment-pipeline.sh` - ⚠️  Production script

**Action**: Evaluate against gui_deployer.py and sdk_deploy_contracts.ts

---

### Category 3: Testing/Verification Scripts (REVIEW NEEDED)

**Testing Scripts**:
- `test-deployment.ps1` - ⚠️  Old version?
- `test-hiro-api.ps1` - ⚠️  API testing
- `simple-api-test.ps1` - ⚠️  Basic API test
- `manual-testing.sh` - ⚠️  Manual test procedures
- `enhanced-verification-system.sh` - ⚠️  Verification system
- `enhanced-post-deployment-verification.ts` - ⚠️  Post-deploy checks
- `production-readiness-check.sh` - ⚠️  Production checks
- `verify.sh` - ⚠️  General verification
- `autocheck.sh` - ⚠️  Auto checking

**Action**: Compare with test-gui-deployer.ps1

---

### Category 4: Utility/Helper Scripts (REVIEW NEEDED)

**Utilities**:
- `pipeline_orchestrator.ps1` - ⚠️  Pipeline management
- `keeper_watchdog.py` - ⚠️  Keeper monitoring
- `governance_proposal_builder.py` - ⚠️  Governance tools
- `generate-deployer-key.ts` - ⚠️  Key generation
- `generate-dependency-graph.py` - ⚠️  Dependency visualization
- `centralize-trait-uses.js` - ⚠️  Trait centralization
- `ensure-deps.js` / `ensure-deps.sh` - ⚠️  Dependency checks
- `setup-env.ps1` - ⚠️  Environment setup
- `update-trait-references.ps1` - ⚠️  Trait updates
- `update-imports.ps1` - ⚠️  Import updates

**Action**: Determine current utility

---

### Category 5: Operational Scripts (REVIEW NEEDED)

**Operations**:
- `oracle_ops.sh` - ⚠️  Oracle operations
- `register_chainhook.sh` - ⚠️  Chainhook registration
- `monitor-health.sh` - ⚠️  Health monitoring
- `setup-monitoring.sh` - ⚠️  Monitoring setup
- `setup-ci-cd.sh` - ⚠️  CI/CD setup
- `ci-local.sh` - ⚠️  Local CI
- `integrate-aip-implementations.sh` - ⚠️  AIP integration
- `ping.sh` - ⚠️  Basic connectivity
- `broadcast-tx.sh` - ⚠️  Transaction broadcast
- `call-read.sh` - ⚠️  Contract reads
- `get-abi.sh` - ⚠️  ABI retrieval
- `claim-creator-tokens.sh` - ⚠️  Token claiming
- `deploy-health-monitor.sh` / `deploy-health-monitoring.sh` - ⚠️  Duplicates?
- `evaluate-pr.sh` - ⚠️  PR evaluation
- `migrate-to-access-control.ts` - ⚠️  Migration script
- `init-trait-registry.ts` - ⚠️  Trait registry init
- `post_deploy_handover.ts` / `post_deploy_verify.ts` - ⚠️  Post-deploy

**Action**: Determine production use

---

## 📝 ANALYSIS PLAN

### Phase 1: Read Key Scripts
1. Read all "fix-*" scripts to find duplicates
2. Read deployment scripts to find best one
3. Check testing scripts against our test suite
4. Verify utilities are still relevant

### Phase 2: Categorize
- **KEEP**: Currently used, tested, working
- **ARCHIVE**: Historical, may be useful later
- **DELETE**: Obsolete, superseded, broken

### Phase 3: Create Archive Directory
- Move historical scripts to `scripts/archive/`
- Keep working scripts in `scripts/`
- Document reasons

### Phase 4: Document
- Update scripts/README.md
- List active scripts with descriptions
- Note archived scripts

---

## ⚠️  SAFETY RULES

1. **Never delete without reading**
2. **Never delete if unsure - archive instead**
3. **Test system after any changes**
4. **Keep backups**
5. **Document everything**

---

## 📅 TIMELINE ANALYSIS

### Recently Modified (Last 24 Hours)

**Our Session (Today 04/10/2025 - KEEP)**:
- 12:23pm - `test-gui-deployer.ps1` (17 tests, validated)
- 12:10pm - `initialize-deployer-governance.ps1` (DAO governance)
- 12:02pm - `fix-final-errors-for-deployment.ps1` (final deployment prep)
- 11:54am - `fix-remaining-syntax-errors.ps1` (17 fixes, tested)
- 11:51am - `fix-all-hardcoded-principals.ps1` (49 fixes, tested)

**Earlier Today (Before Our Session - REVIEW)**:
- 11:20am - `fix-final-errors.ps1` ⚠️  OBSOLETE (superseded by 12:02pm version)
- 11:14am - `fix-remaining-issues.ps1` ⚠️  OBSOLETE (superseded by 11:54am version)
- 11:04am - `fix-trait-quotes.ps1` ⚠️  CHECK (may be incorporated into our fixes)
- 10:31am - `pipeline_orchestrator.ps1` ✅ KEEP (orchestration tool, still relevant)

**Yesterday (03/10/2025 - REVIEW)**:
- `test-hiro-api.ps1` ⚠️  CHECK (may be superseded by pre-checks in GUI)
- `simple-api-test.ps1` ⚠️  CHECK (basic API test, may be incorporated)

---

## 🎯 CLEANUP DECISIONS

### Category A: KEEP (Current Session - Active & Tested)

**Fix Scripts**:
1. ✅ `fix-all-hardcoded-principals.ps1` - Tested, 49 fixes
2. ✅ `fix-remaining-syntax-errors.ps1` - Tested, 17 fixes
3. ✅ `fix-final-errors-for-deployment.ps1` - Final deployment prep

**Deployment**:
4. ✅ `gui_deployer.py` - Main GUI with pre-checks & logging
5. ✅ `sdk_deploy_contracts.ts` - SDK-based deployment
6. ✅ `deploy_from_clarinet_list.js` - Clarinet-based deployment
7. ✅ `deploy-testnet.ps1` - PowerShell testnet deployment
8. ✅ `pipeline_orchestrator.ps1` - Full orchestration

**Governance**:
9. ✅ `initialize-deployer-governance.ps1` - DAO governance setup

**Testing**:
10. ✅ `test-gui-deployer.ps1` - 17-test validation suite

**Utilities** (Referenced in Working Scripts):
11. ✅ `verify_contracts.py` - Contract verification
12. ✅ `sync_clarinet_contracts.py` - Clarinet sync
13. ✅ `generate_wallets.js` - Wallet generation
14. ✅ `post_deploy_handover.ts` - Post-deployment handover
15. ✅ `post_deploy_verify.ts` - Post-deployment verification

---

### Category B: ARCHIVE (Obsolete - Superseded by Category A)

**Fix Scripts (MOVE TO archive/fixes/)**:
1. 📦 `fix-final-errors.ps1` - Superseded by fix-final-errors-for-deployment.ps1
2. 📦 `fix-remaining-issues.ps1` - Superseded by fix-remaining-syntax-errors.ps1
3. 📦 `fix-trait-quotes.ps1` - Likely incorporated into our fixes
4. 📦 `fix-trait-quotes.js` - JavaScript duplicate
5. 📦 `fix-impl-trait.js` - Likely incorporated
6. 📦 `fix-import-paths.ps1` - Likely obsolete
7. 📦 `fix-test-imports.ps1` - Likely obsolete
8. 📦 `fix-token-imports.ps1` - Likely obsolete

---

### Category C: EVALUATE (May Still Be Useful)

**Deployment Scripts** (Check if superseded by GUI deployer):
- `deploy-enhanced.ps1` - Enhanced validation script
- `deploy-tokenomics.ps1` / `deploy-tokenomics.sh` - Token-specific
- `deploy-tokens.ps1` - Token deployment
- `deploy-mainnet.sh` - Production (KEEP for future)
- `deploy-access-control.ts` - Specific contract
- `deploy-oracle-system.ts` - Specific system

**Testing Scripts** (Check against test-gui-deployer.ps1):
- `test-deployment.ps1` - May be obsolete
- `test-hiro-api.ps1` - May be incorporated into GUI
- `simple-api-test.ps1` - Basic test

**Utilities**:
- `generate-deployer-key.ts` - Key generation (KEEP)
- `ensure-deps.js` / `ensure-deps.sh` - Dependency management

---

## 📁 PROPOSED ARCHIVE STRUCTURE

```
scripts/
├── (active scripts - keep here)
└── archive/
    ├── fixes/            (obsolete fix scripts)
    ├── deployment/       (old deployment scripts)
    ├── testing/          (old test scripts)
    └── utilities/        (old utility scripts)
```

---

## ⚠️  CRITICAL: Scripts NOT TO DELETE

Even if obsolete, these should be ARCHIVED not deleted:
1. Any script with deployment logic
2. Any script with security/key management
3. Any script referenced in documentation
4. Any script from production deployments
5. Pipeline/orchestration scripts

---

## 🔍 NEXT STEPS

1. ✅ Read each "obsolete" script to confirm
2. ✅ Check for references in code/docs
3. ✅ Create archive directory structure
4. ✅ Move (not delete) obsolete scripts
5. ✅ Update README.md with current inventory
6. ✅ Test system after cleanup
7. ✅ Document changes

---

*Analysis ready for execution...*
