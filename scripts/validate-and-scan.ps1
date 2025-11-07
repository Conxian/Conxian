Param(
  [switch]$StandardizePlans = $true,
  [string]$EnvFilePath = ".env",
  [string]$DeploymentsDir = "deployments",
  [string]$ContractsDir = "contracts",
  [string]$ReportsDir = "reports"
)

$ErrorActionPreference = 'Stop'

function Write-Log {
  param([string]$Message)
  Write-Output ("[validate-and-scan] {0}" -f $Message)
}

function Load-Env {
  param([string]$Path)
  if (!(Test-Path $Path)) {
    throw "Missing .env file at $Path"
  }
  $lines = Get-Content -Raw $Path -ErrorAction Stop -Encoding UTF8
  $map = @{}
  foreach ($line in $lines -split "`r?`n") {
    $trim = $line.Trim()
    if ($trim -eq '' -or $trim.StartsWith('#')) { continue }
    $m = [regex]::Match($trim, '^(?<k>[A-Za-z0-9_\-\.]+)=(?<v>.*)$')
    if ($m.Success) {
      $key = $m.Groups['k'].Value
      $val = $m.Groups['v'].Value
      # Strip surrounding quotes if present
      if ($val.StartsWith('"') -and $val.EndsWith('"')) { $val = $val.Substring(1, $val.Length-2) }
      $map[$key] = $val
    }
  }
  return $map
}

function Validate-Env {
  param($envMap)
  $required = @('DEPLOYER_ADDRESS','NETWORK')
  $present = @()
  $missing = @()
  foreach ($k in $required) { if ($envMap.ContainsKey($k) -and $envMap[$k]) { $present += $k } else { $missing += $k } }
  $privkeyPresent = ($envMap.ContainsKey('STACKS_DEPLOYER_PRIVKEY') -and $envMap['STACKS_DEPLOYER_PRIVKEY']) -or ($envMap.ContainsKey('TESTNET_DEPLOYER_MNEMONIC') -and $envMap['TESTNET_DEPLOYER_MNEMONIC'])
  $addressPrefixOk = $false
  if ($envMap['NETWORK'] -eq 'testnet') { $addressPrefixOk = $envMap['DEPLOYER_ADDRESS'].StartsWith('ST') }
  elseif ($envMap['NETWORK'] -eq 'mainnet') { $addressPrefixOk = $envMap['DEPLOYER_ADDRESS'].StartsWith('SP') }
  else { $addressPrefixOk = $false }
  $formatValid = ($missing.Count -eq 0) -and $privkeyPresent -and $addressPrefixOk
  return @{ envExists = $true; requiredPresent = $present; requiredMissing = $missing; privkeyOrMnemonicPresent = $privkeyPresent; addressPrefixValid = $addressPrefixOk; formatValid = $formatValid }
}

function Standardize-DeploymentPlans {
  param($envMap, [string]$dir, [string]$deployer)
  $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
  $files = Get-ChildItem $dir -File -Include *.toml, *.yaml, *.yml -ErrorAction Stop
  $updated = @()
  foreach ($f in $files) {
    $content = Get-Content -Raw $f.FullName -ErrorAction Stop
    $orig = $content
    # Replace TOML style: expected-sender = "..."
    $content = [regex]::Replace($content, 'expected-sender\s*=\s*"[^"]+"', "expected-sender = \"$deployer\"")
    # Replace YAML style: expected-sender: ...
    $content = [regex]::Replace($content, 'expected-sender\s*:\s*[^\r\n]+', "expected-sender: $deployer")
    if ($content -ne $orig) {
      # Prepend a standardization banner comment (keeping format compatible)
      $banner = "# Standardized from .env on $timestamp`n"
      if (-not ($content.StartsWith('# Standardized'))) { $content = $banner + $content }
      Set-Content -Path $f.FullName -Value $content -Encoding UTF8 -ErrorAction Stop
      $updated += $f.FullName
    }
  }
  return $updated
}

