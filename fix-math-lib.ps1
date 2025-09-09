#!/usr/bin/env pwsh

# Read the clean file content
$content = Get-Content "contracts/math-lib-clean.clar" -Raw

# Ensure LF line endings
$content = $content -replace "`r`n", "`n"
$content = $content -replace "`r", "`n"

# Write with UTF-8 without BOM and LF line endings
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("contracts/math-lib-advanced.clar", $content, $utf8NoBom)

Write-Host "Math library written with LF line endings and UTF-8 without BOM" -ForegroundColor Green
