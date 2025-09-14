# Fix Line Endings and Character Encoding for Clarity Contracts
Write-Host "Fixing line endings and character encoding for Clarity contracts..." -ForegroundColor Yellow

# Get all .clar files recursively  
$clarFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse
Write-Host "Found $($clarFiles.Count) .clar files to process" -ForegroundColor Cyan

$processedCount = 0
foreach ($file in $clarFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Green
    
    try {
        # Read file content as bytes
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $content = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        if ($content) {
            # Replace problematic Unicode characters
            $content = $content -replace 'â', '-'
            $content = $content -replace 'Ï', 'pi'  
            $content = $content -replace '["""]', '"'
            $content = $content -replace '[''']', "'"
            
            # Remove any remaining non-ASCII characters except newlines and tabs
            $content = $content -replace '[^\x00-\x7F]', ''
            
            # Convert to LF line endings
            $content = $content -replace "`r`n", "`n"
            $content = $content -replace "`r", "`n"
            
            # Write back as UTF-8 without BOM
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
            
            $processedCount++
            Write-Host "Fixed: $($file.Name)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error processing $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Processed $processedCount Clarity contracts!" -ForegroundColor Green
