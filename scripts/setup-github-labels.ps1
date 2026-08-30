[CmdletBinding()]
param(
    [string]$Repository
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) was not found. Install it from https://cli.github.com/ and retry.'
}

if (-not $Repository) {
    $Repository = & gh repo view --json nameWithOwner --jq '.nameWithOwner'
    $Repository = $Repository.Trim()
}

if (-not $Repository) {
    throw 'Could not determine the repository. Specify -Repository owner/repository.'
}

$labelPath = Join-Path $PSScriptRoot '..\.github\labels.json'
$labels = Get-Content -Raw -Encoding utf8 -LiteralPath $labelPath | ConvertFrom-Json

foreach ($label in $labels) {
    & gh label create $label.name --repo $Repository --color $label.color --description $label.description --force
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create or update label '$($label.name)'."
    }
}

Write-Host "Applied $(($labels | Measure-Object).Count) labels to $Repository."
