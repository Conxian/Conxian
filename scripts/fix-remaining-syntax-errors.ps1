# =============================================================================
# FIX REMAINING SYNTAX ERRORS - FINAL CLEANUP
# =============================================================================
# Purpose: Fix remaining 17 compilation errors for testnet-ready status
# Author: Cascade AI (CTO Handover - Final Prep)
# Date: 2025-10-04
# =============================================================================

param([switch]$DryRun = $false)

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "FINAL SYNTAX ERRORS FIX" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""

$filesFixed = 0
$totalChanges = 0

# Fix 1: Remove multi-line string literal in concentrated-liquidity-pool.clar
Write-Host "📝 Fix 1: String literal in concentrated-liquidity-pool.clar" -ForegroundColor Cyan
$poolPath = "contracts\pools\concentrated-liquidity-pool.clar"

if (Test-Path $poolPath) {
    $content = Get-Content -Path $poolPath -Raw
    $originalContent = $content
    
    # Convert multi-line string to comment
    $content = $content -replace '"Retrieves the current reserves \(balances\) of token-x and token-y held by a specific concentrated liquidity pool\.\s+@param pool-id The ID of the pool to query\.\s+@returns An `\(ok \{reserve-a: uint, reserve-b: uint\}\)` result containing the current balances of token-x and token-y, or an error if the pool does not exist\.', ';; Retrieves the current reserves (balances) of token-x and token-y held by a specific concentrated liquidity pool.
  ;; @param pool-id The ID of the pool to query.
  ;; @returns An (ok {reserve-a: uint, reserve-b: uint}) result containing the current balances of token-x and token-y, or an error if the pool does not exist.'
    
    if ($content -ne $originalContent) {
        Write-Host "  ✅ Fixed string literal" -ForegroundColor Green
        $filesFixed++
        $totalChanges++
        if (-not $DryRun) { Set-Content -Path $poolPath -Value $content -NoNewline }
    }
}

# Fix 2: Remove <mcsymbol> tags from concentrated-liquidity-pool.clar
Write-Host "📝 Fix 2: Remove mcsymbol tags from concentrated-liquidity-pool.clar" -ForegroundColor Cyan
$clpPath = "contracts\concentrated-liquidity-pool.clar"

if (Test-Path $clpPath) {
    $content = Get-Content -Path $clpPath -Raw
    $originalContent = $content
    
    # Remove mcsymbol tags completely
    $content = $content -replace '<mcsymbol[^>]+>([^<]+)</mcsymbol>', '$1'
    $content = $content -replace '<mcsymbol[^>]+></mcsymbol>', 'sip-010-ft-trait'
    
    if ($content -ne $originalContent) {
        Write-Host "  ✅ Removed mcsymbol tags" -ForegroundColor Green
        $filesFixed++
        $totalChanges += ([regex]::Matches($originalContent, '<mcsymbol')).Count
        if (-not $DryRun) { Set-Content -Path $clpPath -Value $content -NoNewline }
    }
}

# Fix 3: Remove <mcsymbol> tags from dex-factory.clar
Write-Host "📝 Fix 3: Remove mcsymbol tags from dex-factory.clar" -ForegroundColor Cyan
$factoryPath = "contracts\dex\dex-factory.clar"

if (Test-Path $factoryPath) {
    $content = Get-Content -Path $factoryPath -Raw
    $originalContent = $content
    
    $content = $content -replace '<mcsymbol[^>]+>([^<]+)</mcsymbol>', '$1'
    $content = $content -replace '<mcsymbol[^>]+></mcsymbol>', 'sip-010-ft-trait'
    
    if ($content -ne $originalContent) {
        Write-Host "  ✅ Removed mcsymbol tags" -ForegroundColor Green
        $filesFixed++
        $totalChanges += ([regex]::Matches($originalContent, '<mcsymbol')).Count
        if (-not $DryRun) { Set-Content -Path $factoryPath -Value $content -NoNewline }
    }
}

# Fix 4: Search for any remaining string issues
Write-Host "📝 Fix 4: Searching for remaining syntax issues" -ForegroundColor Cyan
$contractsPath = "contracts"
$clarFiles = Get-ChildItem -Path $contractsPath -Filter "*.clar" -Recurse

foreach ($file in $clarFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    $changed = $false
    
    # Remove any remaining mcsymbol tags
    if ($content -match '<mcsymbol') {
        $content = $content -replace '<mcsymbol[^>]+>([^<]+)</mcsymbol>', '$1'
        $content = $content -replace '<mcsymbol[^>]+></mcsymbol>', 'sip-010-ft-trait'
        $changed = $true
    }
    
    if ($changed -and $content -ne $originalContent) {
        Write-Host "  ✅ $($file.Name)" -ForegroundColor Green
        $filesFixed++
        $totalChanges++
        if (-not $DryRun) { Set-Content -Path $file.FullName -Value $content -NoNewline }
    }
}

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Files Fixed: $filesFixed" -ForegroundColor $(if ($filesFixed -gt 0) { 'Green' } else { 'Yellow' })
Write-Host "Total Changes: $totalChanges" -ForegroundColor $(if ($totalChanges -gt 0) { 'Green' } else { 'Yellow' })

if ($DryRun) {
    Write-Host ""
    Write-Host "🔍 DRY RUN - No files modified" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "✅ FIXES APPLIED" -ForegroundColor Green
}

Write-Host "=============================================================================" -ForegroundColor Cyan
exit 0
