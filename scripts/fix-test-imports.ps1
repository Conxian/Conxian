# Script to fix imports in test files

# Get all test files
$testFiles = Get-ChildItem -Path ".\tests" -Recurse -Filter "*.ts" -File

foreach ($file in $testFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    $updated = $false
    
    # Update import paths
    $patterns = @(
        # Update contract imports
        @{ Pattern = 'from "\.\./contracts/'; Replacement = 'from "../../contracts/' },
        @{ Pattern = 'from "\.\./\.\./contracts/'; Replacement = 'from "../../contracts/' },
        
        # Update test utility imports
        @{ Pattern = 'from "\.\./utils/'; Replacement = 'from "../utils/' },
        @{ Pattern = 'from "\.\./\.\./utils/'; Replacement = 'from "../../utils/' },
        
        # Fix any remaining relative paths
        @{ Pattern = 'from "\.\./\.\./'; Replacement = 'from "../../' },
        @{ Pattern = 'from "\.\./'; Replacement = 'from "../' }
    )
    
    foreach ($pattern in $patterns) {
        if ($content -match $pattern.Pattern) {
            $content = $content -replace $pattern.Pattern, $pattern.Replacement
            $updated = $true
        }
    }
    
    if ($updated) {
        $content | Set-Content -Path $file.FullName -NoNewline
        Write-Host "Updated imports in $($file.FullName)"
    }
}

Write-Host "Test import updates complete!"
