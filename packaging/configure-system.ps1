[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GatewayPath,
    [ValidateRange(1, 65535)]
    [int]$Port = 7172,
    [string]$ConfigPath,
    [switch]$Remove,
    [switch]$StopGateway
)

$ErrorActionPreference = 'Stop'

function Stop-Pageway {
    Get-CimInstance Win32_Process -Filter "Name = 'pageway-gateway.exe'" |
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
    Remove-NetFirewallRule -Name 'Pageway-Web' -ErrorAction SilentlyContinue
    exit 0
}

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
Set-Service -Name 'TermService' -StartupType Manual
Start-Service -Name 'TermService'
Get-NetFirewallRule -Name 'RemoteDesktop-UserMode-In-TCP', 'RemoteDesktop-UserMode-In-UDP' -ErrorAction SilentlyContinue |
    Enable-NetFirewallRule

Remove-NetFirewallRule -Name 'Pageway-Web' -ErrorAction SilentlyContinue
New-NetFirewallRule -Name 'Pageway-Web' -DisplayName 'Pageway Web' -Direction Inbound -Action Allow `
    -Program $GatewayPath -Protocol TCP -Profile Any | Out-Null
