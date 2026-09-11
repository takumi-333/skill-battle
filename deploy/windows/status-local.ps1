[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StateDirectory = Join-Path $RepoRoot '.local-server'

function ConvertTo-UtcStartTimeTicks([object]$Value) {
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime.Ticks }
    if ($Value -is [DateTime]) { return $Value.ToUniversalTime().Ticks }
    return [DateTime]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime().Ticks
}

function Test-ProcessStartTimeMatch([DateTime]$ProcessStartTime, [object]$RecordedStartedAt) {
    try {
        return $ProcessStartTime.ToUniversalTime().Ticks -eq (ConvertTo-UtcStartTimeTicks $RecordedStartedAt)
    } catch {
        return $false
    }
}

function Get-ManagedStatus([string]$Name, [string]$PidFile) {
    if (-not (Test-Path -LiteralPath $PidFile)) {
        return [pscustomobject]@{ name = $Name; state = 'stopped'; pid = $null }
    }
    try {
        $record = Get-Content -Raw -LiteralPath $PidFile | ConvertFrom-Json
        $process = Get-Process -Id $record.id -ErrorAction SilentlyContinue
        if ($null -eq $process) {
            return [pscustomobject]@{ name = $Name; state = 'stopped'; pid = $record.id }
        }
        if (-not (Test-ProcessStartTimeMatch $process.StartTime $record.started_at)) {
            return [pscustomobject]@{ name = $Name; state = 'pid_reused'; pid = $record.id }
        }
        return [pscustomobject]@{ name = $Name; state = 'running'; pid = $record.id }
    } catch {
        return [pscustomobject]@{ name = $Name; state = 'state_file_error'; pid = $null }
    }
}

[pscustomobject]@{
    platform = 'Windows local launcher'
    lobby = Get-ManagedStatus 'Lobby' (Join-Path $StateDirectory 'lobby.pid.json')
    dedicated = Get-ManagedStatus 'Dedicated Server' (Join-Path $StateDirectory 'dedicated.pid.json')
} | ConvertTo-Json -Compress
