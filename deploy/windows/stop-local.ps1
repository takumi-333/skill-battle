[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StateDirectory = Join-Path $RepoRoot '.local-server'

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
    if ($process.StartTime.ToUniversalTime().ToString('o') -ne $record.started_at) {
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
