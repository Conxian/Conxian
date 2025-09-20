# Fix Line Endings and Character Encoding for Clarity Contracts
# This script converts line endings to LF and ensures proper encoding

Write-Host "🔧 Fixing line endings and character encoding for Clarity contracts..." -ForegroundColor Yellow

# Get all .clar files recursively
$clarFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse

foreach ($file in $clarFiles) {
    Write-Host "Processing: $($file.FullName)" -ForegroundColor Green
    
    try {
        # Read file content as raw text
        $content = [System.IO.File]::ReadAllText($file.FullName)
        
        # Normalize line endings to LF
        $content = $content -replace "`r`n", "`n"
        $content = $content -replace "`r", "`n"
        
        # Remove any remaining non-ASCII characters (keep only ASCII 32-126 plus newlines and tabs)
        $content = [regex]::Replace($content, '[^\x20-\x7E\n\t]', '')
        
        # Write back with UTF-8 encoding without BOM and LF line endings
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
        
        Write-Host "✅ Fixed: $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error processing $($file.Name): $_" -ForegroundColor Red
    }
}

Write-Host "🎉 All Clarity contracts have been processed!" -ForegroundColor Green
