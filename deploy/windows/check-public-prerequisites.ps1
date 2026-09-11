[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'public-common.ps1')
$config = Get-PublicConfig
$inspection = Get-FunnelInspection
if (-not $inspection.target_is_gateway) { throw 'Funnel target is not confirmed as 127.0.0.1:8080. Refusing public-start approval.' }
if ($config['SKILL_BATTLE_PLAYIT_FORWARD_TARGET'] -ne '127.0.0.1:7000') { throw 'playit.gg forwarding target must be recorded as 127.0.0.1:7000.' }
Assert-ManagedServiceRunning (Get-ManagedStatus 'public-lobby')
Assert-ManagedServiceRunning (Get-ManagedStatus 'public-gateway')
Assert-ManagedServiceRunning (Get-ManagedStatus 'public-dedicated')
Assert-HttpHealth 'http://127.0.0.1:8000' 'Lobby' -RequireProtectedApiReady
Assert-HttpHealth 'http://127.0.0.1:8080' 'Public Gateway' -RequireProtectedApiReady
Write-Host 'Local checks passed: Lobby, Public Gateway, and Dedicated Server are running; both loopback health checks are healthy and protected_api_ready=true. In the playit.gg dashboard, independently verify that exactly one UDP tunnel forwards to 127.0.0.1:7000 before sharing the Funnel HTTPS URL and shared invite token.'
