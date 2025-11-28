# Remove ALL numbered prefixes from trait references
# Pattern: .01-name -> .name, .02-name -> .name, etc.

Write-Host "Fixing numbered trait prefixes..." -ForegroundColor Cyan

$files = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse
$fixedCount = 0

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $original = $content
    
    # Replace numbered prefixes in use-trait and contract-call statements
    # Pattern: .\d\d-name.trait -> .name.trait
    $content = $content -replace '\.0[1-9]-([a-z-]+)\.', '.$1.'
    $content = $content -replace '\.1[0-9]-([a-z-]+)\.', '.$1.'
    
    # Fix specific broken patterns
    $content = $content -replace '\.trait-([a-z-]+)\.02-core-protocol\.', '.$1.'
    $content = $content -replace '\.([a-z-]+)\.([a-z-]+)\.rbac-trait-trait', '.$1.rbac-trait'
    
    if ($content -ne $original) {
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  Fixed: $($file.Name)" -ForegroundColor Green
        $fixedCount++
    }
}

Write-Host "`n✅ Fixed $fixedCount files" -ForegroundColor Green
