[CmdletBinding()]
param([switch]$IngressAlreadyDisabled)

. (Join-Path $PSScriptRoot 'public-common.ps1')
if (-not $IngressAlreadyDisabled) {
    throw 'First disable HTTP ingress (Funnel) and UDP ingress (playit.gg tunnel), then rerun with -IngressAlreadyDisabled. This script manages only the three local processes.'
}
Stop-ManagedProcess 'public-gateway'
Stop-ManagedProcess 'public-dedicated'
Stop-ManagedProcess 'public-lobby'
Write-Host 'Local public processes are stopped. Funnel and playit.gg are intentionally not controlled by this script; verify both ingress paths remain OFF.'
