#!/usr/bin/env pwsh

Write-Host "=== Comprehensive File Encoding and Line Ending Fix ===" -ForegroundColor Green
Write-Host "Fixing all .clar, .ts, .js, .md, .toml, and .yaml files..." -ForegroundColor Yellow

# Get all relevant files
$files = Get-ChildItem -Recurse -Include "*.clar", "*.ts", "*.js", "*.md", "*.toml", "*.yaml", "*.yml" | Where-Object { $_.FullName -notmatch "node_modules|\.git|coverage" }

Write-Host "Found $($files.Count) files to process" -ForegroundColor Cyan

$fixedCount = 0
$errorCount = 0

foreach ($file in $files) {
    try {
        Write-Host "Processing: $($file.Name)" -ForegroundColor Gray
        
        # Read file as bytes to detect BOM
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        
        # Check for UTF-8 BOM and remove it
        $hasBOM = $false
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $hasBOM = $true
            $bytes = $bytes[3..($bytes.Length - 1)]
            Write-Host "  Removed UTF-8 BOM" -ForegroundColor Yellow
        }
        
        # Convert to string using UTF-8 (without BOM)
        $content = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        # Replace CRLF with LF
        $originalLength = $content.Length
        $content = $content -replace "`r`n", "`n"
        $content = $content -replace "`r", "`n"
        
        if ($content.Length -ne $originalLength -or $hasBOM) {
            Write-Host "  Fixed line endings and/or BOM" -ForegroundColor Green
        }
        
        # Write back with UTF-8 without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
        
        $fixedCount++
    }
    catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host "=== Summary ===" -ForegroundColor Green
Write-Host "Successfully processed: $fixedCount files" -ForegroundColor Green
Write-Host "Errors encountered: $errorCount files" -ForegroundColor Red

# Set git line ending attributes
Write-Host "`nSetting git attributes for consistent line endings..." -ForegroundColor Yellow

$gitAttributes = @"
# Auto detect text files and perform LF normalization
* text=auto

# Explicitly declare text files to be normalized and converted to LF on checkin
*.clar text eol=lf
*.ts text eol=lf
*.js text eol=lf
*.md text eol=lf
*.toml text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.json text eol=lf

# Declare files that will always have CRLF line endings on checkout
*.bat text eol=crlf

# Denote all files that are truly binary and should not be modified
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.ico binary
*.pdf binary
*.zip binary
*.tar.gz binary
"@

Set-Content -Path ".gitattributes" -Value $gitAttributes -Encoding UTF8
Write-Host "Created .gitattributes file" -ForegroundColor Green

Write-Host "`n=== Fix Complete ===" -ForegroundColor Green
Write-Host "Run 'git add . && git reset --hard HEAD' if you want to refresh from git" -ForegroundColor Yellow
