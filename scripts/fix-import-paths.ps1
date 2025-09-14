# Script to fix import paths in all .clar files

# Get all .clar files
$files = Get-ChildItem -Path . -Recurse -Filter "*.clar" -File

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $updated = $false
    
    # Fix double paths
    $patterns = @(
        @{ Pattern = '\.governance\.governance\.'; Replacement = '.governance.' },
        @{ Pattern = '\.traits\.traits\.'; Replacement = '.traits.' },
        @{ Pattern = '\.dex\.dex\.'; Replacement = '.dex.' },
        @{ Pattern = '\.tokens\.tokens\.'; Replacement = '.tokens.' },
        @{ Pattern = '\.lib\.lib\.'; Replacement = '.lib.' },
        @{ Pattern = '\.mocks\.mocks\.'; Replacement = '.mocks.' }
    )
    
    foreach ($pattern in $patterns) {
        if ($content -match $pattern.Pattern) {
            $content = $content -replace $pattern.Pattern, $pattern.Replacement
            $updated = $true
        }
    }
    
    if ($updated) {
        $content | Set-Content -Path $file.FullName -NoNewline
        Write-Host "Fixed import paths in $($file.FullName)"
    }
}

Write-Host "Import path fixes complete!"
