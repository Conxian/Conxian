# =============================================================================
# FIX ALL HARDCODED PRINCIPALS - FINAL PREPARATION
# =============================================================================
# Purpose: Remove all 26 hardcoded principal references for deployment
# Author: Cascade AI (CTO Handover - Final Prep)
# Date: 2025-10-04
# Mode: Auto-run approved by CTO
# =============================================================================

param(
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "CONXIAN FINAL PREPARATION - HARDCODED PRINCIPALS FIX" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Target: Fix 26 contracts with hardcoded principals" -ForegroundColor Yellow
Write-Host "🔧 Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE EXECUTION' })" -ForegroundColor Yellow
Write-Host ""

$ErrorActionPreference = "Stop"
$filesFixed = 0
$totalReplacements = 0
$errors = @()

# Define the hardcoded principal to find
$HARDCODED_PRINCIPAL = "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"

# List of files with hardcoded principals (from comprehensive analysis)
$filesToFix = @(
    "contracts\dimensional\concentrated-liquidity-pool-v2.clar",
    "contracts\dimensional\concentrated-liquidity-pool.clar", 
    "contracts\pools\concentrated-liquidity-pool.clar",
    "contracts\dex\enterprise-loan-manager.clar",
    "contracts\oracle\dimensional-oracle.clar",
    "contracts\governance\access-control.clar",
    "contracts\pools\tiered-pools.clar",
    "contracts\tiered-pools.clar",
    "contracts\dex\enhanced-yield-strategy.clar",
    "contracts\dex\legacy-adapter.clar",
    "contracts\dex\oracle.clar",
    "contracts\dex\sbtc-flash-loan-extension.clar",
    "contracts\dex\vault.clar",
    "contracts\dimensional\dim-registry.clar",
    "contracts\dimensional\dim-revenue-adapter.clar",
    "contracts\governance\governance-signature-verifier.clar",
    "contracts\governance\lending-protocol-governance.clar",
    "contracts\libraries\concentrated-math.clar",
    "contracts\mocks\mock-dao.clar",
    "contracts\mocks\mock-token.clar",
    "contracts\oracle\oracle-aggregator-v2.clar",
    "contracts\tokens\cxd-token.clar",
    "contracts\tokens\cxlp-token.clar",
    "contracts\tokens\cxs-token.clar",
    "contracts\tokens\cxtr-token.clar",
    "contracts\tokens\cxvg-token.clar"
)

Write-Host "📋 Processing $($filesToFix.Count) files..." -ForegroundColor Cyan
Write-Host ""

foreach ($relativeFile in $filesToFix) {
    $filePath = Join-Path $PSScriptRoot "..\$relativeFile"
    
    if (-not (Test-Path $filePath)) {
        Write-Host "⚠️  File not found: $relativeFile" -ForegroundColor Yellow
        $errors += "File not found: $relativeFile"
        continue
    }
    
    try {
        $content = Get-Content -Path $filePath -Raw
        $originalContent = $content
        $fileReplacements = 0
        
        # Pattern 1: ST3...contract-name -> .contract-name
        # Matches: ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.contract-name
        $pattern1 = "$HARDCODED_PRINCIPAL\.([a-z0-9-]+)"
        $matches1 = [regex]::Matches($content, $pattern1)
        if ($matches1.Count -gt 0) {
            $content = $content -replace $pattern1, '.$1'
            $fileReplacements += $matches1.Count
            
            if ($Verbose) {
                Write-Host "  Pattern 1: Fixed $($matches1.Count) references" -ForegroundColor Gray
                foreach ($match in $matches1) {
                    Write-Host "    - $($match.Value) → .$($match.Groups[1].Value)" -ForegroundColor DarkGray
                }
            }
        }
        
        # Pattern 2: ST3...path.contract-name -> .path.contract-name
        # Matches: ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.path.contract-name
        $pattern2 = "$HARDCODED_PRINCIPAL\.([a-z0-9-]+)\.([a-z0-9-]+)"
        $matches2 = [regex]::Matches($content, $pattern2)
        if ($matches2.Count -gt 0) {
            $content = $content -replace $pattern2, '.$1.$2'
            $fileReplacements += $matches2.Count
            
            if ($Verbose) {
                Write-Host "  Pattern 2: Fixed $($matches2.Count) nested references" -ForegroundColor Gray
            }
        }
        
        # Pattern 3: Contract calls with ST3 in string literals (edge case)
        $pattern3 = "`"$HARDCODED_PRINCIPAL\.([a-z0-9-]+)`""
        $matches3 = [regex]::Matches($content, $pattern3)
        if ($matches3.Count -gt 0) {
            $content = $content -replace $pattern3, '`".$1`"'
            $fileReplacements += $matches3.Count
            
            if ($Verbose) {
                Write-Host "  Pattern 3: Fixed $($matches3.Count) string literal references" -ForegroundColor Gray
            }
        }
        
        if ($content -ne $originalContent) {
            Write-Host "✅ $relativeFile" -ForegroundColor Green
            Write-Host "   Replacements: $fileReplacements" -ForegroundColor Gray
            
            if (-not $DryRun) {
                Set-Content -Path $filePath -Value $content -NoNewline
            }
            
            $filesFixed++
            $totalReplacements += $fileReplacements
        } else {
            Write-Host "✓  $relativeFile (no changes needed)" -ForegroundColor DarkGray
        }
        
    } catch {
        Write-Host "❌ Error processing $relativeFile" -ForegroundColor Red
        Write-Host "   $_" -ForegroundColor Red
        $errors += "Error in ${relativeFile}: $_"
    }
}

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Files Processed: $($filesToFix.Count)" -ForegroundColor White
Write-Host "Files Modified: $filesFixed" -ForegroundColor $(if ($filesFixed -gt 0) { 'Green' } else { 'Yellow' })
Write-Host "Total Replacements: $totalReplacements" -ForegroundColor $(if ($totalReplacements -gt 0) { 'Green' } else { 'Yellow' })
Write-Host "Errors: $($errors.Count)" -ForegroundColor $(if ($errors.Count -gt 0) { 'Red' } else { 'Green' })

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  ERRORS ENCOUNTERED:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "   - $error" -ForegroundColor Red
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "🔍 DRY RUN COMPLETE - No files were modified" -ForegroundColor Yellow
    Write-Host "   Run without -DryRun flag to apply changes" -ForegroundColor Yellow
} else {
    Write-Host ""
    if ($filesFixed -gt 0) {
        Write-Host "✅ CHANGES APPLIED SUCCESSFULLY" -ForegroundColor Green
        Write-Host "   Next step: Run 'clarinet check' to validate" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  NO CHANGES NEEDED - All files are already clean" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan

# Exit with appropriate code
if ($errors.Count -gt 0) {
    exit 1
} else {
    exit 0
}
