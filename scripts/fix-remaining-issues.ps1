# Fix Remaining Compilation Issues
# Purpose: Fix trait parameter syntax and other remaining errors
# Date: 2025-10-04

param(
    [switch]$DryRun = $false
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Conxian Remaining Issues Fix Script" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

$filesFixed = 0
$totalReplacements = 0

# Fix 1: Trait parameter syntax in all-traits.clar
Write-Host "📝 Fix 1: Trait parameter syntax in all-traits.clar" -ForegroundColor Cyan
$allTraitsPath = Join-Path $PSScriptRoot "..\contracts\traits\all-traits.clar"

if (Test-Path $allTraitsPath) {
    $content = Get-Content -Path $allTraitsPath -Raw
    $originalContent = $content
    
    # Replace (contract-of sip-010-ft-trait) with <sip-010-ft-trait>
    $content = $content -replace '\(contract-of sip-010-ft-trait\)', '<sip-010-ft-trait>'
    
    if ($content -ne $originalContent) {
        $matches = ([regex]::Matches($originalContent, '\(contract-of sip-010-ft-trait\)')).Count
        Write-Host "  ✅ Replaced $matches occurrences of (contract-of sip-010-ft-trait)" -ForegroundColor Green
        $totalReplacements += $matches
        $filesFixed++
        
        if (-not $DryRun) {
            Set-Content -Path $allTraitsPath -Value $content -NoNewline
        }
    }
}

# Fix 2: SBTC_MAINNET constant definitions
Write-Host "📝 Fix 2: SBTC constants in sbtc-*.clar files" -ForegroundColor Cyan
$sbtcFiles = @(
    "contracts\dex\sbtc-integration.clar",
    "contracts\dex\sbtc-lending-integration.clar",
    "contracts\dex\sbtc-oracle-adapter.clar"
)

foreach ($relPath in $sbtcFiles) {
    $filePath = Join-Path $PSScriptRoot "..\$relPath"
    if (Test-Path $filePath) {
        $content = Get-Content -Path $filePath -Raw
        $originalContent = $content
        
        # Fix constant definition
        $content = $content -replace "\(define-constant SBTC_MAINNET 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9\.sbtc-token\)", "(define-constant SBTC_MAINNET .sbtc-token)"
        
        if ($content -ne $originalContent) {
            Write-Host "  ✅ Fixed SBTC_MAINNET in $relPath" -ForegroundColor Green
            $filesFixed++
            
            if (-not $DryRun) {
                Set-Content -Path $filePath -Value $content -NoNewline
            }
        }
    }
}

# Fix 3: Malformed trait path in concentrated-liquidity-pool.clar
Write-Host "📝 Fix 3: Math lib trait path in concentrated-liquidity-pool.clar" -ForegroundColor Cyan
$poolPath = Join-Path $PSScriptRoot "..\contracts\pools\concentrated-liquidity-pool.clar"

if (Test-Path $poolPath) {
    $content = Get-Content -Path $poolPath -Raw
    $originalContent = $content
    
    # Fix malformed trait path
    $content = $content -replace "\(use-trait math-lib-concentrated 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.math\.math-lib-concentrated\)", "(use-trait math-trait .all-traits.math-trait)"
    
    if ($content -ne $originalContent) {
        Write-Host "  ✅ Fixed math-lib trait reference" -ForegroundColor Green
        $filesFixed++
        
        if (-not $DryRun) {
            Set-Content -Path $poolPath -Value $content -NoNewline
        }
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Files Fixed: $filesFixed" -ForegroundColor Green
Write-Host "Total Replacements: $totalReplacements" -ForegroundColor Yellow
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN COMPLETE" -ForegroundColor Yellow
} else {
    Write-Host "✅ FIXES APPLIED" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Run 'clarinet check' to verify (expect 6 false positives)" -ForegroundColor White
    Write-Host "2. Review changes with 'git diff'" -ForegroundColor White
    Write-Host "3. Commit changes if successful" -ForegroundColor White
}

Write-Host "==================================================" -ForegroundColor Cyan

exit 0
