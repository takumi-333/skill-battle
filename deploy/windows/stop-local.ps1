[CmdletBinding()]
param([switch]$Quiet)

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

function Stop-ManagedProcess([string]$Name, [string]$PidFile) {
    if (-not (Test-Path -LiteralPath $PidFile)) {
        if (-not $Quiet) { Write-Host "$Name is not managed by this launcher." }
        return
    }
    $record = Get-Content -Raw -LiteralPath $PidFile | ConvertFrom-Json
    $process = Get-Process -Id $record.id -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        Remove-Item -LiteralPath $PidFile
        if (-not $Quiet) { Write-Host "$Name was already stopped." }
        return
    }
    if (-not (Test-ProcessStartTimeMatch $process.StartTime $record.started_at)) {
        Write-Warning "$Name PID $($record.id) has been reused. Refusing to stop it. Inspect $PidFile."
        return
    }
    try {
        Stop-Process -Id $process.Id -ErrorAction Stop
    } catch {
        throw "Cannot stop $Name (PID $($process.Id)). It was likely started from another or elevated Windows session. Close it from the original terminal or Task Manager, then run start-local.bat as a standard user."
    }
    [void]$process.WaitForExit(5000)
    Remove-Item -LiteralPath $PidFile
    if (-not $Quiet) { Write-Host "Stopped $Name (PID $($process.Id))." }
}

Stop-ManagedProcess 'Dedicated Server' (Join-Path $StateDirectory 'dedicated.pid.json')
Stop-ManagedProcess 'Lobby' (Join-Path $StateDirectory 'lobby.pid.json')
