[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 16)]
    [int]$ClientCount
)

$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$LocalStateDirectory = Join-Path $RepoRoot '.local-server'
$ClientStateDirectory = Join-Path $LocalStateDirectory 'debug-clients'
$ClientStatePath = Join-Path $ClientStateDirectory 'clients.json'
$ServerLauncher = Join-Path $RepoRoot 'deploy\windows\start-local.ps1'
$ServerStatus = Join-Path $RepoRoot 'deploy\windows\status-local.ps1'

function Get-GodotGui {
    $candidates = @($env:GODOT, 'C:\Godot\godot.exe')
    $fromPath = Get-Command godot.exe -ErrorAction SilentlyContinue
    if ($null -ne $fromPath) { $candidates += $fromPath.Source }
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    throw 'Godot GUI executable was not found. Set GODOT to godot.exe and retry.'
}

if (-not (Test-Path -LiteralPath $ServerLauncher)) {
    throw "Local server launcher was not found: $ServerLauncher"
}

& $ServerLauncher -NoBrowser
New-Item -ItemType Directory -Force -Path $ClientStateDirectory | Out-Null

$godot = Get-GodotGui
$clients = @()
for ($index = 1; $index -le $ClientCount; $index++) {
    $userDataDirectory = Join-Path $ClientStateDirectory ('client-{0:D2}' -f $index)
    New-Item -ItemType Directory -Force -Path $userDataDirectory | Out-Null
    $x = 80 * ($index - 1)
    $y = 60 * ($index - 1)
    $process = Start-Process -FilePath $godot -WorkingDirectory $RepoRoot -ArgumentList @('--path', $RepoRoot, '--user-data-dir', $userDataDirectory, '--position', "$x,$y") -PassThru
    $clients += [pscustomobject]@{
        index = $index
        id = $process.Id
        started_at = $process.StartTime.ToUniversalTime().ToString('o')
        user_data_dir = $userDataDirectory
    }
}

$clients | ConvertTo-Json | Set-Content -LiteralPath $ClientStatePath -Encoding utf8
Start-Sleep -Seconds 1

$failed = @($clients | Where-Object { $null -eq (Get-Process -Id $_.id -ErrorAction SilentlyContinue) })
if ($failed.Count -gt 0) {
    $failedIds = ($failed | ForEach-Object { $_.id }) -join ', '
    throw "One or more game clients exited during startup: $failedIds"
}

[pscustomobject]@{
    server = (& $ServerStatus | ConvertFrom-Json)
    clients = $clients
} | ConvertTo-Json -Depth 4
