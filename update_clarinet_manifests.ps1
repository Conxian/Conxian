# Update all Clarinet.toml files in the current directory and subdirectories (root level only)
$files = Get-ChildItem -Path . -Include 'Clarinet*.toml' -Recurse -Depth 1 | Where-Object { $_.DirectoryName -eq (Resolve-Path .).Path }

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw

    # Update project clarinet_version to 3.5.0
    $content = $content -replace 'clarinet_version\s*=\s*"[0-9]+\.[0-9]+\.[0-9]+"', 'clarinet_version = "3.5.0"'

    # Replace clarity_version = <number> with epoch = "2.4"
    $content = $content -replace 'clarity_version\s*=\s*[0-9]+', 'epoch = "2.4"'

    Set-Content -Path $file.FullName -Value $content
}
