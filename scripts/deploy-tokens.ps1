# deploy-tokens.ps1
# PowerShell script to deploy all Conxian tokens with proper dependency ordering

# Configuration
$Env:NETWORK = "testnet"  # or "mainnet" for production
$Env:HIRO_API_KEY = "8f88f1cb5341624afdaa9d0282456506"

# Token deployment order (respects dependencies)
$tokens = @(
    @{Name = "sip-010-trait"; Path = "contracts/traits/sip-010-trait.clar"; DependsOn = @()},
    @{Name = "ft-mintable-trait"; Path = "contracts/traits/ft-mintable-trait.clar"; DependsOn = @("sip-010-trait")},
    @{Name = "monitor-trait"; Path = "contracts/traits/monitor-trait.clar"; DependsOn = @()},
    
    # Core Tokens
    @{Name = "cxd-token"; Path = "contracts/tokens/cxd-token.clar"; DependsOn = @("sip-010-trait", "ft-mintable-trait", "monitor-trait")},
    @{Name = "cxvg-token"; Path = "contracts/tokens/cxvg-token.clar"; DependsOn = @("sip-010-trait", "ft-mintable-trait")},
    @{Name = "cxtr-token"; Path = "contracts/tokens/cxtr-token.clar"; DependsOn = @("sip-010-trait", "ft-mintable-trait", "monitor-trait")},
    @{Name = "cxlp-token"; Path = "contracts/tokens/cxlp-token.clar"; DependsOn = @("sip-010-trait", "ft-mintable-trait")},
    @{Name = "cxs-token"; Path = "contracts/tokens/cxs-token.clar"; DependsOn = @("sip-009-trait")},
    
    # Token Utilities
    @{Name = "tokenized-bond"; Path = "contracts/dimensional/tokenized-bond.clar"; DependsOn = @("sip-010-trait")},
    @{Name = "tokenized-bond-adapter"; Path = "contracts/dimensional/tokenized-bond-adapter.clar"; DependsOn = @("tokenized-bond", "sip-010-trait")},
    @{Name = "token-emission-controller"; Path = "contracts/dex/token-emission-controller.clar"; DependsOn = @("sip-010-trait")},
    @{Name = "token-system-coordinator"; Path = "contracts/dex/token-system-coordinator.clar"; DependsOn = @("sip-010-trait")}
)

# Function to check if all dependencies are met
function Test-DependenciesMet {
    param (
        [string[]]$Dependencies,
        [hashtable]$Deployed
    )
    
    foreach ($dep in $Dependencies) {
        if (-not $Deployed.ContainsKey($dep)) {
            return $false
        }
    }
    return $true
}

# Main deployment function
function Deploy-Tokens {
    $deployed = @{}
    $remaining = New-Object System.Collections.Queue($tokens)
    $maxIterations = $tokens.Count * 2  # Prevent infinite loops
    $iteration = 0
    
    Write-Host "Starting token deployment on $($Env:NETWORK)" -ForegroundColor Cyan
    
    while ($remaining.Count -gt 0 -and $iteration -lt $maxIterations) {
        $token = $remaining.Dequeue()
        
        if (Test-DependenciesMet -Dependencies $token.DependsOn -Deployed $deployed) {
            Write-Host "Deploying $($token.Name)..." -ForegroundColor Green
            
            try {
                # Build the Clarinet command
                $dependsOnParams = $token.DependsOn | ForEach-Object { "--depends_on=$_" }
                $command = "clarity-cli deploy_contract $($token.Name) $($token.Path) $($dependsOnParams -join ' ')"
                
                Write-Host "  $command" -ForegroundColor DarkGray
                Invoke-Expression $command
                
                if ($LASTEXITCODE -eq 0) {
                    $deployed[$token.Name] = $true
                    Write-Host "  ✓ Successfully deployed $($token.Name)" -ForegroundColor Green
                } else {
                    Write-Host "  ✗ Failed to deploy $($token.Name)" -ForegroundColor Red
                    $remaining.Enqueue($token)  # Retry later
                }
            } catch {
                Write-Host "  ✗ Error deploying $($token.Name): $_" -ForegroundColor Red
                $remaining.Enqueue($token)  # Retry later
            }
        } else {
            $remaining.Enqueue($token)  # Move to end of queue
        }
        
        $iteration++
    }
    
    if ($remaining.Count -gt 0) {
        Write-Host "Failed to deploy all tokens. Remaining:" -ForegroundColor Red
        $remaining | ForEach-Object { Write-Host "- $($_.Name)" }
        exit 1
    }
    
    Write-Host "All tokens deployed successfully!" -ForegroundColor Green
}

# Execute deployment
Deploy-Tokens
