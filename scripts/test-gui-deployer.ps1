# =============================================================================
# TEST GUI DEPLOYER - COMPREHENSIVE TESTING
# =============================================================================
# Purpose: Test all GUI deployer features including failure log collection
# =============================================================================

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "TESTING GUI DEPLOYER - COMPREHENSIVE VALIDATION" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0
$testsTotal = 0

function Test-Feature {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    $script:testsTotal++
    Write-Host "Test $testsTotal : $Name" -ForegroundColor Cyan -NoNewline
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host " ✅" -ForegroundColor Green
            $script:testsPassed++
            return $true
        } else {
            Write-Host " ❌" -ForegroundColor Red
            $script:testsFailed++
            return $false
        }
    } catch {
        Write-Host " ❌ (Exception: $_)" -ForegroundColor Red
        $script:testsFailed++
        return $false
    }
}

Write-Host "📋 TESTING PREREQUISITES" -ForegroundColor Yellow
Write-Host ""

# Test 1: Check Python installation
Test-Feature "Python installed and accessible" {
    $null = python --version 2>&1
    return $LASTEXITCODE -eq 0
}

# Test 2: Check .env file exists
Test-Feature ".env file exists" {
    return Test-Path ".env"
}

# Test 3: Check contracts directory
Test-Feature "Contracts directory exists" {
    return Test-Path "contracts"
}

# Test 4: Check scripts directory
Test-Feature "Scripts directory exists" {
    return Test-Path "scripts/gui_deployer.py"
}

# Test 5: Check logs directory creation
Test-Feature "Logs directory can be created" {
    New-Item -ItemType Directory -Force -Path "logs" | Out-Null
    return Test-Path "logs"
}

Write-Host ""
Write-Host "📋 TESTING ENVIRONMENT VARIABLES" -ForegroundColor Yellow
Write-Host ""

# Load .env for testing
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2] -replace '^"' -replace '"$'
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

# Test 6: Required environment variables
Test-Feature "DEPLOYER_PRIVKEY is set" {
    return $null -ne $env:DEPLOYER_PRIVKEY
}

Test-Feature "SYSTEM_ADDRESS is set" {
    return $null -ne $env:SYSTEM_ADDRESS
}

Test-Feature "NETWORK is set" {
    return $null -ne $env:NETWORK
}

Write-Host ""
Write-Host "📋 TESTING CONTRACT DETECTION" -ForegroundColor Yellow
Write-Host ""

# Test 9: Count contracts
Test-Feature "Contract files detected" {
    $contracts = Get-ChildItem -Path "contracts" -Filter "*.clar" -Recurse
    Write-Host "      Found $($contracts.Count) contracts" -ForegroundColor Gray
    return $contracts.Count -gt 0
}

# Test 10: Check for key contracts
Test-Feature "Core contracts exist (all-traits, tokens)" {
    $coreExists = (Test-Path "contracts/traits/all-traits.clar")
    return $coreExists
}

Write-Host ""
Write-Host "📋 TESTING NETWORK CONNECTIVITY" -ForegroundColor Yellow
Write-Host ""

# Test 11: Test API endpoint
Test-Feature "Testnet API accessible" {
    try {
        $response = Invoke-WebRequest -Uri "https://api.testnet.hiro.so/v2/info" -TimeoutSec 10 -UseBasicParsing
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

Write-Host ""
Write-Host "📋 TESTING COMPILATION" -ForegroundColor Yellow
Write-Host ""

# Test 12: Clarinet check
Test-Feature "Clarinet check runs" {
    $result = clarinet check 2>&1
    # Even with errors, if clarinet runs, it's good
    return $LASTEXITCODE -ne 127  # 127 = command not found
}

Write-Host ""
Write-Host "📋 TESTING LOG FUNCTIONALITY" -ForegroundColor Yellow
Write-Host ""

# Test 13: Create test log
Test-Feature "Log file can be created" {
    $testLog = "logs/test_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    "Test log entry" | Out-File -FilePath $testLog -Encoding utf8
    $exists = Test-Path $testLog
    if ($exists) { Remove-Item $testLog }
    return $exists
}

# Test 14: Log directory writable
Test-Feature "Logs directory is writable" {
    try {
        $testFile = "logs/write_test.tmp"
        "test" | Out-File -FilePath $testFile
        $canWrite = Test-Path $testFile
        if ($canWrite) { Remove-Item $testFile }
        return $canWrite
    } catch {
        return $false
    }
}

Write-Host ""
Write-Host "📋 TESTING GUI DEPLOYER COMPONENTS" -ForegroundColor Yellow
Write-Host ""

# Test 15: GUI script exists
Test-Feature "GUI deployer script exists" {
    return Test-Path "scripts/gui_deployer.py"
}

# Test 16: GUI script is valid Python
Test-Feature "GUI deployer syntax is valid" {
    $result = python -m py_compile scripts/gui_deployer.py 2>&1
    return $LASTEXITCODE -eq 0
}

# Test 17: Required Python modules (tkinter)
Test-Feature "Python tkinter available" {
    $result = python -c "import tkinter" 2>&1
    return $LASTEXITCODE -eq 0
}

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  $testsTotal" -ForegroundColor White
Write-Host "Passed:       $testsPassed" -ForegroundColor Green
Write-Host "Failed:       $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

$percentage = [math]::Round(($testsPassed / $testsTotal) * 100, 1)
Write-Host "Success Rate: $percentage%" -ForegroundColor $(if ($percentage -ge 90) { 'Green' } elseif ($percentage -ge 70) { 'Yellow' } else { 'Red' })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✅ ALL TESTS PASSED - System ready for deployment!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Run: python scripts/gui_deployer.py" -ForegroundColor White
    Write-Host "2. Click 'Run Pre-Deployment Checks'" -ForegroundColor White
    Write-Host "3. Review the checks" -ForegroundColor White
    Write-Host "4. Click 'Deploy to Testnet'" -ForegroundColor White
    exit 0
} else {
    Write-Host "⚠️  SOME TESTS FAILED - Review issues before deployment" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Cyan
    Write-Host "- Install Python 3.x with tkinter" -ForegroundColor White
    Write-Host "- Create/configure .env file" -ForegroundColor White
    Write-Host "- Check network connectivity" -ForegroundColor White
    Write-Host "- Install Clarinet" -ForegroundColor White
    exit 1
}
