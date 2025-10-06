# Fix Trait Imports - Comprehensive System Repair
# This script systematically fixes trait imports to use centralized all-traits.clar

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Conxian Trait Import Fix Script v2.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$FixCount = 0
$FileCount = 0

# Get all Clarity contract files
$contractFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse -Exclude "all-traits.clar"

Write-Host "Found $($contractFiles.Count) contract files to process" -ForegroundColor Yellow
Write-Host ""

foreach ($file in $contractFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Gray
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    $fileFixCount = 0
    
    # =========================================================================
    # FIX 1: Replace incorrect use-trait patterns
    # =========================================================================
    
    # Pattern: (use-trait trait-name .trait-name.trait-name)
    # Fix to: (use-trait trait-name .all-traits.trait-name)
    
    $traitPatterns = @(
        @{Name="sip-010-ft-trait"; Old="\.sip-010-ft-trait\.sip-010-ft-trait"; New=".all-traits.sip-010-ft-trait"},
        @{Name="sip-009-nft-trait"; Old="\.sip-009-nft-trait\.sip-009-nft-trait"; New=".all-traits.sip-009-nft-trait"},
        @{Name="ownable-trait"; Old="\.ownable-trait\.ownable-trait"; New=".all-traits.ownable-trait"},
        @{Name="access-control-trait"; Old="\.access-control-trait\.access-control-trait"; New=".all-traits.access-control-trait"},
        @{Name="vault-trait"; Old="\.vault-trait\.vault-trait"; New=".all-traits.vault-trait"},
        @{Name="pool-trait"; Old="\.pool-trait\.pool-trait"; New=".all-traits.pool-trait"},
        @{Name="factory-trait"; Old="\.factory-trait\.factory-trait"; New=".all-traits.factory-trait"},
        @{Name="staking-trait"; Old="\.staking-trait\.staking-trait"; New=".all-traits.staking-trait"},
        @{Name="strategy-trait"; Old="\.strategy-trait\.strategy-trait"; New=".all-traits.strategy-trait"},
        @{Name="lending-system-trait"; Old="\.lending-system-trait\.lending-system-trait"; New=".all-traits.lending-system-trait"},
        @{Name="math-trait"; Old="\.math-trait\.math-trait"; New=".all-traits.math-trait"},
        @{Name="bond-trait"; Old="\.bond-trait\.bond-trait"; New=".all-traits.bond-trait"},
        @{Name="router-trait"; Old="\.router-trait\.router-trait"; New=".all-traits.router-trait"}
    )
    
    foreach ($pattern in $traitPatterns) {
        $regex = "\(use-trait\s+$($pattern.Name)\s+$($pattern.Old)\)"
        if ($content -match $regex) {
            $content = $content -replace $regex, "(use-trait $($pattern.Name) $($pattern.New))"
            $fileFixCount++
            Write-Host "  OK Fixed use-trait for $($pattern.Name)" -ForegroundColor Green
        }
    }
    
    # =========================================================================
    # FIX 2: Remove duplicate use-trait declarations
    # =========================================================================
    
    # Find and remove duplicate use-trait lines
    $lines = $content -split "`n"
    $seenTraits = @{}
    $newLines = @()
    $removedDuplicates = 0
    
    foreach ($line in $lines) {
        if ($line -match '^\s*\(use-trait\s+(\S+)\s+') {
            $traitName = $Matches[1]
            if ($seenTraits.ContainsKey($traitName)) {
                $removedDuplicates++
                Write-Host "  OK Removed duplicate use-trait for $traitName" -ForegroundColor Green
                continue
            }
            $seenTraits[$traitName] = $true
        }
        $newLines += $line
    }
    
    if ($removedDuplicates -gt 0) {
        $content = $newLines -join "`n"
        $fileFixCount += $removedDuplicates
    }
    
    # =========================================================================
    # FIX 3: Fix impl-trait statements
    # =========================================================================
    
    # Pattern: (impl-trait trait-name)
    # Fix to: (impl-trait .all-traits.trait-name)
    
    foreach ($pattern in $traitPatterns) {
        # Only fix if it's just the trait name without a path
        $regex = "\(impl-trait\s+$($pattern.Name)\s*\)"
        if ($content -match $regex) {
            $content = $content -replace $regex, "(impl-trait $($pattern.New))"
            $fileFixCount++
            Write-Host "  OK Fixed impl-trait for $($pattern.Name)" -ForegroundColor Green
        }
    }
    
    # =========================================================================
    # FIX 4: Remove any remaining quote syntax in trait references
    # =========================================================================
    
    if ($content -match "'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.\S+") {
        $pattern = @'
'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.([^\.\s]+)\.([^\.\s]+)
'@
        $replacement = '.all-traits.$2'
        $content = $content -replace $pattern, $replacement
        $fileFixCount++
        Write-Host "  OK Removed hardcoded principal quotes" -ForegroundColor Green
    }
    
    # =========================================================================
    # FIX 5: Fix contract references to use relative paths
    # =========================================================================
    
    # Fix references like .trait-registry to contracts that exist
    $contractRefs = @(
        @{Name="trait-registry"; Path=".trait-registry"},
        @{Name="circuit-breaker"; Path=".circuit-breaker"},
        @{Name="fee-manager"; Path=".fee-manager"}
    )
    
    # This is informational only - these need to be reviewed manually
    foreach ($ref in $contractRefs) {
        if ($content -match "\.$($ref.Name)\b") {
            Write-Host "  Info: Found reference to $($ref.Name) - verify this contract exists" -ForegroundColor DarkYellow
        }
    }
    
    # =========================================================================
    # Save changes if any fixes were made
    # =========================================================================
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $FileCount++
        $FixCount += $fileFixCount
        Write-Host "  Saved $fileFixCount fixes to $($file.Name)" -ForegroundColor Cyan
    } else {
        Write-Host "  No changes needed" -ForegroundColor DarkGray
    }
    
    Write-Host ""
}

# =========================================================================
# Summary Report
# =========================================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Files Processed: $($contractFiles.Count)" -ForegroundColor White
Write-Host "Files Modified: $FileCount" -ForegroundColor Green
Write-Host "Total Fixes Applied: $FixCount" -ForegroundColor Green
Write-Host ""

if ($FileCount -gt 0) {
    Write-Host "Trait import fixes complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Run: clarinet check" -ForegroundColor White
    Write-Host "2. Review error count reduction" -ForegroundColor White
    Write-Host "3. Commit changes with: git add -A; git commit -m 'fix: centralize trait imports to all-traits.clar'" -ForegroundColor White
} else {
    Write-Host "Info: No changes were needed" -ForegroundColor Yellow
}

Write-Host ""
