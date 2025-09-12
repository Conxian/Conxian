# Script to update contract imports for new directory structure

# Import mappings
$importMappings = @{
    '\.access-control-trait\.' = '.traits.access-control-trait.'
    '\.sip-010-trait\.' = '.traits.sip-010-trait.'
    '\.ownable-trait\.' = '.traits.ownable-trait.'
    '\.standard-constants-trait\.' = '.traits.standard-constants-trait.'
    '\.access-control\.' = '.governance.access-control.'
    '\.governance\.' = '.governance.'
    '\.dex\.' = '.dex.'
    '\.tokens\.' = '.tokens.'
}

# Get all .clar files
$files = Get-ChildItem -Path . -Recurse -Filter "*.clar" -File

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $updated = $false
    
    foreach ($mapping in $importMappings.GetEnumerator()) {
        if ($content -match $mapping.Key) {
            $content = $content -replace $mapping.Key, $mapping.Value
            $updated = $true
        }
    }
    
    if ($updated) {
        $content | Set-Content -Path $file.FullName -NoNewline
        Write-Host "Updated imports in $($file.FullName)"
    }
}

Write-Host "Import updates complete!"
