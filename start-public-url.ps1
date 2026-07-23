# BeatShift Pro - Public URL launcher (no Node.js required)

$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = Split-Path -Parent (Get-Item $MyInvocation.MyCommand.Path).FullName
}
$toolsDir = Join-Path $projectRoot "tools"
$port = 8765
$urlFile = Join-Path $toolsDir "public-url.txt"
$cloudflared = Join-Path $toolsDir "cloudflared.exe"

$indexFile = Get-ChildItem -Path $projectRoot -Recurse -Filter "index.html" |
    Where-Object { $_.DirectoryName -notmatch '\\tools\\' } |
    Select-Object -First 1
if (-not $indexFile) { throw "index.html not found under $projectRoot" }

if (-not (Test-Path $cloudflared)) {
    Write-Host "Downloading cloudflared..."
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    curl.exe -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -o $cloudflared
}

Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*serve.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

$serveScript = Join-Path $toolsDir "serve.ps1"
Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$serveScript`"" -WindowStyle Hidden
Start-Sleep -Seconds 2

$tunnelScript = Join-Path $toolsDir "start-tunnel.ps1"
$publicUrl = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tunnelScript

Write-Host ""
Write-Host "========================================"
Write-Host " Public URL (open on iPhone 4G):"
Write-Host " $publicUrl"
Write-Host "========================================"
Write-Host ""
Write-Host "Local: http://127.0.0.1:$port/"
Write-Host "Saved: $urlFile"
Write-Host ""
Write-Host "Server and tunnel are running in background."
Write-Host "Keep this PC on. Stop with tools\stop-public-url.ps1"
Write-Host ""
