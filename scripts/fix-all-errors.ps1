# COMPREHENSIVE FIX SCRIPT
# Fixes all 3 categories of errors:
# 1. CRLF -> LF conversion
# 2. Trait reference syntax  
# 3. Specific contract issues

Write-Host "Starting comprehensive fix..." -ForegroundColor Cyan

# STEP 1: Fix CRLF -> LF for ALL .clar files
Write-Host "`n[1/3] Converting CRLF to LF..." -ForegroundColor Yellow
$clarFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse
$crlfCount = 0
foreach ($file in $clarFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "`r`n") {
        $content = $content -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        $crlfCount++
    }
}
Write-Host "Fixed $crlfCount files (CRLF -> LF)" -ForegroundColor Green

# STEP 2: Fix trait references - remove hyphens from contract names in use-trait
Write-Host "`n[2/3] Fixing trait reference syntax..." -ForegroundColor Yellow
$traitFixes = @{
    # Fix numbered prefix pattern (e.g., .02-core-protocol -> .core-protocol)
    '\.sip-standards\.' = '.sip-standards.'  # Already correct
    '\.core-protocol\.rbac-trait-trait' = '.core-protocol.rbac-trait'
    '\.core-protocol\.02-core-protocol\.rbac-trait-trait' = '.core-protocol.rbac-trait'
    '\.trait-sip-standards\.' = '.sip-standards.'
    '\.trait-core-protocol\.' = '.core-protocol.'
    '\.base-traits\.' = '.core-protocol.'  # Base traits should use core-protocol
}

$traitCount = 0
foreach ($file in $clarFiles) {
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    foreach ($pattern in $traitFixes.Keys) {
        $replacement = $traitFixes[$pattern]
        if ($content -match [regex]::Escape($pattern)) {
            $content = $content -replace [regex]::Escape($pattern), $replacement
            $modified = $true
        }
    }
    
    if ($modified) {
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        $traitCount++
    }
}
Write-Host "Fixed $traitCount files (trait references)" -ForegroundColor Green

# STEP 3: Fix specific contract issues
Write-Host "`n[3/3] Fixing specific syntax issues..." -ForegroundColor Yellow

# Fix roles.clar - wrong function signature
$rolesPath = "contracts/access/roles.clar"
if (Test-Path $rolesPath) {
    $content = Get-Content $rolesPath -Raw
    # The trait expects (role principal) but implementation has (principal role)
    $content = $content -replace '\(grant-role \(who principal\) \(role \(string-ascii 32\)\)\)', '(grant-role (role (string-ascii 32)) (who principal))'
    $content = $content -replace '\(revoke-role \(who principal\) \(role \(string-ascii 32\)\)\)', '(revoke-role (role (string-ascii 32)) (who principal))'
    $content = $content -replace '\(has-role \(who principal\) \(role \(string-ascii 32\)\)\)', '(has-role (role (string-ascii 32)) (who principal))'
    [System.IO.File]::WriteAllText($rolesPath, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  - Fixed roles.clar function signatures" -ForegroundColor Green
}

Write-Host "`n✅ Comprehensive fix complete!" -ForegroundColor Green
Write-Host "`nRun 'clarinet check' to verify fixes" -ForegroundColor Cyan
