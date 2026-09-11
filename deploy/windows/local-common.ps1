$ErrorActionPreference = 'Stop'

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:StateDirectory = Join-Path $script:RepoRoot '.local-server'
$script:LocalConfigPath = Join-Path $script:StateDirectory 'local.env'
$script:LocalClientConfigPath = Join-Path $script:StateDirectory 'local-client.env'
$script:LocalLobbyDatabasePath = Join-Path $script:StateDirectory 'local-lobby.db'
$script:LocalLobbyUrl = 'http://127.0.0.1:8000'
$script:LocalDedicatedPort = 17000
$script:LocalSecretNames = @(
    'SKILL_BATTLE_TOKEN_SECRET',
    'SKILL_BATTLE_ADMIN_TOKEN',
    'SKILL_BATTLE_INTERNAL_API_TOKEN',
    'SKILL_BATTLE_PUBLIC_ACCESS_TOKEN'
)

function New-LocalSecret {
    $bytes = New-Object byte[] 48
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [BitConverter]::ToString($bytes).Replace('-', '').ToLowerInvariant()
}

function Set-CurrentUserOnlyLocalAcl([string]$Path, [switch]$Directory) {
    $account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($Directory) {
        & icacls $Path /inheritance:r /grant:r "${account}:(OI)(CI)(F)" | Out-Null
    } else {
        & icacls $Path /inheritance:r /grant:r "${account}:(R,W)" | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { throw "Could not restrict ACL for $Path" }
}

function Get-LocalEnvironmentDefaults {
    return [ordered]@{
        SKILL_BATTLE_LOBBY_DB = [IO.Path]::GetFullPath($script:LocalLobbyDatabasePath)
        SKILL_BATTLE_LOBBY_INTERNAL_URL = $script:LocalLobbyUrl
        SKILL_BATTLE_REQUIRE_LOBBY_CONSUME = '1'
        SKILL_BATTLE_UVICORN_WORKERS = '1'
        SKILL_BATTLE_PUBLIC_MODE = '0'
        SKILL_BATTLE_SERVER_LISTEN_PORT = [string]$script:LocalDedicatedPort
        SKILL_BATTLE_SERVER_ADDRESS = '127.0.0.1'
        SKILL_BATTLE_SERVER_PORT = [string]$script:LocalDedicatedPort
    }
}

function Read-LocalEnvironmentFile {
    $config = @{}
    if (-not (Test-Path -LiteralPath $script:LocalConfigPath)) { return $config }
    foreach ($line in Get-Content -LiteralPath $script:LocalConfigPath) {
        $line = $line.TrimStart([char]0xFEFF)
        if ($line -match '^([A-Z0-9_]+)=(.*)$') { $config[$matches[1]] = $matches[2] }
    }
    return $config
}

function Test-LocalSecretsAreValid([hashtable]$Config) {
    $secrets = @()
    foreach ($name in $script:LocalSecretNames) {
        if (-not $Config.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($Config[$name]) -or $Config[$name].Length -lt 32) {
            return $false
        }
        $secrets += $Config[$name]
    }
    return ($secrets | Select-Object -Unique).Count -eq $secrets.Count
}

function Test-LocalConfigContainsPublicSettings([hashtable]$Config) {
    if ($Config['SKILL_BATTLE_PUBLIC_MODE'] -eq '1') { return $true }
    if (-not [string]::IsNullOrWhiteSpace($Config['SKILL_BATTLE_PLAYIT_FORWARD_TARGET'])) { return $true }

    $address = [string]$Config['SKILL_BATTLE_SERVER_ADDRESS']
    if (-not [string]::IsNullOrWhiteSpace($address) -and $address -notin @('127.0.0.1', 'localhost')) { return $true }

    foreach ($name in 'SKILL_BATTLE_SERVER_PORT', 'SKILL_BATTLE_SERVER_LISTEN_PORT') {
        $port = [string]$Config[$name]
        if (-not [string]::IsNullOrWhiteSpace($port) -and $port -ne [string]$script:LocalDedicatedPort) { return $true }
    }
    return $false
}

function New-LocalConfig {
    $config = @{}
    foreach ($name in $script:LocalSecretNames) { $config[$name] = New-LocalSecret }
    foreach ($entry in (Get-LocalEnvironmentDefaults).GetEnumerator()) { $config[$entry.Key] = $entry.Value }
    return $config
}

function Normalize-LocalConfig([hashtable]$ExistingConfig) {
    if (-not (Test-LocalSecretsAreValid $ExistingConfig)) { return New-LocalConfig }
    $config = @{}
    foreach ($name in $script:LocalSecretNames) { $config[$name] = $ExistingConfig[$name] }
    foreach ($entry in (Get-LocalEnvironmentDefaults).GetEnumerator()) { $config[$entry.Key] = $entry.Value }
    return $config
}

function Test-ConfigEquivalent([hashtable]$Left, [hashtable]$Right) {
    if ($Left.Count -ne $Right.Count) { return $false }
    foreach ($entry in $Right.GetEnumerator()) {
        if (-not $Left.ContainsKey($entry.Key) -or [string]$Left[$entry.Key] -ne [string]$entry.Value) { return $false }
    }
    return $true
}

function Write-LocalConfig([hashtable]$Config) {
    New-Item -ItemType Directory -Force -Path $script:StateDirectory | Out-Null
    Set-CurrentUserOnlyLocalAcl $script:StateDirectory -Directory
    @($Config.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) | Set-Content -LiteralPath $script:LocalConfigPath -Encoding utf8
    Set-CurrentUserOnlyLocalAcl $script:LocalConfigPath
}

function Get-LocalConfig {
    $existingConfig = Read-LocalEnvironmentFile
    $migratingPublicSettings = Test-LocalConfigContainsPublicSettings $existingConfig
    $config = if ($migratingPublicSettings) { New-LocalConfig } else { Normalize-LocalConfig $existingConfig }
    if (-not (Test-ConfigEquivalent $existingConfig $config)) {
        Write-LocalConfig $config
        if ($migratingPublicSettings) {
            Write-Host "Migrated $script:LocalConfigPath to isolated local-only settings."
        } elseif ($existingConfig.Count -eq 0) {
            Write-Host "Created local-only settings: $script:LocalConfigPath"
        } else {
            Write-Host "Normalized local-only settings: $script:LocalConfigPath"
        }
    }
    return $config
}

function Write-LocalClientConfig([hashtable]$Config) {
    New-Item -ItemType Directory -Force -Path $script:StateDirectory | Out-Null
    @(
        "LOBBY_URL=$script:LocalLobbyUrl"
        "INVITE_TOKEN=$($Config['SKILL_BATTLE_PUBLIC_ACCESS_TOKEN'])"
    ) | Set-Content -LiteralPath $script:LocalClientConfigPath -Encoding utf8
    Set-CurrentUserOnlyLocalAcl $script:LocalClientConfigPath
}
