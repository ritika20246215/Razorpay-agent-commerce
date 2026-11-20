param(
    [int]$Port = 0
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..."
    python -m venv .venv
}

# Auto-detect available port if not explicitly given
if ($Port -eq 0) {
    $candidates = @(8000, 8765, 8080)
    foreach ($p in $candidates) {
        $conn = Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue
        if (-not $conn) {
            $Port = $p
            break
        }
    }
    if ($Port -eq 0) { $Port = 8000 }
}

$url = "http://127.0.0.1:$Port/dashboard"
$docs = "http://127.0.0.1:$Port/docs"

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Razorpay Agent Commerce Layer" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Port         : $Port" -ForegroundColor Yellow
Write-Host "Dashboard    : $url" -ForegroundColor Yellow
Write-Host "API Docs     : $docs" -ForegroundColor Yellow
Write-Host "-------------------------------------------------------"
Write-Host "Launching dashboard in default browser..." -ForegroundColor Cyan
Start-Process $url

Write-Host "Starting Uvicorn server (Press Ctrl+C to stop)..." -ForegroundColor Green
& ".\.venv\Scripts\python.exe" -m uvicorn app.main:app --reload --port $Port
