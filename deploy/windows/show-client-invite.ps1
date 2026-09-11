[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$LobbyUrl
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'public-common.ps1')

$normalizedUrl = $LobbyUrl.Trim().TrimEnd('/')
try {
    $uri = [Uri]$normalizedUrl
} catch {
    throw 'LobbyUrl must be the public Funnel HTTPS URL, for example https://your-node.example.ts.net.'
}
if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https' -or [string]::IsNullOrWhiteSpace($uri.Host) -or -not [string]::IsNullOrWhiteSpace($uri.UserInfo) -or -not [string]::IsNullOrWhiteSpace($uri.Query) -or -not [string]::IsNullOrWhiteSpace($uri.Fragment)) {
    throw 'LobbyUrl must be a plain public HTTPS URL without credentials, query parameters, or fragments.'
}

$config = Get-PublicConfig
Write-Host 'Send exactly these two values to each invited player, preferably by a channel separate from the ZIP download.'
Write-Output "Lobby HTTPS URL: $normalizedUrl"
Write-Output "Shared invite token: $($config['SKILL_BATTLE_PUBLIC_ACCESS_TOKEN'])"
Write-Host 'Do not share public.env or any admin/internal/token-signing value.'
