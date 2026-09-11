[CmdletBinding()]
param(
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$null = . (Join-Path $PSScriptRoot 'local-common.ps1')
$RepoRoot = $script:RepoRoot
$StateDirectory = $script:StateDirectory
$LobbyDirectory = Join-Path $RepoRoot 'server\lobby'
$LobbyPidPath = Join-Path $StateDirectory 'lobby.pid.json'
$DedicatedPidPath = Join-Path $StateDirectory 'dedicated.pid.json'
$LobbyUrl = 'http://127.0.0.1:8000'

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

function Get-ManagedProcess([string]$Name, [string]$PidPath) {
    if (-not (Test-Path -LiteralPath $PidPath)) { return $null }
    $record = Get-Content -Raw -LiteralPath $PidPath | ConvertFrom-Json
    $process = Get-Process -Id $record.id -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        Remove-Item -LiteralPath $PidPath
        return $null
    }
    if (-not (Test-ProcessStartTimeMatch $process.StartTime $record.started_at)) {
        throw "$Name PID $($record.id) has been reused. It will not be stopped or replaced; inspect $PidPath."
    }
    return $process
}

function Assert-PortFree([int]$Port, [string]$Protocol) {
    $used = if ($Protocol -eq 'TCP') {
        Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    } else {
        Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue
    }
    if ($null -ne $used) { throw "$Protocol port $Port is already in use. Stop the existing server before launching." }
}

function Get-VenvPython {
    $venv = Join-Path $LobbyDirectory '.venv'
    $python = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        $py = Get-Command py.exe -ErrorAction SilentlyContinue
        if ($null -eq $py) { throw 'Python launcher (py.exe) was not found. Install Python 3.11+ and run this launcher again.' }
        Write-Host 'Creating Lobby Python virtual environment...'
        & $py.Source -m venv $venv
    }
    & $python -c 'import fastapi, uvicorn' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Installing Lobby dependencies...'
        & $python -m pip install --disable-pip-version-check -r (Join-Path $LobbyDirectory 'requirements.txt')
    }
    return $python
}

function Get-GodotConsole {
    $candidates = @($env:GODOT_CONSOLE, 'C:\Godot\godot_console.exe')
    $fromPath = Get-Command godot_console.exe -ErrorAction SilentlyContinue
    if ($null -ne $fromPath) { $candidates += $fromPath.Source }
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    throw 'Godot console executable was not found. Set GODOT_CONSOLE to godot_console.exe, then run this launcher again.'
}

function Join-ProcessArguments([string[]]$Values) {
    return (($Values | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' ')
}

function Start-ManagedProcess([string]$Name, [string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory, [string]$PidPath) {
    $stdout = Join-Path $StateDirectory "$Name.stdout.log"
    $stderr = Join-Path $StateDirectory "$Name.stderr.log"
    $process = Start-Process -FilePath $FilePath -ArgumentList (Join-ProcessArguments $Arguments) -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    @{ id = $process.Id; started_at = $process.StartTime.ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $PidPath -Encoding utf8
    return $process
}

function Wait-LobbyHealth {
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing "$LobbyUrl/healthz" -TimeoutSec 1
            if ($response.StatusCode -eq 200) { return }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    throw "Lobby did not become ready. See $(Join-Path $StateDirectory 'lobby.stderr.log')."
}

$config = Get-LocalConfig
Write-LocalClientConfig $config
foreach ($entry in $config.GetEnumerator()) { Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value }

$existingLobby = Get-ManagedProcess 'Lobby' $LobbyPidPath
$existingDedicated = Get-ManagedProcess 'Dedicated Server' $DedicatedPidPath
try {
    if ($null -eq $existingLobby) {
        Assert-PortFree 8000 'TCP'
        $python = Get-VenvPython
        Start-ManagedProcess 'lobby' $python @('-m', 'uvicorn', 'app:app', '--host', '127.0.0.1', '--port', '8000', '--workers', '1') $LobbyDirectory $LobbyPidPath | Out-Null
        Wait-LobbyHealth
    } else {
        Write-Host "Lobby is already running (PID $($existingLobby.Id))."
    }
    if ($null -eq $existingDedicated) {
        Assert-PortFree ([int]$config['SKILL_BATTLE_SERVER_LISTEN_PORT']) 'UDP'
        $godot = Get-GodotConsole
        Start-ManagedProcess 'dedicated' $godot @('--headless', '--path', $RepoRoot, '--scene', 'res://scenes/server_main.tscn') $RepoRoot $DedicatedPidPath | Out-Null
        Start-Sleep -Seconds 2
        if ($null -eq (Get-ManagedProcess 'Dedicated Server' $DedicatedPidPath)) { throw "Dedicated Server exited. See $(Join-Path $StateDirectory 'dedicated.stderr.log')." }
    } else {
        Write-Host "Dedicated Server is already running (PID $($existingDedicated.Id))."
    }
    Write-Host 'Lobby and Dedicated Server are ready.'
} catch {
    & (Join-Path $PSScriptRoot 'stop-local.ps1') -Quiet
    throw
}

Write-Host "Management UI: $LobbyUrl/admin"
if (-not $NoBrowser) {
    # Fragments are never sent to the server. admin.html moves this local-only
    # token into sessionStorage immediately, then clears the address bar.
    Start-Process "$LobbyUrl/admin#token=$($config['SKILL_BATTLE_ADMIN_TOKEN'])"
}
