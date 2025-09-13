# Setup environment variables for local development
# This script helps sync local environment with GitHub secrets

param (
    [string]$EnvFile = ".env"
)

# Check if .env file exists
if (-not (Test-Path $EnvFile)) {
    Write-Host "Creating new .env file from .env.example"
    Copy-Item -Path ".env.example" -Destination $EnvFile
    Write-Host "Please update the values in $EnvFile and run this script again"
    exit 1
}

# Load environment variables
$envVars = @{}
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^([^#][^=]+)=(.*)') {
        $envVars[$matches[1]] = $matches[2].Trim('"\' ')
    }
}

# Set environment variables
foreach ($key in $envVars.Keys) {
    if (-not [string]::IsNullOrEmpty($envVars[$key])) {
        [Environment]::SetEnvironmentVariable($key, $envVars[$key], "User")
        Write-Host "Set $key"
    }
}

Write-Host "Environment variables have been set from $EnvFile"
Write-Host "You can now run 'clarinet console' or other commands"
