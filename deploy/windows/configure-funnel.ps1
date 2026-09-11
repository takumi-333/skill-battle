[CmdletBinding()]
param(
    [ValidateSet(443,8443,10000)]
    [int]$HttpsPort = 443
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'public-common.ps1')
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Funnel changes may require administrator rights. Open PowerShell as Administrator and run this script there.'
}
if ((Get-ManagedStatus 'public-gateway').state -ne 'running') { throw 'Public Gateway is not running on 127.0.0.1:8080.' }
try { if ((Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:8080/healthz' -TimeoutSec 2).StatusCode -ne 200) { throw 'Gateway health check failed.' } } catch { throw 'Gateway health check failed.' }
$tailscale = Get-Command tailscale.exe,tailscale -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $tailscale) { throw 'tailscale CLI was not found.' }
& $tailscale.Source funnel "--https=$HttpsPort" --bg 'http://127.0.0.1:8080'
if ($LASTEXITCODE -ne 0) { throw 'tailscale funnel configuration failed.' }
$inspection = Get-FunnelInspection
if (-not $inspection.target_is_gateway) { throw 'Funnel status does not show the required 127.0.0.1:8080 target; disable Funnel and investigate before publishing.' }
Write-Host 'Funnel is configured only for the Public Gateway. Do not expose Lobby port 8000.'
