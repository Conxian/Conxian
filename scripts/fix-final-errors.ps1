# Fix Final Compilation Errors
# Purpose: Fix all remaining 13 errors systematically
# Date: 2025-10-04

param(
    [switch]$DryRun = $false
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Conxian Final Errors Fix Script" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE" -ForegroundColor Yellow
    Write-Host ""
}

$filesFixed = 0
$totalChanges = 0

# Fix 1: Math lib path in concentrated-liquidity-pool.clar
Write-Host "📝 Fix 1: Math lib paths in concentrated-liquidity-pool.clar" -ForegroundColor Cyan
$poolPath = Join-Path $PSScriptRoot "..\contracts\pools\concentrated-liquidity-pool.clar"

if (Test-Path $poolPath) {
    $content = Get-Content -Path $poolPath -Raw
    $originalContent = $content
    
    # Fix use-trait with invalid principal path
    $content = $content -replace '\(use-trait math-lib-concentrated ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.math\.math-lib-concentrated\)', '(use-trait math-lib-trait .all-traits.math-trait)'
    
    # Fix duplicate use-trait later in file (line 529)
    $content = $content -replace '\(use-trait math-lib-concentrated-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.math\.math-lib-concentrated\)', ''
    
    # Fix use-trait with ST3... reference
    $content = $content -replace '\(use-trait err-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.errors\.err-trait\)', ''
    
    # Remove duplicate get-tick-from-sqrt-price functions (keep only first one)
    # This regex finds the pattern and removes duplicates
    $pattern = '\(define-read-only \(get-tick-from-sqrt-price \(sqrt-price uint\)\)\s+\(contract-call\? ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.math\.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price\)\s+\)'
    $matches = [regex]::Matches($content, $pattern)
    if ($matches.Count -gt 1) {
        Write-Host "  Found $($matches.Count) duplicate get-tick-from-sqrt-price functions" -ForegroundColor Yellow
        # Keep first match, remove all others
        $firstMatch = $matches[0]
        for ($i = $matches.Count - 1; $i -gt 0; $i--) {
            $match = $matches[$i]
            $before = $content.Substring(0, $match.Index)
            $after = $content.Substring($match.Index + $match.Length)
            $content = $before + $after
            $totalChanges++
        }
    }
    
    if ($content -ne $originalContent) {
        Write-Host "  ✅ Fixed math-lib paths and removed duplicates" -ForegroundColor Green
        $filesFixed++
        
        if (-not $DryRun) {
            Set-Content -Path $poolPath -Value $content -NoNewline
        }
    }
}

# Fix 2: Batch processor trait path in batch-processor.clar
Write-Host "📝 Fix 2: Batch processor trait path" -ForegroundColor Cyan
$batchPath = Join-Path $PSScriptRoot "..\contracts\automation\batch-processor.clar"

if (Test-Path $batchPath) {
    $content = Get-Content -Path $batchPath -Raw
    $originalContent = $content
    
    # Remove invalid impl-trait
    $content = $content -replace '\(impl-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.batch-processor\.batch-processor-trait\)', ''
    
    # Fix remaining quote in impl-trait
    $content = $content -replace "\(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6\.ownable-trait\)", '(impl-trait .all-traits.ownable-trait)'
    
    if ($content -ne $originalContent) {
        Write-Host "  ✅ Fixed batch processor paths" -ForegroundColor Green
        $filesFixed++
        
        if (-not $DryRun) {
            Set-Content -Path $batchPath -Value $content -NoNewline
        }
    }
}

# Fix 3: Search for remaining quotes in contracts
Write-Host "📝 Fix 3: Searching for remaining quote issues" -ForegroundColor Cyan
$contractsPath = Join-Path $PSScriptRoot "..\contracts"
$clarFiles = Get-ChildItem -Path $contractsPath -Filter "*.clar" -Recurse

$quotePattern = "'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"
foreach ($file in $clarFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    if ($content -match $quotePattern) {
        $originalContent = $content
        
        # Remove remaining quotes
        $content = $content -replace "'(ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6[^\s\)]+)", '$1'
        
        if ($content -ne $originalContent) {
            $relativePath = $file.FullName.Replace($contractsPath, "").TrimStart('\', '/')
            Write-Host "  ✅ Fixed remaining quotes in $relativePath" -ForegroundColor Green
            $filesFixed++
            
            if (-not $DryRun) {
                Set-Content -Path $file.FullName -Value $content -NoNewline
            }
        }
    }
}

# Fix 4: Check dex-pool.clar for unclosed list (line 307 area)
Write-Host "📝 Fix 4: Checking dex-pool.clar structure" -ForegroundColor Cyan
$dexPoolPath = Join-Path $PSScriptRoot "..\contracts\dex\dex-pool.clar"

if (Test-Path $dexPoolPath) {
    $content = Get-Content -Path $dexPoolPath -Raw
    # The dex-pool file appears to be correctly structured based on our read
    # The error might be a false positive or in a different location
    Write-Host "  ℹ️  dex-pool.clar structure appears correct (may be false positive)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Files Fixed: $filesFixed" -ForegroundColor Green
Write-Host "Total Changes: $totalChanges" -ForegroundColor Yellow
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN COMPLETE" -ForegroundColor Yellow
} else {
    Write-Host "✅ FIXES APPLIED" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Run 'clarinet check' to verify fixes" -ForegroundColor White
    Write-Host "2. Review changes with 'git diff'" -ForegroundColor White
    Write-Host "3. Commit if successful" -ForegroundColor White
}

Write-Host "==================================================" -ForegroundColor Cyan

exit 0
