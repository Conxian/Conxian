# Fix Line Endings and Character Encoding for Clarity Contracts
# This script converts CRLF to LF and removes non-ASCII characters

Write-Host "🔧 Fixing line endings and character encoding for Clarity contracts..." -ForegroundColor Yellow

# Get all .clar files recursively
$clarFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse

foreach ($file in $clarFiles) {
    Write-Host "Processing: $($file.FullName)" -ForegroundColor Green
    
    # Read file content as bytes to preserve encoding
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    
    if ($content) {
        # Replace common Unicode characters with ASCII equivalents
        $content = $content -replace 'â', '-'  # Replace Unicode dash
        $content = $content -replace 'Ï', 'pi'  # Replace Unicode pi
        $content = $content -replace '["""]', '"'  # Replace smart quotes
        $content = $content -replace '[''']', "'"  # Replace smart apostrophes
        
        # Remove other non-ASCII characters (keep only ASCII 32-126)
        $content = [System.Text.RegularExpressions.Regex]::Replace($content, '[^\x20-\x7E\r\n\t]', '')
        
        # Convert CRLF to LF
        $content = $content -replace "`r`n", "`n"
        $content = $content -replace "`r", "`n"
        
        # Write back with UTF8 encoding without BOM and LF line endings
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
        
        Write-Host "✅ Fixed: $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "🎉 All Clarity contracts have been fixed!" -ForegroundColor Green
Write-Host "📝 Summary of fixes applied:" -ForegroundColor Cyan
Write-Host "   - Converted CRLF to LF line endings" -ForegroundColor White
Write-Host "   - Replaced Unicode characters with ASCII equivalents" -ForegroundColor White
Write-Host "   - Ensured UTF-8 encoding without BOM" -ForegroundColor White
