# FINAL FIX: Rename trait files to match Clarinet.toml contract names
# This resolves the fundamental mismatch causing all parsing errors

Write-Host "Renaming trait files to match contract names..." -ForegroundColor Cyan

$renames = @{
    "contracts/traits/01-sip-standards.clar" = "contracts/traits/sip-standards.clar"
    "contracts/traits/02-core-protocol.clar" = "contracts/traits/core-protocol.clar"
    "contracts/traits/03-defi-primitives.clar" = "contracts/traits/defi-primitives.clar"
    "contracts/traits/04-dimensional.clar" = "contracts/traits/dimensional-traits.clar"
    "contracts/traits/05-oracle-pricing.clar" = "contracts/traits/oracle-pricing.clar"
    "contracts/traits/06-risk-management.clar" = "contracts/traits/risk-management.clar"
    "contracts/traits/07-cross-chain.clar" = "contracts/traits/cross-chain-traits.clar"
    "contracts/traits/08-governance.clar" = "contracts/traits/governance-traits.clar"
    "contracts/traits/09-security-monitoring.clar" = "contracts/traits/security-monitoring.clar"
    "contracts/traits/10-math-utilities.clar" = "contracts/traits/math-utilities.clar"
    "contracts/traits/errors.clar" = "contracts/traits/trait-errors.clar"
}

$renamed = 0
foreach ($old in $renames.Keys) {
    $new = $renames[$old]
    if (Test-Path $old) {
        # Convert CRLF to LF while renaming
        $content = Get-Content $old -Raw
        $content = $content -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($new, $content, [System.Text.UTF8Encoding]::new($false))
        Remove-Item $old
        Write-Host "  Renamed: $old -> $new" -ForegroundColor Green
        $renamed++
    }
}

Write-Host "`n✅ Renamed $renamed trait files" -ForegroundColor Green
Write-Host "Updating Clarinet.toml paths..." -ForegroundColor Yellow

# Update Clarinet.toml paths
$clarinetPath = "Clarinet.toml"
$content = Get-Content $clarinetPath -Raw
$content = $content -replace 'path = "contracts/traits/01-sip-standards\.clar"', 'path = "contracts/traits/sip-standards.clar"'
$content = $content -replace 'path = "contracts/traits/02-core-protocol\.clar"', 'path = "contracts/traits/core-protocol.clar"'
$content = $content -replace 'path = "contracts/traits/03-defi-primitives\.clar"', 'path = "contracts/traits/defi-primitives.clar"'
$content = $content -replace 'path = "contracts/traits/04-dimensional\.clar"', 'path = "contracts/traits/dimensional-traits.clar"'
$content = $content -replace 'path = "contracts/traits/05-oracle-pricing\.clar"', 'path = "contracts/traits/oracle-pricing.clar"'
$content = $content -replace 'path = "contracts/traits/06-risk-management\.clar"', 'path = "contracts/traits/risk-management.clar"'
$content = $content -replace 'path = "contracts/traits/07-cross-chain\.clar"', 'path = "contracts/traits/cross-chain-traits.clar"'
$content = $content -replace 'path = "contracts/traits/08-governance\.clar"', 'path = "contracts/traits/governance-traits.clar"'
$content = $content -replace 'path = "contracts/traits/09-security-monitoring\.clar"', 'path = "contracts/traits/security-monitoring.clar"'
$content = $content -replace 'path = "contracts/traits/10-math-utilities\.clar"', 'path = "contracts/traits/math-utilities.clar"'
$content = $content -replace 'path = "contracts/traits/errors\.clar"', 'path = "contracts/traits/trait-errors.clar"'
[System.IO.File]::WriteAllText($clarinetPath, $content, [System.Text.UTF8Encoding]::new($false))

Write-Host "✅ Updated Clarinet.toml" -ForegroundColor Green
Write-Host "`n🎯 This should resolve the trait mismatch causing parser errors" -ForegroundColor Cyan
