# Download and install Clarinet globally for Windows
$downloadUrl = "https://github.com/hirosystems/clarinet/releases/download/v3.5.0/clarinet-v3.5.0-x86_64-pc-windows-msvc.zip"
$zipPath = "clarinet.zip"
$globalBinDir = "$env:USERPROFILE\AppData\Local\bin"

# Remove existing zip if present
Remove-Item -Path $zipPath -ErrorAction SilentlyContinue

# Download with error handling
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
} catch {
    Write-Error "Failed to download Clarinet: $_"
    exit 1
}

# Create global bin directory if it doesn't exist
New-Item -ItemType Directory -Path $globalBinDir -Force

# Extract the zip to a temporary directory
$tempDir = New-Item -ItemType Directory -Path "$env:TEMP\clarinet-install" -Force
Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

# Copy the executable to the global bin directory
Copy-Item -Path "$tempDir\clarinet.exe" -Destination "$globalBinDir\clarinet.exe" -Force

# Clean up the temporary directory and the zip
Remove-Item -Path $tempDir -Recurse -Force
Remove-Item -Path $zipPath -Force

# Update the PATH if necessary
$userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
if ($userPath -notlike "*$globalBinDir*") {
    $newPath = $userPath + ";$globalBinDir"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
    # Also update the current session's PATH
    $env:Path += ";$globalBinDir"
}

# Verify installation
clarinet --version
