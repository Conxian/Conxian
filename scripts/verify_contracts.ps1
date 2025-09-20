<#
.SYNOPSIS
    Verifies contract and trait alignments in the Conxian protocol.
.DESCRIPTION
    This script performs the following checks:
    1. Verifies all .clar files are listed in Clarinet.toml
    2. Checks for missing or incorrect trait references
    3. Validates trait implementations in contracts
    4. Runs clarinet check for basic syntax validation
#>

# Configuration
$ErrorActionPreference = "Stop"
$rootDir = Split-Path -Parent $PSScriptRoot
$contractsDir = Join-Path $rootDir "contracts"
$clarinetToml = Join-Path $rootDir "Clarinet.toml"
$traitsFile = Join-Path $rootDir "contracts" "traits" "all-traits.clar"

# ANSI color codes
$RED = "\u001b[31m"
$GREEN = "\u001b[32m"
$YELLOW = "\u001b[33m"
$RESET = "\u001b[0m"

function Write-Header($message) {
    Write-Host "`n=== $($YELLOW)$($message)$($RESET) ===" -ForegroundColor Yellow
}

function Write-Success($message) {
    Write-Host "[${GREEN}✓${RESET}] $message"
}

function Write-ErrorMsg($message) {
    Write-Host "[${RED}✗${RESET}] $message" -ForegroundColor Red
}

function Write-Warning($message) {
    Write-Host "[${YELLOW}!${RESET}] $message" -ForegroundColor Yellow
}

function Test-CommandExists($command) {
    try {
        $null = Get-Command $command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-ContractFiles {
    param(
        [string]$directory = $contractsDir
    )
    
    Get-ChildItem -Path $directory -Filter "*.clar" -Recurse | 
        Where-Object { $_.FullName -notlike "*\test\*" -and $_.FullName -notlike "*\tests\*" } |
        ForEach-Object { $_.FullName }
}

function Test-ContractsInToml {
    Write-Header "Checking contract listings in Clarinet.toml"
    
    if (-not (Test-Path $clarinetToml)) {
        Write-ErrorMsg "Clarinet.toml not found at $clarinetToml"
        return $false
    }
    
    $config = Get-Content $clarinetToml -Raw | ConvertFrom-Toml
    $definedContracts = $config.contracts.Keys | ForEach-Object { $_ }
    $contractFiles = Get-ContractFiles
    $missing = @()
    
    foreach ($file in $contractFiles) {
        $contractName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $relativePath = $file.Substring($rootDir.Length + 1)
        
        if ($definedContracts -notcontains $contractName) {
            $missing += $relativePath
            Write-ErrorMsg "Contract not listed in Clarinet.toml: $relativePath"
        }
    }
    
    if ($missing.Count -eq 0) {
        Write-Success "All contracts are properly listed in Clarinet.toml"
        return $true
    } else {
        Write-ErrorMsg "$($missing.Count) contracts are missing from Clarinet.toml"
        return $false
    }
}

function Test-TraitReferences {
    Write-Header "Checking trait references"
    
    if (-not (Test-Path $traitsFile)) {
        Write-ErrorMsg "Traits file not found at $traitsFile"
        return $false
    }
    
    # Extract defined traits
    $traitContent = Get-Content $traitsFile -Raw
    $definedTraits = [regex]::Matches($traitContent, '\(define-trait\s+([^\s\n]+)') | 
        ForEach-Object { $_.Groups[1].Value }
    
    $contractFiles = Get-ContractFiles
    $hasErrors = $false
    
    foreach ($file in $contractFiles) {
        $content = Get-Content $file -Raw
        $relativePath = $file.Substring($rootDir.Length + 1)
        
        # Check use-trait statements
        $useTraitPattern = '\(use-trait\s+([^\s]+)\s+[''"]([^''"]+)[''"]\)'
        $useTraitMatches = [regex]::Matches($content, $useTraitPattern)
        foreach ($match in $useTraitMatches) {
            $traitName = $match.Groups[1].Value
            $traitRef = $match.Groups[2].Value
            
            # Skip if it's a fully qualified principal
            if ($traitRef -match '^[A-Z0-9]+\.') {
                continue
            }
            
            if ($definedTraits -notcontains $traitRef) {
                $line = ($content.Substring(0, $match.Index) -split '[\r\n]').Count
                Write-ErrorMsg "Undefined trait reference in $relativePath (line ~$line): $($match.Groups[0].Value)"
                $hasErrors = $true
            }
        }
        
        # Check impl-trait statements
        $implTraitPattern = '\(impl-trait\s+[''"]([^''"]+)[''"]\)'
        $implTraitMatches = [regex]::Matches($content, $implTraitPattern)
        foreach ($match in $implTraitMatches) {
            $traitRef = $match.Groups[1].Value
            
            # Skip if it's a fully qualified principal
            if ($traitRef -match '^[A-Z0-9]+\.') {
                continue
            }
            
            if ($definedTraits -notcontains $traitRef) {
                $line = ($content.Substring(0, $match.Index) -split '[\r\n]').Count
                Write-ErrorMsg "Undefined trait implementation in $relativePath (line ~$line): $($match.Groups[0].Value)"
                $hasErrors = $true
            }
        }
    }
    
    if (-not $hasErrors) {
        Write-Success "All trait references are valid"
        return $true
    } else {
        return $false
    }
}

function Test-ClarinetCheck {
    Write-Header "Running clarinet check"
    
    if (-not (Test-CommandExists "clarinet")) {
        Write-ErrorMsg "clarinet command not found. Please install it first."
        return $false
    }
    
    Push-Location $rootDir
    try {
        $output = & clarinet check 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "clarinet check failed with errors:"
            $output | ForEach-Object { Write-Host $_ }
            return $false
        } else {
            Write-Success "clarinet check passed"
            return $true
        }
    } finally {
        Pop-Location
    }
}

# Main execution
try {
    $results = @{
        ContractsInToml = Test-ContractsInToml
        TraitReferences = Test-TraitReferences
        ClarinetCheck = Test-ClarinetCheck
    }
    
    $success = $results.Values -notcontains $false
    
    Write-Header "Verification Summary"
    $results.GetEnumerator() | ForEach-Object {
        $status = if ($_.Value) { "${GREEN}PASS${RESET}" } else { "${RED}FAIL${RESET}" }
        Write-Host "$($_.Key.PadRight(20)): $status"
    }
    
    if ($success) {
        Write-Host "\n${GREEN}All verifications passed successfully!${RESET}" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "\n${RED}Some verifications failed. Please check the errors above.${RESET}" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-ErrorMsg "An error occurred: $_"
    Write-ErrorMsg $_.ScriptStackTrace
    exit 1
}
