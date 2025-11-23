# ⚠️ Non-Standard Clarity Functions Warning

## Overview

Some contracts in the Conxian codebase reference functions that are **NOT part of standard Clarity 3.0**. These need verification and potential replacement before mainnet deployment.

## Affected Functions

### 1. `keccak256`

**Status**: ❌ Not in Clarity 3.0 standard  
**Used in**:

- `contracts/dex/wormhole-integration.clar` (line 235, 371)
- `contracts/dex/nakamoto-compatibility.clar` (line 206)

**Purpose**: Cryptographic hashing for VAA validation and MEV protection

### 2. `principal-to-buff`

**Status**: ❌ Not in Clarity 3.0 standard  
**Used in**:

- `contracts/dex/nakamoto-compatibility.clar` (line 206)

**Purpose**: Convert principal to buffer for hashing

### 3. `string-to-buff`  

**Status**: ❌ Not in Clarity 3.0 standard  
**Used in**:

- `contracts/dex/nakamoto-compatibility.clar` (line 207)

**Purpose**: Convert string to buffer for hashing

### 4. `buff-to-uint-be`

**Status**: ❌ Not in Clarity 3.0 standard  
**Used in**:

- `contracts/dex/nakamoto-compatibility.clar` (line 208)

**Purpose**: Convert buffer to uint for hashing

## Required Actions

### Priority 1: Verify Function Availability

```bash
# Test if functions exist in Clarinet 3.7.0
clarinet check contracts/dex/nakamoto-compatibility.clar
clarinet check contracts/dex/wormhole-integration.clar
```

### Priority 2: Possible Solutions

#### Option A: Use Available Clarity Functions

Replace with standard Clarity 3.0 functions if possible:

- `hash160` - Available in Clarity
- `sha256` - Available in Clarity  
- `sha512` - Available in Clarity
- Manual buffer manipulations with `buff-to-int-be`, `buff-to-int-le`

#### Option B: Implement Polyfills

Create library contracts that implement these functions using available Clarity primitives.

#### Option C: Remove Experimental Features

If functions are not available:

- Remove or stub out `nakamoto-compatibility.clar` MEV protection
- Remove or modify `wormhole-integration.clar` to use available hashing

### Priority 3: Test Compilation

```bash
# Run full contract check
npm run clarinet:check

# Run tests to verify
npm test
```

## Impact Assessment

### High Risk Contracts

1. **wormhole-integration.clar**: Cross-chain functionality depends on `keccak256`
2. **nakamoto-compatibility.clar**: MEV protection depends on hash generation

### Mitigation Strategy

1. These contracts may be **experimental/future-ready** features
2. Consider marking them as "not for mainnet deployment" until functions are available
3. Document which contracts are production-ready vs experimental

## Recommendations

### For SDK 3.7.0 Deployment

1. ✅ **Test compilation**: Run `clarinet check` on all contracts
2. ⚠️ **Mark experimental**: Tag contracts using non-standard functions
3. ⚠️ **Deployment plan**: Exclude experimental contracts from initial mainnet deployment
4. 📝 **Documentation**: Update README to clarify production vs experimental contracts

### Future Clarity Versions

- Monitor Clarity upgrade proposals for `keccak256` support
- Stay aligned with Wormhole integration standards

## Testing Status

**Last Tested**: October 9, 2025  
**SDK Version**: Clarinet 3.7.0  
**Status**: ❌ **COMPILATION FAILED**

  **Result**:


  ```bash
  $ clarinet check
  error: NoSuchContract("STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.traits folder")
  ```

  **Additional Issues Found**:


  - Missing `utils.clar` contract implementation (see SDK_3_7_0_ALIGNMENT_REPORT.md)
  - Non-standard functions prevent compilation
  - Contract dependency resolution errors

## Resolution Timeline

- **Immediate**: Document and test (this file)
- **Short-term** (1-2 weeks): Verify function availability or implement alternatives
- **Long-term**: Track Clarity upgrades for native support

---

*Created: October 9, 2025*  
*Priority: High - Blocking mainnet deployment*  
*Assignee: Development Team*
