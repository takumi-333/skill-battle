$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:StateDirectory = Join-Path $script:RepoRoot '.local-server'
$script:PublicConfigPath = Join-Path $script:StateDirectory 'public.env'
$script:PublicLobbyDatabasePath = Join-Path $script:StateDirectory 'public-lobby.db'
$script:LobbyDirectory = Join-Path $script:RepoRoot 'server\lobby'
$script:GatewayDirectory = Join-Path $script:RepoRoot 'server\public_gateway'

function New-PublicSecret {
    $bytes = New-Object byte[] 48
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [Convert]::ToHexString($bytes).ToLowerInvariant()
}

function Set-CurrentUserOnlyAcl([string]$Path, [switch]$Directory) {
    $account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($Directory) {
        & icacls $Path /inheritance:r /grant:r "${account}:(OI)(CI)(F)" | Out-Null
    } else {
        & icacls $Path /inheritance:r /grant:r "${account}:(R,W)" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "Could not restrict ACL for $Path" }
}

function Ensure-PublicConfig {
    if (Test-Path -LiteralPath $script:PublicConfigPath) {
        Set-CurrentUserOnlyAcl $script:StateDirectory -Directory
        Set-CurrentUserOnlyAcl $script:PublicConfigPath
        return
    }
    New-Item -ItemType Directory -Force -Path $script:StateDirectory | Out-Null
    Set-CurrentUserOnlyAcl $script:StateDirectory -Directory
    @(
        "SKILL_BATTLE_TOKEN_SECRET=$(New-PublicSecret)"
        "SKILL_BATTLE_ADMIN_TOKEN=$(New-PublicSecret)"
        "SKILL_BATTLE_INTERNAL_API_TOKEN=$(New-PublicSecret)"
        "SKILL_BATTLE_PUBLIC_ACCESS_TOKEN=$(New-PublicSecret)"
        "SKILL_BATTLE_LOBBY_DB=$script:PublicLobbyDatabasePath"
        'SKILL_BATTLE_LOBBY_INTERNAL_URL=http://127.0.0.1:8000'
        'SKILL_BATTLE_SERVER_LISTEN_PORT=7000'
        'SKILL_BATTLE_SERVER_ADDRESS='
        'SKILL_BATTLE_SERVER_PORT='
        'SKILL_BATTLE_PLAYIT_FORWARD_TARGET=127.0.0.1:7000'
        'SKILL_BATTLE_UVICORN_WORKERS=1'
        'SKILL_BATTLE_PUBLIC_MODE=1'
        'SKILL_BATTLE_REQUIRE_LOBBY_CONSUME=1'
    ) | Set-Content -LiteralPath $script:PublicConfigPath -Encoding utf8
    Set-CurrentUserOnlyAcl $script:PublicConfigPath
    Write-Host "Created $script:PublicConfigPath. Set SKILL_BATTLE_SERVER_ADDRESS and SKILL_BATTLE_SERVER_PORT from playit.gg before starting public services."
}

