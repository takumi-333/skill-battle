[CmdletBinding()]
param(
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StateDirectory = Join-Path $RepoRoot '.local-server'
$ConfigPath = Join-Path $StateDirectory 'local.env'
$LobbyDirectory = Join-Path $RepoRoot 'server\lobby'
$LobbyPidPath = Join-Path $StateDirectory 'lobby.pid.json'
$DedicatedPidPath = Join-Path $StateDirectory 'dedicated.pid.json'
$LobbyUrl = 'http://127.0.0.1:8000'

function New-LocalSecret {
    $bytes = New-Object byte[] 48
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
}

function Read-LocalConfig {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        New-Item -ItemType Directory -Force -Path $StateDirectory | Out-Null
        @(
            "SKILL_BATTLE_TOKEN_SECRET=$(New-LocalSecret)"
            "SKILL_BATTLE_ADMIN_TOKEN=$(New-LocalSecret)"
            "SKILL_BATTLE_INTERNAL_API_TOKEN=$(New-LocalSecret)"
            'SKILL_BATTLE_LOBBY_INTERNAL_URL=http://127.0.0.1:8000'
            # 17000 avoids colliding with the usual production UDP 7000
            # when a developer is also connected to a remote test server.
            'SKILL_BATTLE_SERVER_PORT=17000'
        ) | Set-Content -LiteralPath $ConfigPath -Encoding utf8
        Write-Host "Created local secrets: $ConfigPath"
    }

    $config = @{}
    foreach ($line in Get-Content -LiteralPath $ConfigPath) {
        $line = $line.TrimStart([char]0xFEFF)
        if ($line -match '^([A-Z0-9_]+)=(.*)$') { $config[$matches[1]] = $matches[2] }
    }
    foreach ($required in 'SKILL_BATTLE_TOKEN_SECRET', 'SKILL_BATTLE_ADMIN_TOKEN', 'SKILL_BATTLE_INTERNAL_API_TOKEN', 'SKILL_BATTLE_LOBBY_INTERNAL_URL', 'SKILL_BATTLE_SERVER_PORT') {
        if (-not $config.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($config[$required])) {
            throw "Missing $required in $ConfigPath"
        }
    }
    return $config
}

function Get-ManagedProcess([string]$Name, [string]$PidPath) {
    if (-not (Test-Path -LiteralPath $PidPath)) { return $null }
    $record = Get-Content -Raw -LiteralPath $PidPath | ConvertFrom-Json
    $process = Get-Process -Id $record.id -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        Remove-Item -LiteralPath $PidPath
        return $null
    }
    if ($process.StartTime.ToUniversalTime().ToString('o') -ne $record.started_at) {
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

$config = Read-LocalConfig
foreach ($entry in $config.GetEnumerator()) { Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value }

$existingLobby = Get-ManagedProcess 'Lobby' $LobbyPidPath
$existingDedicated = Get-ManagedProcess 'Dedicated Server' $DedicatedPidPath
try {
    if ($null -eq $existingLobby) {
        Assert-PortFree 8000 'TCP'
        $python = Get-VenvPython
        Start-ManagedProcess 'lobby' $python @('-m', 'uvicorn', 'app:app', '--host', '127.0.0.1', '--port', '8000') $LobbyDirectory $LobbyPidPath | Out-Null
        Wait-LobbyHealth
    } else {
        Write-Host "Lobby is already running (PID $($existingLobby.Id))."
    }
    if ($null -eq $existingDedicated) {
        Assert-PortFree ([int]$config['SKILL_BATTLE_SERVER_PORT']) 'UDP'
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
