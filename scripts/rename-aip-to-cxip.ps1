# Rename AIP files to CXIP and update content
Get-ChildItem -Path . -Recurse -Filter 'AIP-*.md' | ForEach-Object {
    $newName = $_.Name -replace 'AIP', 'CXIP'
    $newPath = Join-Path $_.Directory.FullName $newName
    
    # Rename file
    Rename-Item -Path $_.FullName -NewName $newName
    
    # Update content
    (Get-Content $newPath) | 
        ForEach-Object { $_ -replace 'AIP', 'CXIP' -replace 'Anya Improvement Proposal', 'Conxian Improvement Proposal' } | 
        Set-Content $newPath
}

# Update references in other files
Get-ChildItem -Path . -Recurse -Include *.md, *.clar, *.toml | ForEach-Object {
    $content = Get-Content $_.FullName
    $updatedContent = $content -replace 'AIP-', 'CXIP-'
    Set-Content -Path $_.FullName -Value $updatedContent
}
