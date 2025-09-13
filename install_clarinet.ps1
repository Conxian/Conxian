# Download Clarinet for Windows (glibc variant)
$downloadUrl = "https://github.com/hirosystems/clarinet/releases/latest/download/clarinet-windows-x64-glibc.zip"
$zipPath = "clarinet.zip"
$installDir = "bin"

# Remove existing files to prevent conflicts
Remove-Item -Path $zipPath -ErrorAction SilentlyContinue
Remove-Item -Path "$installDir/clarinet*" -Recurse -ErrorAction SilentlyContinue

# Download and extract
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

# Verify installation
& "$installDir/clarinet" --version