function Scan-Contracts {
  param([string]$contractsDir)
  $files = Get-ChildItem -Recurse -File $contractsDir -Filter *.clar -ErrorAction Stop
  $map = @{}
  foreach ($file in $files) {
    $name = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    if (-not $map.ContainsKey($name)) { $map[$name] = @() }
    $rel = $file.FullName -replace [regex]::Escape((Get-Location).Path+'\'), ''
    $map[$name] += $rel
  }
  return @{ files = ($files | ForEach-Object { $_.FullName -replace [regex]::Escape((Get-Location).Path+'\'), '' }); nameToPaths = $map }
}

function Classify-Severity {
  param([string[]]$paths)
  $sev = 'low'
  foreach ($p in $paths) {
    if ($p -match '^contracts\\tokens' -or $p -match '^contracts\\dex' -or $p -match '^contracts\\vault' -or $p -match '^contracts\\governance') { return 'high' }
    if ($p -match '^contracts\\core' -or $p -match '^contracts\\risk' -or $p -match '^contracts\\oracle' -or $p -match '^contracts\\lib' -or $p -match '^contracts\\libraries') { $sev = 'medium' }
    if ($p -match '^contracts\\mocks' -or $p -match '^contracts\\monitoring' -or $p -match '^contracts\\utils' ) { if ($sev -ne 'high') { $sev = 'low' } }
  }
  return $sev
}

function Check-ExternalConflicts {
  param([string]$address, [string[]]$names, [string]$apiBase)
  $base = if ($apiBase) { $apiBase.TrimEnd('/') + '/v2/contracts/source' } else { 'https://api.testnet.hiro.so/v2/contracts/source' }
  $results = @{}
  foreach ($n in $names) {
    $url = "$base/$address/$n"
    try {
      $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -Method GET -ErrorAction Stop
      # If we got here, status was 2xx => conflict exists
      $results[$n] = @{ exists = $true; status = $resp.StatusCode }
    } catch {
      $status = ($_.Exception.Response.StatusCode.value__ ) 2> $null
      if ($status -eq $null) { $status = -1 }
      if ($status -eq 404) { $results[$n] = @{ exists = $false; status = 404 } }
      else { $results[$n] = @{ exists = $false; status = $status; error = $_.Exception.Message } }
    }
  }
  return $results
}

function Build-Conflict-Report {
  param($envMap, $validation, $scan, $external)
  $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
  $conflicts = @()
  $nameMap = $scan.nameToPaths
  foreach ($key in $nameMap.Keys) {
    $paths = $nameMap[$key]
    $internalDuplicate = ($paths.Count -gt 1)
    $externalExists = ($external.ContainsKey($key) -and $external[$key].exists)
    if ($internalDuplicate -or $externalExists) {
      $severity = Classify-Severity -paths $paths
      $recommendations = @()
      if ($internalDuplicate) { $recommendations += "Rename duplicate contract files or scope names per module (e.g., add -dex/-core suffix)." }
      if ($externalExists) { $recommendations += "Choose a unique contract-name or deploy from a different address; ensure factory routes reference updated IDs." }
      $type = @()
      if ($internalDuplicate) { $type += 'internal-duplicate' }
      if ($externalExists) { $type += 'external-existing' }
      $conflicts += @{ 
        contractName = $key;
        type = $type;
        severity = $severity;
        affectedFiles = $paths;
        recommendedResolution = $recommendations;
        externalStatus = if ($external.ContainsKey($key)) { $external[$key].status } else { 404 }
      }
    }
  }
  $coverageComplete = ($scan.files.Count -ge (Get-ChildItem -Recurse -File $ContractsDir -Filter *.clar).Count)
  return @{ 
    timestamp = $timestamp;
    env = @{ DEPLOYER_ADDRESS = $envMap['DEPLOYER_ADDRESS']; NETWORK = $envMap['NETWORK'] };
    validation = $validation;
    scan = @{ totalContractsFound = $scan.files.Count; coverageComplete = $coverageComplete; filesScanned = $scan.files };
    conflicts = $conflicts;
    errors = @()
  }
}

# MAIN EXECUTION
Write-Log "Loading .env from $EnvFilePath"
$envMap = Load-Env -Path $EnvFilePath
$validation = Validate-Env -envMap $envMap
if (-not $validation.formatValid) {
  Write-Log "ENV validation failed: requiredMissing=$($validation.requiredMissing -join ', '), privkeyOrMnemonicPresent=$($validation.privkeyOrMnemonicPresent), addressPrefixValid=$($validation.addressPrefixValid)"
  throw "Environment validation failed. Please correct .env before deployment."
}
Write-Log "ENV validation passed. Address=$($envMap['DEPLOYER_ADDRESS']) Network=$($envMap['NETWORK'])"

if ($StandardizePlans) {
  Write-Log "Standardizing deployment plans in '$DeploymentsDir' to use .env DEPLOYER_ADDRESS"
  $updated = Standardize-DeploymentPlans -envMap $envMap -dir $DeploymentsDir -deployer $envMap['DEPLOYER_ADDRESS']
  Write-Log ("Updated {0} deployment plan file(s)." -f $updated.Count)
  foreach ($u in $updated) { Write-Log (" - $u") }
}

Write-Log "Scanning contracts directory '$ContractsDir'"
$scan = Scan-Contracts -contractsDir $ContractsDir
Write-Log ("Found {0} .clar files." -f $scan.files.Count)

Write-Log "Checking external conflicts on testnet via Hiro API"
$apiBase = if ($envMap.ContainsKey('STACKS_API_BASE')) { $envMap['STACKS_API_BASE'] } else { 'https://api.testnet.hiro.so' }
$external = Check-ExternalConflicts -address $envMap['DEPLOYER_ADDRESS'] -names ($scan.nameToPaths.Keys) -apiBase $apiBase

Write-Log "Building conflict report JSON"
$report = Build-Conflict-Report -envMap $envMap -validation $validation -scan $scan -external $external

if (!(Test-Path $ReportsDir)) { New-Item -ItemType Directory -Force -Path $ReportsDir | Out-Null }
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$reportPath = Join-Path $ReportsDir ("contract-conflicts-$ts.json")
$report | ConvertTo-Json -Depth 6 | Out-File -FilePath $reportPath -Encoding UTF8 -Force

Write-Log ("Report generated: $reportPath")
Write-Output ("JSON report path: $reportPath")