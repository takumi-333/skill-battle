[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'public-common.ps1')
[pscustomobject]@{
    platform = 'Windows public launcher'
    lobby = Get-ManagedStatus 'public-lobby'
    gateway = Get-ManagedStatus 'public-gateway'
    dedicated = Get-ManagedStatus 'public-dedicated'
    funnel = Get-FunnelInspection
    note = 'Funnel and playit.gg ingress are outside this launcher. A reported Funnel target must be 127.0.0.1:8080; verify playit.gg forwards UDP to 127.0.0.1:7000.'
} | ConvertTo-Json -Compress
