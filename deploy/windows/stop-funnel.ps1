[CmdletBinding()]
param(
    [ValidateSet(443,8443,10000)]
    [int]$HttpsPort = 443
)

$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Funnel changes may require administrator rights. Open PowerShell as Administrator and run this script there.'
}
$tailscale = Get-Command tailscale.exe,tailscale -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $tailscale) { throw 'tailscale CLI was not found.' }
& $tailscale.Source funnel "--https=$HttpsPort" off
if ($LASTEXITCODE -ne 0) { throw 'tailscale funnel stop failed.' }
Write-Host 'Funnel is OFF. Verify playit.gg UDP ingress is also OFF before stopping local services.'
