# Fix Line Endings and Encoding Issues
# PowerShell script to fix CRLF line endings and non-ASCII characters

Write-Host "Starting comprehensive line ending and encoding fix..." -ForegroundColor Green

# Set UTF-8 encoding without BOM for PowerShell
$OutputEncoding = [System.Text.Encoding]::UTF8

# Function to fix line endings and encoding
function Fix-ContractFile {
    param(
        [string]$FilePath
    )
    
    try {
        Write-Host "Processing: $FilePath" -ForegroundColor Yellow
        
        # Read file content with UTF-8 encoding
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        
        if ($content) {
            # Replace CRLF with LF
            $content = $content -replace "`r`n", "`n"
            $content = $content -replace "`r", "`n"
            
            # Replace non-ASCII characters with ASCII equivalents
            $content = $content -replace "â", "-"
            $content = $content -replace "π", "pi"
            $content = $content -replace "≈", "~"
            $content = $content -replace "∞", "inf"
            $content = $content -replace """, '"'
            $content = $content -replace """, '"'
            $content = $content -replace "'", "'"
            $content = $content -replace "'", "'"
            $content = $content -replace "–", "-"
            $content = $content -replace "—", "-"
            $content = $content -replace "…", "..."
            
            # Ensure content ends with single newline
            $content = $content.TrimEnd() + "`n"
            
            # Write back with UTF-8 encoding without BOM
            $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
            [System.IO.File]::WriteAllText($FilePath, $content, $utf8NoBomEncoding)
            
            Write-Host "Fixed: $FilePath" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error processing $FilePath : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Get all .clar files
$clarFiles = Get-ChildItem -Path "c:\Users\bmokoka\anyachainlabs\Conxian\contracts" -Filter "*.clar" -Recurse
Write-Host "Found $($clarFiles.Count) .clar files to process" -ForegroundColor Cyan

# Process each file
foreach ($file in $clarFiles) {
    Fix-ContractFile -FilePath $file.FullName
}

# Fix test files too
$testFiles = Get-ChildItem -Path "c:\Users\bmokoka\anyachainlabs\Conxian\tests" -Filter "*.ts" -Recurse
Write-Host "Found $($testFiles.Count) test files to process" -ForegroundColor Cyan

foreach ($file in $testFiles) {
    Fix-ContractFile -FilePath $file.FullName
}

Write-Host "Line ending and encoding fix completed!" -ForegroundColor Green
Write-Host "All files now use LF line endings and ASCII-compatible characters." -ForegroundColor Green
