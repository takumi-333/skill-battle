[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'public-common.ps1')
$config = Get-PublicConfig
Set-PublicProcessEnvironment $config
$started = @()

try {
    if ($null -eq (Get-ManagedProcess 'public-lobby')) {
        Assert-PortFree 8000 'TCP'
        $python = Get-LobbyPython
        Start-ManagedProcess 'public-lobby' $python @('-m','uvicorn','app:app','--host','127.0.0.1','--port','8000','--workers','1') $script:LobbyDirectory | Out-Null
        $started += 'public-lobby'
        Wait-HttpHealth 'http://127.0.0.1:8000' 'Lobby'
    }
    if ($null -eq (Get-ManagedProcess 'public-gateway')) {
        Assert-PortFree 8080 'TCP'
        if ($null -eq $python) { $python = Get-LobbyPython }
        Start-ManagedProcess 'public-gateway' $python @('-m','uvicorn','app:app','--host','127.0.0.1','--port','8080','--workers','1') $script:GatewayDirectory | Out-Null
        $started += 'public-gateway'
        Wait-HttpHealth 'http://127.0.0.1:8080' 'Public Gateway'
    }
    if ($null -eq (Get-ManagedProcess 'public-dedicated')) {
        Assert-PortFree 7000 'UDP'
        $godot = Get-GodotConsole
        Start-ManagedProcess 'public-dedicated' $godot @('--headless','--path',$script:RepoRoot,'--scene','res://scenes/server_main.tscn') $script:RepoRoot | Out-Null
        $started += 'public-dedicated'
        Start-Sleep -Seconds 2
        if ($null -eq (Get-ManagedProcess 'public-dedicated')) { throw 'Dedicated Server exited during startup. Inspect its local log.' }
    }
    Write-Host 'Lobby, Public Gateway, and Dedicated Server are ready on loopback only. Configure Funnel and playit.gg separately.'
} catch {
    foreach ($name in $started) { Stop-ManagedProcess $name -Quiet }
    throw
}
