$traitMappings = @{
    'sip-010-trait' = 'sip-010-ft-trait'
    'sip009-nft-trait' = 'sip-009-nft-trait'
}

$files = Get-ChildItem -Path 'c:\Users\bmokoka\anyachainlabs\Conxian\contracts' -Recurse -Filter '*.clar' | 
          Where-Object { $_.FullName -notlike '*\traits\all-traits.clar' -and $_.FullName -notlike '*\traits\*' }

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content

    # Replace trait names
    foreach ($key in $traitMappings.Keys) {
        $value = $traitMappings[$key]
        $content = $content -replace $key, $value
    }

    # Update use-trait statements to use all-traits contract
    $content = $content -replace '\(use-trait\s+''([^'']+)''\s+''([^'']+)\.([^'']+)''\)', '(use-trait ''$2.all-traits.$3'''

    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Updated $($file.FullName)"
    }
}
