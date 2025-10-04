<#
Conxian End-to-End Orchestrator (Devnet → Testnet → Mainnet tests)

Stages (sequential):
  1) Sync Clarinet.toml with all contracts
  2) Verify contracts (listings, traits, compilation)
  3) Run unit/integration tests (Vitest)
  4) Deploy to devnet (dry-run by default) + post-deploy checks
  5) Deploy to testnet (requires DEPLOYER_PRIVKEY) + post-deploy checks
  6) Run tests for mainnet configuration (no deploy)

Usage examples:
  # Full pipeline (devnet DRY RUN) then testnet (real deploy if key provided), then mainnet tests
  powershell -ExecutionPolicy Bypass -File .\scripts\pipeline_orchestrator.ps1

  # Skip testnet deploy
  powershell -ExecutionPolicy Bypass -File .\scripts\pipeline_orchestrator.ps1 -SkipTestnet

  # Disable dry-run for devnet (attempt broadcast on devnet)
  powershell -ExecutionPolicy Bypass -File .\scripts\pipeline_orchestrator.ps1 -NoDevnetDryRun
  
  Environment variables:
    DEPLOYER_PRIVKEY   - <hex-private-key> (never commit; use secret manager)
  CORE_API_URL       - optional; overrides network API URL resolution for SDK
#>

[CmdletBinding()]
param(
  [switch]$SkipDevnet,
  [switch]$SkipTestnet,
  [switch]$SkipMainnetTests,
  [switch]$NoDevnetDryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Step($Name, [scriptblock]$Action, [bool]$Required = $true) {
  Write-Host "`n=== [$Name] ===" -ForegroundColor Cyan
  try {
    & $Action
    Write-Host "[PASS] $Name" -ForegroundColor Green
    return $true
  } catch {
    Write-Host ("[FAIL] {0}: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    if ($Required) { throw }
    return $false
  }
}

function Ensure-Tool($cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required tool not found: $cmd"
  }
}

function Load-Wallets($NetworkName) {
  $cfgPath = Join-Path $ROOT ("config/wallets.{0}.json" -f $NetworkName)
  if (-not (Test-Path $cfgPath)) {
    Write-Host ("[warn] Wallet config not found: {0}" -f $cfgPath) -ForegroundColor Yellow
    return
  }
  $cfg = Get-Content $cfgPath | ConvertFrom-Json
  $env:DAO_BOARD_ADDRESS       = $cfg.dao_board_address
  $env:OPS_MULTISIG_ADDRESS    = $cfg.ops_multisig_address
  $env:GUARDIAN_ADDRESS        = $cfg.guardian_address
  $env:TREASURY_ADDRESS        = $cfg.treasury_address
  $env:TIMELOCK_CONTRACT       = $cfg.timelock_contract
  if ($cfg.deployer_address) { $env:DEPLOYER_ADDRESS = $cfg.deployer_address }
  Write-Host ("[wallets] Loaded {0}" -f $cfgPath) -ForegroundColor DarkCyan
}

# Project root
$ROOT = (Resolve-Path "$PSScriptRoot/..\").Path
Push-Location $ROOT

# Tools check
Step "Tools check" {
  Ensure-Tool python
  Ensure-Tool clarinet
  Ensure-Tool npm
  Ensure-Tool node
} | Out-Null

# 1) Sync Clarinet.toml with all contracts
Step "Sync Clarinet.toml (add missing contracts)" {
  python .\scripts\sync_clarinet_contracts.py --write | Write-Host
}

# 2) Verify full system
Step "Verify contracts (listings/traits/compile)" {
  python .\scripts\verify_contracts.py | Write-Host
}

# 3) Unit & integration tests (Vitest)
Step "Install dev deps if needed" {
  npm.cmd install | Out-Null
}
Step "Run tests (Vitest)" {
  npx vitest run
}

# 4) Devnet deploy (optional)
if (-not $SkipDevnet) {
  Step "Devnet deploy (sdk_deploy_contracts.js)" {
    if (-not (Test-Path .\scripts\sdk_deploy_contracts.js)) {
      throw "scripts/sdk_deploy_contracts.js not found; cannot perform SDK deploy."
    }
    $env:NETWORK = 'devnet'
    Load-Wallets 'devnet'
    if ($NoDevnetDryRun) { Remove-Item Env:DRY_RUN -ErrorAction SilentlyContinue } else { $env:DRY_RUN = '1' }
    node .\scripts\sdk_deploy_contracts.js
  } $false | Out-Null

  Step "Devnet post-deploy verification (TS)" {
    if (Test-Path .\scripts\post_deploy_verify.ts) {
      npx ts-node .\scripts\post_deploy_verify.ts
    } else {
      Write-Host "post_deploy_verify.ts not found - skipping" -ForegroundColor Yellow
    }
  } $false | Out-Null
}

# 5) Testnet deploy (requires DEPLOYER_PRIVKEY)
if (-not $SkipTestnet) {
  Step "Testnet preflight" {
    if (-not $Env:DEPLOYER_PRIVKEY) { throw "DEPLOYER_PRIVKEY not set in environment" }
  }
  Step "Testnet deploy (sdk_deploy_contracts.js)" {
    $env:NETWORK = 'testnet'
    Load-Wallets 'testnet'
    Remove-Item Env:DRY_RUN -ErrorAction SilentlyContinue
    node .\scripts\sdk_deploy_contracts.js
  }
  Step "Testnet post-deploy verification (enhanced)" {
    if (Test-Path .\scripts\enhanced-post-deployment-verification.ts) {
      npx ts-node .\scripts\enhanced-post-deployment-verification.ts
    } else {
      Write-Host "enhanced-post-deployment-verification.ts not found - skipping" -ForegroundColor Yellow
    }
  } $false | Out-Null
  Step "Testnet post-deploy handover (DAO/ops)" {
    if (Test-Path .\scripts\post_deploy_handover.ts) {
      npx ts-node .\scripts\post_deploy_handover.ts
    } else {
      Write-Host "post_deploy_handover.ts not found - skipping" -ForegroundColor Yellow
    }
  } $false | Out-Null
}

# 6) Mainnet tests (no deploy)
if (-not $SkipMainnetTests) {
  Step "Mainnet tests (configuration)" {
    $env:NETWORK = 'mainnet'
    Load-Wallets 'mainnet'
    npx vitest run
  } $false | Out-Null
}

Write-Host "`n=== Pipeline complete ===" -ForegroundColor Cyan
Pop-Location
