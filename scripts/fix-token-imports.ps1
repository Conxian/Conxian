# Script to fix imports in token contracts

# Get all token contract files
$tokenFiles = Get-ChildItem -Path ".\contracts\tokens\*.clar" -File

foreach ($file in $tokenFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $updated = $false
    
    # Fix import paths
    $patterns = @(
        @{ Pattern = '\(impl-trait \s*\.\)(?!traits\.)'; Replacement = '${1}traits.' },
        @{ Pattern = '\(use-trait \s*\w+ \s*\.\)(?!traits\.)'; Replacement = '${1}traits.' },
        @{ Pattern = '\.\./'; Replacement = '' },
        @{ Pattern = '\b\.\.\b'; Replacement = '' }
    )
    
    foreach ($pattern in $patterns) {
        if ($content -match $pattern.Pattern) {
            $content = $content -replace $pattern.Pattern, $pattern.Replacement
            $updated = $true
        }
    }
    
    if ($updated) {
        $content | Set-Content -Path $file.FullName -NoNewline
        Write-Host "Updated imports in $($file.Name)"
    }
}

Write-Host "Token import updates complete!"