function Get-PublicConfig {
    Ensure-PublicConfig
    $config = @{}
    foreach ($line in Get-Content -LiteralPath $script:PublicConfigPath) {
        $line = $line.TrimStart([char]0xFEFF)
        if ($line -match '^([A-Z0-9_]+)=(.*)$') { $config[$matches[1]] = $matches[2] }
    }
    if (-not $config.ContainsKey('SKILL_BATTLE_LOBBY_DB') -or [string]::IsNullOrWhiteSpace($config['SKILL_BATTLE_LOBBY_DB'])) {
        $config['SKILL_BATTLE_LOBBY_DB'] = $script:PublicLobbyDatabasePath
        Add-Content -LiteralPath $script:PublicConfigPath -Value "SKILL_BATTLE_LOBBY_DB=$script:PublicLobbyDatabasePath" -Encoding utf8
        Set-CurrentUserOnlyAcl $script:PublicConfigPath
    }
    $required = @('SKILL_BATTLE_TOKEN_SECRET','SKILL_BATTLE_ADMIN_TOKEN','SKILL_BATTLE_INTERNAL_API_TOKEN','SKILL_BATTLE_PUBLIC_ACCESS_TOKEN','SKILL_BATTLE_LOBBY_DB','SKILL_BATTLE_LOBBY_INTERNAL_URL','SKILL_BATTLE_SERVER_LISTEN_PORT','SKILL_BATTLE_SERVER_ADDRESS','SKILL_BATTLE_SERVER_PORT','SKILL_BATTLE_PLAYIT_FORWARD_TARGET','SKILL_BATTLE_UVICORN_WORKERS','SKILL_BATTLE_PUBLIC_MODE','SKILL_BATTLE_REQUIRE_LOBBY_CONSUME')
    foreach ($key in $required) {
        if (-not $config.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($config[$key])) { throw "Missing $key in $script:PublicConfigPath" }
    }
    foreach ($key in 'SKILL_BATTLE_TOKEN_SECRET','SKILL_BATTLE_ADMIN_TOKEN','SKILL_BATTLE_INTERNAL_API_TOKEN','SKILL_BATTLE_PUBLIC_ACCESS_TOKEN') {
        if ($config[$key].Length -lt 32) { throw "$key is too short in $script:PublicConfigPath" }
    }
    $secrets = @('SKILL_BATTLE_TOKEN_SECRET','SKILL_BATTLE_ADMIN_TOKEN','SKILL_BATTLE_INTERNAL_API_TOKEN','SKILL_BATTLE_PUBLIC_ACCESS_TOKEN') | ForEach-Object { $config[$_] }
    if (($secrets | Select-Object -Unique).Count -ne $secrets.Count) { throw 'Public secrets must not be reused across roles.' }
    if ($config['SKILL_BATTLE_UVICORN_WORKERS'] -ne '1') { throw 'Public Lobby must use exactly one uvicorn worker.' }
    if ($config['SKILL_BATTLE_PUBLIC_MODE'] -ne '1' -or $config['SKILL_BATTLE_REQUIRE_LOBBY_CONSUME'] -ne '1') { throw 'Public mode must require loopback binding and Lobby nonce consumption.' }
    if ($config['SKILL_BATTLE_SERVER_LISTEN_PORT'] -ne '7000' -or $config['SKILL_BATTLE_PLAYIT_FORWARD_TARGET'] -ne '127.0.0.1:7000') { throw 'This deployment requires playit.gg forwarding to 127.0.0.1:7000.' }
    $configuredDatabasePath = [IO.Path]::GetFullPath([string]$config['SKILL_BATTLE_LOBBY_DB'])
    $expectedDatabasePath = [IO.Path]::GetFullPath($script:PublicLobbyDatabasePath)
    if (-not [string]::Equals($configuredDatabasePath, $expectedDatabasePath, [StringComparison]::OrdinalIgnoreCase)) { throw "Public Lobby DB must be $expectedDatabasePath." }
    $config['SKILL_BATTLE_LOBBY_DB'] = $expectedDatabasePath
    return $config
}

function Set-PublicProcessEnvironment([hashtable]$Config) {
    foreach ($entry in $Config.GetEnumerator()) { Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value }
}

function Get-PublicPidPath([string]$Name) { Join-Path $script:StateDirectory "$Name.pid.json" }

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

function Get-ManagedProcess([string]$Name) {
    $pidPath = Get-PublicPidPath $Name
    if (-not (Test-Path -LiteralPath $pidPath)) { return $null }
    $record = Get-Content -Raw -LiteralPath $pidPath | ConvertFrom-Json
    $process = Get-Process -Id $record.id -ErrorAction SilentlyContinue
    if ($null -eq $process) { Remove-Item -LiteralPath $pidPath; return $null }
    if (-not (Test-ProcessStartTimeMatch $process.StartTime $record.started_at)) { throw "$Name PID $($record.id) has been reused or has an invalid start-time record; refusing to manage it." }
    return $process
}

function Stop-ManagedProcess([string]$Name, [switch]$Quiet) {
    $pidPath = Get-PublicPidPath $Name
    $process = Get-ManagedProcess $Name
    if ($null -eq $process) { if (-not $Quiet) { Write-Host "$Name is not running." }; return }
    Stop-Process -Id $process.Id -ErrorAction Stop
    [void]$process.WaitForExit(5000)
    Remove-Item -LiteralPath $pidPath
    if (-not $Quiet) { Write-Host "Stopped $Name (PID $($process.Id))." }
}

function Get-ManagedStatus([string]$Name) {
    try {
        $process = Get-ManagedProcess $Name
        if ($null -eq $process) { return [pscustomobject]@{ name=$Name; state='stopped'; pid=$null } }
        return [pscustomobject]@{ name=$Name; state='running'; pid=$process.Id }
    } catch { return [pscustomobject]@{ name=$Name; state='pid_reused_or_state_error'; pid=$null } }
}

function Assert-ManagedServiceRunning([object]$Status) {
    if ($null -eq $Status -or $Status.state -ne 'running') {
        $name = if ($null -eq $Status) { 'Managed service' } else { [string]$Status.name }
        throw "$name is not running."
    }
}

function Assert-HttpHealthResponse([object]$Response, [string]$Name, [switch]$RequireProtectedApiReady) {
    if ($null -eq $Response -or $Response.StatusCode -ne 200) { throw "$Name health check did not return HTTP 200." }
    if (-not $RequireProtectedApiReady) { return }
    try { $payload = ([string]$Response.Content | ConvertFrom-Json -ErrorAction Stop) } catch { throw "$Name health check did not return JSON." }
    if ($payload.protected_api_ready -ne $true) { throw "$Name reports protected_api_ready is not true." }
}

