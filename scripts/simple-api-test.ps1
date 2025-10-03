# Simple Hiro API Test
param(
    [string]$ApiKey,
    [string]$ApiBase
)

if (-not $ApiKey) { $ApiKey = $env:HIRO_API_KEY }
if (-not $ApiBase) { $ApiBase = if ($env:STACKS_API_BASE) { $env:STACKS_API_BASE } else { "https://api.testnet.hiro.so" } }

if (-not $ApiKey) {
    Write-Host "HIRO_API_KEY not provided. Set env:HIRO_API_KEY or pass -ApiKey." -ForegroundColor Red
    exit 1
}

Write-Host "Testing Hiro API Integration..." -ForegroundColor Green

$headers = @{
    'X-API-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri "$ApiBase/extended/v1/status" -Headers $headers
    Write-Host "SUCCESS: API connection working" -ForegroundColor Green
    Write-Host "Chain ID: $($response.chain_id)" -ForegroundColor Cyan
    Write-Host "Network: $($response.network_id)" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Environment Setup:" -ForegroundColor Yellow
Write-Host "- API Base: $ApiBase" -ForegroundColor Gray
Write-Host "- API Key: $($ApiKey.Substring(0,8))..." -ForegroundColor Gray