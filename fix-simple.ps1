# Fix Line Endings for Clarity Contracts
Write-Host "Fixing line endings for Clarity contracts..." -ForegroundColor Yellow

$clarFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse
Write-Host "Found $($clarFiles.Count) .clar files to process" -ForegroundColor Cyan

$processedCount = 0
foreach ($file in $clarFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Green
    
    try {
        # Read content
        $content = Get-Content $file.FullName -Raw -Encoding UTF8
        
        if ($content) {
            # Fix specific Unicode characters
            $content = $content.Replace("â", "-")
            $content = $content.Replace("Ï", "pi")
            
            # Convert to LF line endings
            $content = $content.Replace("`r`n", "`n")
            $content = $content.Replace("`r", "`n")
            
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

Write-Host "Processed $processedCount Clarity contracts!" -ForegroundColor Green
