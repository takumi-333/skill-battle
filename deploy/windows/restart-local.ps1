[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'stop-local.ps1') -Quiet
Start-Sleep -Seconds 1
& (Join-Path $PSScriptRoot 'start-local.ps1') -NoBrowser
