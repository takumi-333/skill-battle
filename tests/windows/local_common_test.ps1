$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\deploy\windows\local-common.ps1')

function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
    if ($Actual -ne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

$temporaryStateDirectory = Join-Path ([IO.Path]::GetTempPath()) ("skill-battle-local-config-test-" + [Guid]::NewGuid().ToString('N'))
$originalStateDirectory = $script:StateDirectory
$originalConfigPath = $script:LocalConfigPath
$originalClientConfigPath = $script:LocalClientConfigPath
$originalLobbyDatabasePath = $script:LocalLobbyDatabasePath
try {
    New-Item -ItemType Directory -Path $temporaryStateDirectory | Out-Null
    $script:StateDirectory = $temporaryStateDirectory
    $script:LocalConfigPath = Join-Path $temporaryStateDirectory 'local.env'
    $script:LocalClientConfigPath = Join-Path $temporaryStateDirectory 'local-client.env'
    $script:LocalLobbyDatabasePath = Join-Path $temporaryStateDirectory 'local-lobby.db'

    $publicConfigPath = Join-Path $temporaryStateDirectory 'public.env'
    Set-Content -LiteralPath $publicConfigPath -Value "SKILL_BATTLE_SERVER_ADDRESS=public.example.test`nSKILL_BATTLE_SERVER_PORT=7000" -Encoding utf8
    $publicConfigBefore = Get-Content -Raw -LiteralPath $publicConfigPath
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
    ) | Set-Content -LiteralPath $script:LocalConfigPath -Encoding utf8

    $config = Get-LocalConfig
    Assert-Equal $config['SKILL_BATTLE_SERVER_ADDRESS'] '127.0.0.1' 'Local server address must be loopback.'
    Assert-Equal $config['SKILL_BATTLE_SERVER_PORT'] '17000' 'Local ticket port must be fixed.'
    Assert-Equal $config['SKILL_BATTLE_SERVER_LISTEN_PORT'] '17000' 'Local Dedicated Server listen port must be fixed.'
    Assert-Equal $config['SKILL_BATTLE_PUBLIC_MODE'] '0' 'Local launcher must disable public mode.'
    Assert-Equal $config['SKILL_BATTLE_LOBBY_DB'] ([IO.Path]::GetFullPath($script:LocalLobbyDatabasePath)) 'Local Lobby DB must be isolated.'
    if ($config['SKILL_BATTLE_TOKEN_SECRET'] -eq ('a' * 32)) { throw 'Migrated local settings must not reuse the legacy secret.' }
    if (-not (Test-LocalSecretsAreValid $config)) { throw 'Local settings must contain distinct valid secrets.' }
    if ((Get-Content -Raw -LiteralPath $script:LocalConfigPath) -match 'public\.example\.test|PLAYIT') { throw 'Migrated local.env must not retain public transport settings.' }
    Assert-Equal (Get-Content -Raw -LiteralPath $publicConfigPath) $publicConfigBefore 'Local migration must not change public.env.'

    $secondConfig = Get-LocalConfig
    foreach ($name in $script:LocalSecretNames) {
        Assert-Equal $secondConfig[$name] $config[$name] 'Valid local secrets must survive later local starts.'
    }
    Write-LocalClientConfig $secondConfig
    $clientConfig = Get-Content -Raw -LiteralPath $script:LocalClientConfigPath
    if ($clientConfig -notmatch 'LOBBY_URL=http://127\.0\.0\.1:8000') { throw 'Local client config must point at the local Lobby.' }
    if ($clientConfig -notmatch [regex]::Escape($secondConfig['SKILL_BATTLE_PUBLIC_ACCESS_TOKEN'])) { throw 'Local client config must receive the local invite token.' }
} finally {
    $script:StateDirectory = $originalStateDirectory
    $script:LocalConfigPath = $originalConfigPath
    $script:LocalClientConfigPath = $originalClientConfigPath
    $script:LocalLobbyDatabasePath = $originalLobbyDatabasePath
    if (Test-Path -LiteralPath $temporaryStateDirectory) { Remove-Item -LiteralPath $temporaryStateDirectory -Recurse -Force }
}

Write-Host 'local-common environment separation tests passed'
