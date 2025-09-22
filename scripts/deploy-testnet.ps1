# Deployment script for Conxian Testnet
# This script helps with deploying contracts to the Stacks testnet

# Check if required commands are installed
$requiredCommands = @('gh', 'jq', 'git')
foreach ($cmd in $requiredCommands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "Error: $cmd is not installed. Please install it and try again."
        exit 1
    }
}

# Check if we're in the correct directory
if (-not (Test-Path "$PSScriptRoot/../Clarinet.toml")) {
    Write-Error "Error: Please run this script from the project root directory"
    exit 1
}

# Check if we're logged in to GitHub
$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: Not logged in to GitHub. Please run 'gh auth login' first."
    exit 1
}

# Get the deployer address from the keychain
$deployerAddress = (Get-Content "$PSScriptRoot/../.secrets/keychain.json" | ConvertFrom-Json).keyInfo.address

Write-Host "🚀 Starting deployment process for Conxian Testnet" -ForegroundColor Cyan
Write-Host "🔑 Using deployer address: $deployerAddress" -ForegroundColor Yellow

# Update Clarinet.toml with the new address
Write-Host "🔄 Updating Clarinet.toml with new deployer address..." -ForegroundColor Cyan
(Get-Content "$PSScriptRoot/../Clarinet.toml") -replace 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6', $deployerAddress | Set-Content "$PSScriptRoot/../Clarinet.toml"

# Update contract files with the new address
Write-Host "🔄 Updating contract files with new deployer address..." -ForegroundColor Cyan
Get-ChildItem -Path "$PSScriptRoot/../contracts" -Filter "*.clar" -Recurse | ForEach-Object {
    (Get-Content $_.FullName) -replace 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6', $deployerAddress | Set-Content $_.FullName
}

# Set up GitHub secret if not already set
Write-Host "🔐 Setting up GitHub secret..." -ForegroundColor Cyan
$privateKey = (Get-Content "$PSScriptRoot/../.secrets/keychain.json" | ConvertFrom-Json).keyInfo.privateKey
gh secret set TESTNET_DEPLOYER_KEY --body $privateKey

# Commit changes
Write-Host "💾 Committing changes..." -ForegroundColor Cyan
git add .
git commit -m "chore: update deployer address to $($deployerAddress[0..7] -join '')..."

Write-Host "✅ Deployment setup complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Push your changes to GitHub"
Write-Host "2. Go to GitHub Actions and run the 'Deploy to Testnet' workflow"
Write-Host "3. Monitor the deployment progress in the Actions tab"

# Ask if user wants to push changes
$push = Read-Host "Do you want to push these changes to GitHub now? (y/n)"
if ($push -eq 'y') {
    git push
    Write-Host "✅ Changes pushed to GitHub!" -ForegroundColor Green
    Write-Host "🚀 Go to GitHub Actions to monitor the deployment." -ForegroundColor Cyan
}
