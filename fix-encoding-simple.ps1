# Simple encoding fix script with proper ASCII characters only
Write-Host "Fixing contract encoding issues..." -ForegroundColor Yellow

$contractsPath = "contracts"
if (-not (Test-Path $contractsPath)) {
    Write-Host "Contracts directory not found!" -ForegroundColor Red
    exit 1
}

$clarFiles = Get-ChildItem -Path $contractsPath -Filter "*.clar" -Recurse

foreach ($file in $clarFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
    
    # Read with UTF-8 encoding
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    
    if ($content -eq $null) {
        Write-Host "  Skipping empty file" -ForegroundColor Yellow
        continue
    }
    
    # Fix common encoding issues using hexadecimal patterns
    $content = $content -replace '\u2192', '->'  # → arrow
    $content = $content -replace '\u03C0', 'Pi'  # π character  
    $content = $content -replace '\u2248', '~'   # ≈ approximately
    $content = $content -replace '\u2013', '-'   # en dash
    $content = $content -replace '\u2014', '--'  # em dash
    $content = $content -replace '\u201C', '"'   # left double quote
    $content = $content -replace '\u201D', '"'   # right double quote
    $content = $content -replace '\u2018', "'"   # left single quote
    $content = $content -replace '\u2019', "'"   # right single quote
    
    # Convert line endings to LF only
    $content = $content -replace "`r`n", "`n"
    $content = $content -replace "`r", "`n"
    
    # Ensure single newline at end
    $content = $content.TrimEnd() + "`n"
    
    # Write back as UTF-8 without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
    
    Write-Host "  Fixed encoding and line endings" -ForegroundColor Green
}

Write-Host "All contract files processed successfully!" -ForegroundColor Green
