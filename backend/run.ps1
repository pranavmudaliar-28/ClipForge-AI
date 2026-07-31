# Creates a Python 3.12 venv, installs deps, and runs the ClipForge AI worker.
# Python 3.14 (the machine default) has no torch/CTranslate2 wheels, so the
# worker MUST run on 3.12.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path ".venv")) {
    Write-Host "Creating Python 3.12 venv..." -ForegroundColor Cyan
    py -3.12 -m venv .venv
}

$py = ".\.venv\Scripts\python.exe"
& $py -m pip install --upgrade pip
& $py -m pip install -r requirements.txt

Write-Host "Starting worker on http://0.0.0.0:8000 (emulator: http://10.0.2.2:8000)" -ForegroundColor Green
& $py -m uvicorn app.main:app --host 0.0.0.0 --port 8000
