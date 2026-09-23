[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$ClientStatePath = Join-Path $RepoRoot '.local-server\debug-clients\clients.json'

function ConvertTo-UtcStartTimeTicks([object]$Value) {
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime.Ticks }
    if ($Value -is [DateTime]) { return $Value.ToUniversalTime().Ticks }
    return [DateTime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime().Ticks
}

if (-not (Test-Path -LiteralPath $ClientStatePath)) {
    Write-Host 'No debug client state file was found.'
    exit 0
}

$records = @(Get-Content -Raw -LiteralPath $ClientStatePath | ConvertFrom-Json)
foreach ($record in $records) {
    $process = Get-Process -Id $record.id -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        Write-Host "Client $($record.index) was already stopped."
        continue
    }
    if ($process.StartTime.ToUniversalTime().Ticks -ne (ConvertTo-UtcStartTimeTicks $record.started_at)) {
        Write-Warning "Client $($record.index) PID $($record.id) was reused. Refusing to stop it."
        continue
    }
    Stop-Process -Id $process.Id -ErrorAction Stop
    Write-Host "Stopped debug client $($record.index) (PID $($process.Id))."
}

Remove-Item -LiteralPath $ClientStatePath