function Assert-HttpHealth([string]$Url, [string]$Name, [switch]$RequireProtectedApiReady) {
    try { $response = Invoke-WebRequest -UseBasicParsing "$Url/healthz" -TimeoutSec 2 } catch { throw "$Name health check failed." }
    Assert-HttpHealthResponse $response $Name -RequireProtectedApiReady:$RequireProtectedApiReady
}

function Assert-PortFree([int]$Port, [string]$Protocol) {
    $used = if ($Protocol -eq 'TCP') { Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue } else { Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue }
    if ($null -ne $used) { throw "$Protocol port $Port is already in use." }
}

function Get-LobbyPython {
    $venv = Join-Path $script:LobbyDirectory '.venv'
    $python = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        $py = Get-Command py.exe -ErrorAction SilentlyContinue
        if ($null -eq $py) { throw 'Python launcher (py.exe) was not found.' }
        & $py.Source -m venv $venv
    }
    & $python -c 'import fastapi,uvicorn,httpx' 2>$null
    if ($LASTEXITCODE -ne 0) { & $python -m pip install --disable-pip-version-check -r (Join-Path $script:LobbyDirectory 'requirements.txt') }
    return $python
}

function Get-GodotConsole {
    $candidates = @($env:GODOT_CONSOLE, 'C:\Godot\godot_console.exe')
    $fromPath = Get-Command godot_console.exe -ErrorAction SilentlyContinue
    if ($null -ne $fromPath) { $candidates += $fromPath.Source }
    foreach ($candidate in $candidates) { if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) { return $candidate } }
    throw 'Godot console executable was not found. Set GODOT_CONSOLE to godot_console.exe.'
}

function Join-ProcessArguments([string[]]$Values) { (($Values | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' ') }

function Start-ManagedProcess([string]$Name, [string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory) {
    $stdout = Join-Path $script:StateDirectory "$Name.stdout.log"
    $stderr = Join-Path $script:StateDirectory "$Name.stderr.log"
    $process = Start-Process -FilePath $FilePath -ArgumentList (Join-ProcessArguments $Arguments) -WorkingDirectory $WorkingDirectory -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    @{ id=$process.Id; started_at=$process.StartTime.ToUniversalTime().ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath (Get-PublicPidPath $Name) -Encoding utf8
    Set-CurrentUserOnlyAcl (Get-PublicPidPath $Name)
    return $process
}

function Wait-HttpHealth([string]$Url, [string]$Name) {
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try { if ((Invoke-WebRequest -UseBasicParsing "$Url/healthz" -TimeoutSec 1).StatusCode -eq 200) { return } } catch { Start-Sleep -Milliseconds 500 }
    }
    throw "$Name did not become healthy. Inspect .local-server logs without sharing their contents."
}

function Get-FunnelProxyTargets([object]$Value) {
    if ($null -eq $Value -or $Value -is [string]) { return }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($entry in $Value.GetEnumerator()) {
            if ([string]$entry.Key -eq 'Proxy' -and $entry.Value -is [string]) {
                Write-Output ([string]$entry.Value)
            } else {
                Get-FunnelProxyTargets $entry.Value
            }
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) { Get-FunnelProxyTargets $item }
        return
    }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.Name -eq 'Proxy' -and $property.Value -is [string]) {
            Write-Output ([string]$property.Value)
        } else {
            Get-FunnelProxyTargets $property.Value
        }
    }
}

function Test-FunnelProxyTargets([string[]]$Targets) {
    if ($Targets.Count -ne 1) { return $false }
    try { $uri = [Uri]$Targets[0] } catch { return $false }
    return $uri.Scheme -eq 'http' -and $uri.Host -eq '127.0.0.1' -and $uri.Port -eq 8080 -and $uri.AbsolutePath -eq '/' -and [string]::IsNullOrEmpty($uri.UserInfo) -and [string]::IsNullOrEmpty($uri.Query) -and [string]::IsNullOrEmpty($uri.Fragment)
}

function Get-FunnelInspection {
    $tailscale = Get-Command tailscale.exe,tailscale -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $tailscale) { return [pscustomobject]@{ state='tailscale_cli_missing'; targets=@(); target_is_gateway=$false } }
    $raw = & $tailscale.Source funnel status --json 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ state='funnel_off_or_unavailable'; targets=@(); target_is_gateway=$false } }
    try { $status = $raw | ConvertFrom-Json -ErrorAction Stop } catch { return [pscustomobject]@{ state='invalid_status_json'; targets=@(); target_is_gateway=$false } }
    $targets = @(Get-FunnelProxyTargets $status)
    return [pscustomobject]@{ state='reported'; targets=$targets; target_is_gateway=(Test-FunnelProxyTargets $targets) }
}
