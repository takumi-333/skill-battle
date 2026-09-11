$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\deploy\windows\public-common.ps1')

$expectedStartTime = [DateTime]::Parse('2026-09-11T00:50:29.5092075Z', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
$serializedRecord = @{ started_at = $expectedStartTime.ToUniversalTime().ToString('o') } | ConvertTo-Json -Compress
$jsonRecordedStartTime = ($serializedRecord | ConvertFrom-Json).started_at
$recordedStartTimes = @(
    $expectedStartTime.ToUniversalTime().ToString('o'),
    $expectedStartTime,
    [DateTimeOffset]$expectedStartTime,
    $jsonRecordedStartTime
)
foreach ($recordedStartTime in $recordedStartTimes) {
    if (-not (Test-ProcessStartTimeMatch $expectedStartTime $recordedStartTime)) {
        throw "A matching process start time was rejected for record type $($recordedStartTime.GetType().FullName)."
    }
}
if (Test-ProcessStartTimeMatch $expectedStartTime $expectedStartTime.AddTicks(1)) {
    throw 'A mismatched process start time must be rejected.'
}

$singleTargetStatus = [pscustomobject]@{
    Web = [pscustomobject]@{
        'example.ts.net:443' = [pscustomobject]@{
            Handlers = [pscustomobject]@{ '/' = [pscustomobject]@{ Proxy = 'http://127.0.0.1:8080' } }
        }
    }
}
$singleTarget = @(Get-FunnelProxyTargets $singleTargetStatus)
if (-not (Test-FunnelProxyTargets $singleTarget)) { throw 'The sole loopback Gateway proxy must be accepted.' }

$multipleTargets = @('http://127.0.0.1:8080', 'http://127.0.0.1:8000')
if (Test-FunnelProxyTargets $multipleTargets) { throw 'A Funnel configuration with an additional proxy must be rejected.' }
if (Test-FunnelProxyTargets @('http://127.0.0.1:8000')) { throw 'A Lobby proxy must be rejected.' }
if (Test-FunnelProxyTargets @('http://127.0.0.1:8080/admin')) { throw 'A path-scoped proxy must be rejected.' }

function Assert-Throws([scriptblock]$Action, [string]$FailureMessage) {
    try { & $Action } catch { return }
    throw $FailureMessage
}

Assert-ManagedServiceRunning ([pscustomobject]@{ name='public-lobby'; state='running'; pid=101 })
Assert-Throws { Assert-ManagedServiceRunning ([pscustomobject]@{ name='public-lobby'; state='stopped'; pid=$null }) } 'A stopped Lobby must be rejected.'
Assert-Throws { Assert-ManagedServiceRunning ([pscustomobject]@{ name='public-gateway'; state='pid_reused_or_state_error'; pid=$null }) } 'An invalid Gateway PID record must be rejected.'
Assert-Throws { Assert-ManagedServiceRunning ([pscustomobject]@{ name='public-dedicated'; state='stopped'; pid=$null }) } 'A stopped Dedicated Server must be rejected.'

$readyHealth = [pscustomobject]@{ StatusCode=200; Content='{"ok":true,"protected_api_ready":true}' }
Assert-HttpHealthResponse $readyHealth 'Public Gateway' -RequireProtectedApiReady
Assert-Throws { Assert-HttpHealthResponse ([pscustomobject]@{ StatusCode=503; Content='{}' }) 'Lobby' } 'A non-200 Lobby health response must be rejected.'
Assert-Throws { Assert-HttpHealthResponse ([pscustomobject]@{ StatusCode=200; Content='not-json' }) 'Public Gateway' -RequireProtectedApiReady } 'An invalid Gateway health body must be rejected.'
Assert-Throws { Assert-HttpHealthResponse ([pscustomobject]@{ StatusCode=200; Content='{"ok":true,"protected_api_ready":false}' }) 'Public Gateway' -RequireProtectedApiReady } 'Gateway health without protected API readiness must be rejected.'

$temporaryStateDirectory = Join-Path ([IO.Path]::GetTempPath()) ("skill-battle-public-config-test-" + [Guid]::NewGuid().ToString('N'))
$originalStateDirectory = $script:StateDirectory
$originalConfigPath = $script:PublicConfigPath
$originalLobbyDatabasePath = $script:PublicLobbyDatabasePath
try {
    New-Item -ItemType Directory -Path $temporaryStateDirectory | Out-Null
    $script:StateDirectory = $temporaryStateDirectory
    $script:PublicConfigPath = Join-Path $temporaryStateDirectory 'public.env'
    $script:PublicLobbyDatabasePath = Join-Path $temporaryStateDirectory 'public-lobby.db'
    @(
        "SKILL_BATTLE_TOKEN_SECRET=$('a' * 32)"
        "SKILL_BATTLE_ADMIN_TOKEN=$('b' * 32)"
        "SKILL_BATTLE_INTERNAL_API_TOKEN=$('c' * 32)"
        "SKILL_BATTLE_PUBLIC_ACCESS_TOKEN=$('d' * 32)"
        'SKILL_BATTLE_LOBBY_INTERNAL_URL=http://127.0.0.1:8000'
        'SKILL_BATTLE_SERVER_LISTEN_PORT=7000'
        'SKILL_BATTLE_SERVER_ADDRESS=public.example.test'
        'SKILL_BATTLE_SERVER_PORT=7000'
        'SKILL_BATTLE_PLAYIT_FORWARD_TARGET=127.0.0.1:7000'
        'SKILL_BATTLE_UVICORN_WORKERS=1'
        'SKILL_BATTLE_PUBLIC_MODE=1'
        'SKILL_BATTLE_REQUIRE_LOBBY_CONSUME=1'
    ) | Set-Content -LiteralPath $script:PublicConfigPath -Encoding utf8
    $migratedConfig = Get-PublicConfig
    if ($migratedConfig['SKILL_BATTLE_LOBBY_DB'] -ne [IO.Path]::GetFullPath($script:PublicLobbyDatabasePath)) { throw 'Existing public.env must migrate its DB path into .local-server.' }
    if ((Get-Content -Raw -LiteralPath $script:PublicConfigPath) -notmatch 'SKILL_BATTLE_LOBBY_DB=') { throw 'Migrated public.env must persist the public DB path.' }
} finally {
    $script:StateDirectory = $originalStateDirectory
    $script:PublicConfigPath = $originalConfigPath
    $script:PublicLobbyDatabasePath = $originalLobbyDatabasePath
    if (Test-Path -LiteralPath $temporaryStateDirectory) { Remove-Item -LiteralPath $temporaryStateDirectory -Recurse -Force }
}

Write-Host 'public-common Funnel target tests passed'
