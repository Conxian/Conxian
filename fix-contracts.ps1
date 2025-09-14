# Fix Line Endings and Character Encoding for Clarity Contracts
Write-Host "🔧 Fixing line endings and character encoding for Clarity contracts..." -ForegroundColor Yellow

# Get all .clar files recursively
$clarFiles = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse

foreach ($file in $clarFiles) {
    Write-Host "Processing: $($file.FullName)" -ForegroundColor Green
    
    # Read file content
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    
    if ($content) {
        # Replace Unicode characters with ASCII equivalents
        $content = $content.Replace("â", "-")
        # Replace "Ï" with "pi" (used for mathematical constant pi in some contexts)
        $content = $content.Replace("Ï", "pi") 
        $content = $content.Replace([char]0x201C, '"') # Left double quote
        $content = $content.Replace("â€”", "--") # em dash
        # If you still need to replace standalone "â", uncomment the next line and document why.
        # $content = $content.Replace("â", "-") # Only if you are sure this is safe
        $content = $content.Replace("Ï", "pi") 
        $content = $content.Replace([char]0x201C, '"') # Left double quote
        $content = $content.Replace([char]0x201D, '"') # Right double quote
        $content = $content.Replace([char]0x2018, "'") # Left single quote
        $content = $content.Replace([char]0x2019, "'") # Right single quote
        
        # Remove other problematic Unicode characters
        $content = $content -replace '[^\x00-\x7F]', ''
        
        # Convert CRLF to LF
        $content = $content.Replace([char]0x0D + [char]0x0A, [char]0x0A) # CRLF to LF
        $content = $content.Replace([char]0x0D, [char]0x0A) # CR to LF
        
        # Write back with UTF8 encoding without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
        
        Write-Host "✅ Fixed: $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "🎉 All Clarity contracts have been fixed!" -ForegroundColor Green
