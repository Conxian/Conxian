# Fix all use-trait statements to reference correct modular trait files
# This script updates all 234 use-trait statements across the codebase

$replacements = @{
    # Main numbered trait patterns
    '\.01-sip-standards\.' = '.sip-standards.'
    '\.02-core-protocol\.02-core-protocol\.' = '.core-protocol.'
    '\.02-core-protocol\.' = '.core-protocol.'
    '\.03-defi-primitives\.' = '.defi-primitives.'
    '\.04-dimensional\.' = '.dimensional-traits.'
    '\.05-oracle-pricing\.' = '.oracle-pricing.'
    '\.06-risk-management\.' = '.risk-management.'
    '\.07-cross-chain\.' = '.cross-chain-traits.'
    '\.08-governance\.' = '.governance-traits.'
    '\.09-security-monitoring\.' = '.security-monitoring.'
    '\.10-math-utilities\.' = '.math-utilities.'
    
    # Individual trait file patterns (non-modular references)
    '\.governance-token-trait' = '.governance-traits.governance-token-trait'
    '\.trait-sip-standards\.' = '.sip-standards.'
    '\.trait-dimensional\.' = '.dimensional-traits.'
    '\.pooling-traits\.' = '.defi-primitives.'
    '\.dimensional-traits\.dim' = '.dimensional-traits.dimensional'
}

$files = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse

$totalUpdated = 0

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    $fileUpdated = $false
    
    foreach ($old in $replacements.Keys) {
        $new = $replacements[$old]
        if ($content -match $old) {
            $content = $content -replace [regex]::Escape($old), $new
            $fileUpdated = $true
        }
    }
    
    if ($fileUpdated) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Updated: $($file.FullName)"
        $totalUpdated++
    }
}

Write-Host "`nTotal files updated: $totalUpdated"
Write-Host "Trait system migration complete!"
