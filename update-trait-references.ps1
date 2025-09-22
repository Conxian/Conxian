# Update trait references in all token contracts
$tokenContracts = @(
    "cxd-token.clar",
    "cxlp-token.clar",
    "cxvg-token.clar",
    "cxtr-token.clar",
    "cxs-token.clar"
)

$traitUpdates = @{
    # Pattern = Replacement
    'use-trait sip-010-ft-trait .sip-010-ft-trait' = 'use-trait ft-trait .sip-010-ft-trait'
    'use-trait ownable-trait .ownable-trait' = 'use-trait ownable .ownable-trait'
    'impl-trait ''sip-010-ft-trait''' = 'impl-trait ''.sip-010-ft-trait'''
    'impl-trait ''ownable-trait''' = 'impl-trait ''.ownable-trait'''
}

foreach ($contract in $tokenContracts) {
    $path = "contracts/tokens/$contract"
    if (Test-Path $path) {
        Write-Host "Updating $path..."
        $content = Get-Content $path -Raw
        
        # Apply replacements
        foreach ($update in $traitUpdates.GetEnumerator()) {
            $content = $content -replace [regex]::Escape($update.Key), $update.Value
        }
        
        # Save the updated content
        $content | Set-Content $path -NoNewline
        Write-Host "Updated $path"
    } else {
        Write-Host "Skipping $path (not found)"
    }
}

Write-Host "Trait reference update complete!"
