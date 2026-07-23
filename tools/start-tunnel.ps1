$ErrorActionPreference = "Stop"
$toolsDir = $PSScriptRoot
$cloudflared = Join-Path $toolsDir "cloudflared.exe"
$logFile = Join-Path $toolsDir "tunnel.log"
$port = 8765

if (-not (Test-Path $cloudflared)) {
    curl.exe -L "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -o $cloudflared
}

Remove-Item $logFile -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $cloudflared -ArgumentList @(
    "tunnel", "--url", "http://127.0.0.1:$port", "--logfile", $logFile, "--loglevel", "info"
) -WindowStyle Hidden

$urlFile = Join-Path $toolsDir "public-url.txt"
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $logFile) {
        $log = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        if ($log -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
            $Matches[0] | Set-Content -Path $urlFile -Encoding UTF8
            Write-Output $Matches[0]
            exit 0
        }
    }
}
Write-Error "Tunnel URL not found. See $logFile"
