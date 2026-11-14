[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GatewayPath,
    [ValidateRange(1, 65535)]
    [int]$Port = 7172,
    [string]$ConfigPath,
    [switch]$Remove,
    [switch]$StopGateway,
    [switch]$ListAddresses
)

$ErrorActionPreference = 'Stop'

if ($ListAddresses) {
    $defaultRoutes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        ForEach-Object { $_.InterfaceIndex })
    Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and
            $_.InterfaceAlias -notlike 'vEthernet (WSL*' -and $_.InterfaceAlias -ne 'vEthernet (Default Switch)'
        } |
        Sort-Object @{ Expression = { $defaultRoutes -notcontains $_.InterfaceIndex } }, IPAddress |
        ForEach-Object { "http://$($_.IPAddress):$Port/" }
    exit 0
}

function Stop-Pageway {
    Get-CimInstance Win32_Process -Filter "Name = 'pageway-rdp.exe'" |
        Where-Object { $_.ExecutablePath -ieq $GatewayPath } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if ($StopGateway) {
    Stop-Pageway
    exit 0
}

if ($ConfigPath) {
    $configDirectory = Split-Path -Parent $ConfigPath
    New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    $config = @{
        listen = "0.0.0.0:$Port"
        destination = '127.0.0.1:3389'
    } | ConvertTo-Json
    [IO.File]::WriteAllText($ConfigPath, $config, [Text.UTF8Encoding]::new($false))
}

if ($Remove) {
    Remove-NetFirewallRule -Name 'PagewayRDP-Web' -ErrorAction SilentlyContinue
    exit 0
}

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
Set-Service -Name 'TermService' -StartupType Manual
Start-Service -Name 'TermService'
Get-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP', 'RemoteDesktop-UserMode-In-UDP' -ErrorAction SilentlyContinue |
    Enable-NetFirewallRule

Remove-NetFirewallRule -Name 'PagewayRDP-Web' -ErrorAction SilentlyContinue
New-NetFirewallRule -Name 'PagewayRDP-Web' -DisplayName 'Pageway RDP' -Direction Inbound -Action Allow `
    -Program $GatewayPath -Protocol TCP -Profile Any | Out-Null
