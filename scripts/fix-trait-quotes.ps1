# Fix Trait Quote Syntax - Automated Correction Script
# Purpose: Remove invalid single quotes from trait imports in all .clar files
# Date: 2025-10-04
# Issue: CONX-001 - Quote syntax in 62+ trait imports

param(
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Conxian Trait Quote Syntax Fix Script" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

$contractsPath = Join-Path $PSScriptRoot "..\contracts"
$filesProcessed = 0
$filesModified = 0
$totalReplacements = 0
$errors = @()

# Get all .clar files
$clarFiles = Get-ChildItem -Path $contractsPath -Filter "*.clar" -Recurse

Write-Host "📁 Found $($clarFiles.Count) .clar files to process" -ForegroundColor Green
Write-Host ""

foreach ($file in $clarFiles) {
    $filesProcessed++
    $relativePath = $file.FullName.Replace($contractsPath, "").TrimStart('\', '/')
    
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $originalContent = $content
        $fileReplacements = 0
        
        # Pattern 1: Remove quotes from use-trait statements
        # Before: (use-trait sip-010-ft-trait 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.all-traits.sip-010-ft-trait')
        # After:  (use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
        $pattern1 = "'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.all-traits\."
        $replacement1 = ".all-traits."
        if ($content -match $pattern1) {
            $content = $content -replace $pattern1, $replacement1
            $matches1 = ([regex]::Matches($originalContent, $pattern1)).Count
            $fileReplacements += $matches1
            if ($Verbose) {
                Write-Host "  🔧 Pattern 1: $matches1 replacements (use-trait full path)" -ForegroundColor Gray
            }
        }
        
        # Pattern 2: Remove quotes and trailing quote from use-trait
        # Before: (use-trait bond-trait 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.all-traits.bond-trait')
        # After:  (use-trait bond-trait .all-traits.bond-trait)
        $pattern2 = "'\)"
        $replacement2 = ")"
        if ($content -match $pattern2) {
            $matches2 = ([regex]::Matches($content, $pattern2)).Count
            $content = $content -replace $pattern2, $replacement2
            $fileReplacements += $matches2
            if ($Verbose) {
                Write-Host "  🔧 Pattern 2: $matches2 replacements (trailing quotes)" -ForegroundColor Gray
            }
        }
        
        # Pattern 3: Remove quotes from impl-trait statements
        # Before: (impl-trait 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.all-traits.ownable-trait)
        # After:  (impl-trait .all-traits.ownable-trait)
        $pattern3 = "\(impl-trait 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.all-traits\."
        $replacement3 = "(impl-trait .all-traits."
        if ($content -match $pattern3) {
            $matches3 = ([regex]::Matches($originalContent, $pattern3)).Count
            $content = $content -replace $pattern3, $replacement3
            $fileReplacements += $matches3
            if ($Verbose) {
                Write-Host "  🔧 Pattern 3: $matches3 replacements (impl-trait full path)" -ForegroundColor Gray
            }
        }
        
        # Pattern 4: Remove quotes from other principal references
        # Before: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.errors.err-trait
        # After:  STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.errors.err-trait
        $pattern4 = "'(STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ\.[a-z0-9-]+\.)"
        $replacement4 = '$1'
        if ($content -match $pattern4) {
            $matches4 = ([regex]::Matches($originalContent, $pattern4)).Count
            $content = $content -replace $pattern4, $replacement4
            $fileReplacements += $matches4
            if ($Verbose) {
                Write-Host "  🔧 Pattern 4: $matches4 replacements (other principals)" -ForegroundColor Gray
            }
        }
        
        # Check if file was modified
        if ($content -ne $originalContent) {
            $filesModified++
            $totalReplacements += $fileReplacements
            
            Write-Host "✅ $relativePath" -ForegroundColor Green
            Write-Host "   Replacements: $fileReplacements" -ForegroundColor Gray
            
            if (-not $DryRun) {
                Set-Content -Path $file.FullName -Value $content -NoNewline
            }
        } else {
            if ($Verbose) {
                Write-Host "⚪ $relativePath (no changes)" -ForegroundColor DarkGray
            }
        }
        
    } catch {
        $errors += @{
            File = $relativePath
            Error = $_.Exception.Message
        }
        Write-Host "❌ ERROR: $relativePath" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Files Processed:  $filesProcessed" -ForegroundColor White
Write-Host "Files Modified:   $filesModified" -ForegroundColor Green
Write-Host "Total Replacements: $totalReplacements" -ForegroundColor Yellow
Write-Host "Errors:           $($errors.Count)" -ForegroundColor $(if ($errors.Count -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "ERRORS ENCOUNTERED:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $($error.File): $($error.Error)" -ForegroundColor Red
    }
    Write-Host ""
}

if ($DryRun) {
    Write-Host "🔍 DRY RUN COMPLETE - No files were modified" -ForegroundColor Yellow
    Write-Host "   Run without -DryRun to apply changes" -ForegroundColor Yellow
} else {
    Write-Host "✅ CHANGES APPLIED SUCCESSFULLY" -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "1. Run 'clarinet check' to verify compilation" -ForegroundColor White
    Write-Host "2. Review changes with 'git diff'" -ForegroundColor White
    Write-Host "3. Run tests with 'npm test'" -ForegroundColor White
    Write-Host "4. Commit changes if successful" -ForegroundColor White
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan

# Exit with error code if there were errors
if ($errors.Count -gt 0) {
    exit 1
} else {
    exit 0
}
