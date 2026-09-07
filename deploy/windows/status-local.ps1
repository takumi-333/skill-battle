[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StateDirectory = Join-Path $RepoRoot '.local-server'

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
        if ($process.StartTime.ToUniversalTime().ToString('o') -ne $record.started_at) {
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
