# Fix Line Endings and Character Encoding for Clarity Contracts
Write-Host "🔧 Fixing line endings and character encoding for Clarity contracts..." -ForegroundColor Yellow

# Get all .clar files recursively  
$clarFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse
Write-Host "Found $($clarFiles.Count) .clar files to process" -ForegroundColor Cyan

$processedCount = 0
foreach ($file in $clarFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Green
    
    try {
        # Read file content
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        
        if ($content) {
            # Replace Unicode characters with ASCII equivalents
            $originalLength = $content.Length
            
            # Targeted replacements for common mis-encodings and smart quotes/dashes
            $content = $content.Replace('â', '-')
            $content = $content.Replace('Ï', 'pi')
            $content = $content.Replace('“', '"')
            $content = $content.Replace('”', '"')
            $content = $content.Replace('‘', "'")
            $content = $content.Replace('’', "'")
            
            # Remove other non-ASCII characters
            $content = $content -replace '[^\u0000-\u007F]', ''
            
            # Convert CRLF to LF
            $content = $content.Replace("`r`n", "`n")
            $content = $content.Replace("`r", "`n")
            
            # Write back with UTF8 encoding without BOM
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
            
            $processedCount++
            Write-Host "✅ Fixed: $($file.Name) (was $originalLength chars, now $($content.Length) chars)" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Skipped: $($file.Name) (empty file)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Error processing $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🎉 Processed $processedCount Clarity contracts!" -ForegroundColor Green
Write-Host "📝 Summary of fixes applied:" -ForegroundColor Cyan
Write-Host "   - Converted CRLF to LF line endings" -ForegroundColor White
Write-Host "   - Replaced Unicode characters with ASCII equivalents" -ForegroundColor White
Write-Host "   - Ensured UTF-8 encoding without BOM" -ForegroundColor White
