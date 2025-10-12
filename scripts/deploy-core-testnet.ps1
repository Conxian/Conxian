# Core Testnet Deployment Script for Conxian Protocol
# This script handles the deployment of core contracts to the Stacks testnet

# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$manifestPath = "$PSScriptRoot/../stacks/Clarinet.test.toml"
$deployerAddress = "ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6"
$stacksNode = "https://stacks-node-api.testnet.stacks.co"

# Colors for output
$successColor = "Green"
$infoColor = "Cyan"
$warningColor = "Yellow"
$errorColor = "Red"

function Write-Info {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ℹ️  $Message" -ForegroundColor $infoColor
}

function Write-Success {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ $Message" -ForegroundColor $successColor
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⚠️  $Message" -ForegroundColor $warningColor
}

function Write-Error {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ❌ $Message" -ForegroundColor $errorColor
    exit 1
}

# Check if Clarinet is installed
if (-not (Get-Command clarinet -ErrorAction SilentlyContinue)) {
    Write-Error "Clarinet is not installed. Please install it first."
}

# Check if we're in the correct directory
if (-not (Test-Path $manifestPath)) {
    Write-Error "Could not find Clarinet.toml. Please run this script from the project root directory."
}

# Function to deploy a single contract
function Deploy-Contract {
    param(
        [string]$ContractName,
        [string]$ContractPath,
        [int]$Cost = 1000000
    )
    
    Write-Info "Deploying $ContractName..."
    
    try {
        # Create a temporary deployment plan
        $tempPlan = "$env:TEMP/testnet-deploy-$ContractName.toml"
        @"
id = 0
name = "Deploy $ContractName to Testnet"
network = "testnet"
stacks-node = "$stacksNode"

[[plan.batches]]
id = 0

  [[plan.batches.transactions]]
  contract-publish = {
    contract-name = "$ContractName",
    expected-sender = "$deployerAddress",
    cost = $Cost,
    path = "$ContractPath",
    anchor-block-only = true,
    clarity-version = 3,
    epoch = "3.0"
  }
"@ | Out-File -FilePath $tempPlan -Encoding utf8

        # Execute deployment
        $result = clarinet deployments apply `
            --manifest-path $manifestPath `
            --deployment-plan-path $tempPlan `
            2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to deploy $ContractName`n$($result -join "`n")"
        } else {
            Write-Success "Successfully deployed $ContractName"
            return $true
        }
    } catch {
        Write-Error "Error deploying $ContractName`n$_"
        return $false
    } finally {
        # Clean up temporary file
        if (Test-Path $tempPlan) {
            Remove-Item $tempPlan -Force
        }
    }
}

# Main deployment process
Write-Host "`n🚀 Starting Conxian Testnet Deployment 🚀" -ForegroundColor Magenta
Write-Host "=====================================" -ForegroundColor Magenta
Write-Host "Deployer: $deployerAddress"
Write-Host "Node: $stacksNode"
Write-Host "Manifest: $($manifestPath -replace "$PSScriptRoot/../", '')"
Write-Host "=====================================`n" -ForegroundColor Magenta

# Core contracts to deploy (in order)
$contracts = @(
    @{ Name = "all-traits"; Path = "contracts/traits/all-traits.clar"; Cost = 500000 },
    @{ Name = "cxd-token"; Path = "contracts/tokens/cxd-token.clar"; Cost = 1000000 },
    @{ Name = "governance-token"; Path = "contracts/governance/governance-token.clar"; Cost = 1000000 }
)

# Deploy each contract
foreach ($contract in $contracts) {
    $success = Deploy-Contract -ContractName $contract.Name -ContractPath $contract.Path -Cost $contract.Cost
    if (-not $success) {
        Write-Error "Aborting deployment due to errors."
    }
    
    # Add a small delay between deployments
    Start-Sleep -Seconds 5
}

# Verify deployment
Write-Host "`n🔍 Verifying deployment..." -ForegroundColor Cyan
$deployedContracts = @()

foreach ($contract in $contracts) {
    $info = clarinet contract info $contract.Name --manifest $manifestPath 2>&1
    if ($LASTEXITCODE -eq 0) {
        $deployedContracts += [PSCustomObject]@{
            Contract = $contract.Name
            Status = "✅ Deployed"
            Info = $info -join "`n"
        }
    } else {
        $deployedContracts += [PSCustomObject]@{
            Contract = $contract.Name
            Status = "❌ Failed"
            Info = $info -join "`n"
        }
    }
}

# Display deployment results
$deployedContracts | Format-Table Contract, Status -AutoSize

# Check for any failures
$failed = $deployedContracts | Where-Object { $_.Status -like "❌*" }
if ($failed) {
    Write-Host "`n❌ Some contracts failed to deploy:" -ForegroundColor Red
    $failed | ForEach-Object { 
        Write-Host "  - $($_.Contract): $($_.Status)" -ForegroundColor Red
        Write-Host "    $($_.Info)" -ForegroundColor DarkRed
    }
    exit 1
}

Write-Host "`n🎉 All core contracts deployed successfully!" -ForegroundColor Green
Write-Host "🌐 View on Explorer: https://explorer.stacks.co/address/$deployerAddress?chain=testnet" -ForegroundColor Cyan
Write-Host "📊 Check contract calls: https://explorer.stacks.co/address/$deployerAddress/contract-calls?chain=testnet" -ForegroundColor Cyan

# Open the explorer in the default browser
Start-Process "https://explorer.stacks.co/address/$deployerAddress?chain=testnet"
