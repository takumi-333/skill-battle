[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [string]$OutputRoot = '',
    [int]$ExportTimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $repoRoot 'build\releases'
}

$candidates = @($GodotPath, $env:GODOT)
$fromPath = Get-Command godot.exe,godot -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $fromPath) {
    $candidates += $fromPath.Source
}
$godot = $candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if ($null -eq $godot) {
    throw 'Godot 4 executable was not found. Install the matching export templates, then pass -GodotPath or add godot.exe to PATH.'
}
if ($ExportTimeoutSeconds -lt 1) {
    throw 'ExportTimeoutSeconds must be at least 1.'
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$packageName = "SkillBattle-Windows-x64-$timestamp"
$releaseDirectory = Join-Path $OutputRoot $packageName
$executablePath = Join-Path $releaseDirectory 'SkillBattle.exe'
$archivePath = Join-Path $OutputRoot "$packageName.zip"
$startHereSource = Join-Path $PSScriptRoot 'CLIENT_START_HERE.txt'

if (-not (Test-Path -LiteralPath $startHereSource -PathType Leaf)) {
    throw "Missing client guide: $startHereSource"
}
New-Item -ItemType Directory -Path $releaseDirectory -ErrorAction Stop | Out-Null

& $godot --headless --path $repoRoot --export-release 'Windows Client' $executablePath
$exportSucceeded = $?
$exportExitCode = $LASTEXITCODE
if (-not $exportSucceeded) {
    $exitDescription = if ($null -eq $exportExitCode) { 'unknown' } else { $exportExitCode }
    throw "Godot release export failed with exit code $exitDescription. Confirm that the Windows export templates matching this Godot version are installed."
}

# Godot can return from the export command before its asynchronous savepack
# phase has written the executable. Wait for a non-empty, stable output before
# creating the ZIP so a slow export is not reported as a false failure.
Write-Host "Waiting for the export output to finish (up to $ExportTimeoutSeconds seconds)..."
$deadline = [DateTime]::UtcNow.AddSeconds($ExportTimeoutSeconds)
[long]$lastLength = -1
$stableSamples = 0
while ([DateTime]::UtcNow -lt $deadline -and $stableSamples -lt 2) {
    if (Test-Path -LiteralPath $executablePath -PathType Leaf) {
        [long]$currentLength = (Get-Item -LiteralPath $executablePath -ErrorAction Stop).Length
        if ($currentLength -gt 0 -and $currentLength -eq $lastLength) {
            $stableSamples++
        } else {
            $lastLength = $currentLength
            $stableSamples = 0
        }
    }
    if ($stableSamples -lt 2) {
        Start-Sleep -Seconds 1
    }
}
if ($stableSamples -lt 2) {
    throw "Godot reported success but did not finish writing $executablePath within $ExportTimeoutSeconds seconds."
}

Copy-Item -LiteralPath $startHereSource -Destination (Join-Path $releaseDirectory 'START_HERE.txt') -ErrorAction Stop
Compress-Archive -LiteralPath $releaseDirectory -DestinationPath $archivePath -CompressionLevel Optimal -ErrorAction Stop
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$archivePath.sha256" -Value "$archiveHash  $(Split-Path -Leaf $archivePath)" -Encoding ascii

Write-Host "Created Windows client archive: $archivePath"
Write-Host "SHA-256: $archiveHash"
Write-Host 'Share the ZIP with the friend. Send the Lobby HTTPS URL and invite token separately; they are intentionally not embedded in this archive.'
