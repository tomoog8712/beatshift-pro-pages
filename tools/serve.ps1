$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$indexFile = Get-ChildItem -Path $projectRoot -Recurse -Filter "index.html" |
    Where-Object { $_.DirectoryName -notmatch '\\tools\\' } |
    Select-Object -First 1
if (-not $indexFile) { throw "index.html not found under $projectRoot" }

$root = $indexFile.DirectoryName
$port = 8765
$serverScript = Join-Path $PSScriptRoot "static-server.js"

if (-not (Test-Path $serverScript)) {
    throw "Missing $serverScript"
}

& node $serverScript $root $port
