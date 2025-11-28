# Fix impl-trait statements to reference modular trait files
# Handles impl-trait (different from use-trait)

$replacements = @{
    # Individual trait file patterns that need to reference modular files
    '\.access-traits\.access-control-trait' = '.core-protocol.rbac-trait'
    '\.access-control-trait\.access-control-trait' = '.core-protocol.rbac-trait'
    '\.pausable-trait\.pausable-trait' = '.core-protocol.pausable-trait'
    '\.trait-dimensional\.' = '.dimensional-traits.'
    '\.bond-factory-trait\.bond-factory-trait' = '.defi-primitives.pool-factory-trait'
    '\.pool-factory-v2\.pool-factory-v2-trait' = '.defi-primitives.pool-factory-trait'
    '\.dijkstra-pathfinder-trait\.dijkstra-pathfinder-trait' = '.defi-primitives.router-trait'
    '\.route-manager-trait\.route-manager-trait' = '.defi-primitives.router-trait'
    '\.advanced-router-dijkstra-trait\.advanced-router-dijkstra-trait' = '.defi-primitives.router-trait'
    '\.dim-registry-trait\.dim-registry-trait' = '.dimensional-traits.dimensional-trait'
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
Write-Host "impl-trait references fixed!"
