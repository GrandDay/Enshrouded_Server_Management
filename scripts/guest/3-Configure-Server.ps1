<#
.SYNOPSIS
    Configures Enshrouded server settings.

.DESCRIPTION
    Reads settings from the management configuration file and applies them to
    the Enshrouded server configuration file (enshrouded_server.json).
    Creates the server config file if it doesn't exist.

.EXAMPLE
    .\3-Configure-Server.ps1
    Applies configuration from EnshroudedServerConfig.json to server.

.NOTES
    File Name  : 3-Configure-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Configure Server Settings" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting server configuration..." -Level INFO

# Load management configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration. Run 0-Initial-Setup.ps1 first." -ForegroundColor Red
    exit 1
}

# Server config file path
$serverConfigPath = Join-Path $config.Paths.ServerInstall "enshrouded_server.json"

Write-Host "Management Config: C:\EnshroudedServer\EnshroudedServerConfig.json" -ForegroundColor Gray
Write-Host "Server Config:     $serverConfigPath`n" -ForegroundColor Gray

# Load or create server config
if (Test-Path $serverConfigPath) {
    Write-Host "Loading existing server configuration..." -ForegroundColor Yellow
    try {
        $serverConfig = Get-Content $serverConfigPath -Raw | ConvertFrom-Json
        Write-ServerLog "Loaded existing server configuration." -Level INFO
    } catch {
        Write-ServerLog "Failed to parse existing server config: $($_.Exception.Message)" -Level ERROR
        Write-Host "[FAIL] Failed to parse existing server configuration." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Creating new server configuration..." -ForegroundColor Yellow
    Write-ServerLog "Creating new server configuration file." -Level INFO
    
    # Create default server config
    $serverConfig = [PSCustomObject]@{
        name = ""
        password = ""
        saveDirectory = "./savegame"
        logDirectory = "./logs"
        ip = "0.0.0.0"
        gamePort = 15636
        queryPort = 15637
        slotCount = 16
    }
}

# Apply settings from management config
Write-Host "Applying settings from management configuration..." -ForegroundColor Yellow

$serverConfig.name = $config.Server.Name
$serverConfig.password = $config.Server.Password
$serverConfig.slotCount = $config.Server.SlotCount
$serverConfig.gamePort = $config.Server.GamePort
$serverConfig.queryPort = $config.Server.QueryPort

Write-ServerLog "Applied settings: Name='$($serverConfig.name)', Slots=$($serverConfig.slotCount), Ports=$($serverConfig.gamePort)/$($serverConfig.queryPort)" -Level INFO

# Write configuration back to disk
try {
    $serverConfig | ConvertTo-Json -Depth 10 | Set-Content $serverConfigPath -Encoding UTF8
    Write-ServerLog "Server configuration saved to: $serverConfigPath" -Level SUCCESS
    Write-Host "[OK] Server configuration saved successfully." -ForegroundColor Green
} catch {
    Write-ServerLog "Failed to save server configuration: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to save server configuration." -ForegroundColor Red
    exit 1
}

# Display active configuration
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Active Server Configuration" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Server Name:     $($serverConfig.name)" -ForegroundColor White
Write-Host "Password:        $(if ($serverConfig.password) { '********' } else { '(none - public server)' })" -ForegroundColor White
Write-Host "Max Players:     $($serverConfig.slotCount)" -ForegroundColor White
Write-Host "Game Port:       $($serverConfig.gamePort) UDP" -ForegroundColor White
Write-Host "Query Port:      $($serverConfig.queryPort) UDP" -ForegroundColor White
Write-Host "Bind IP:         $($serverConfig.ip)" -ForegroundColor White
Write-Host "Save Directory:  $($serverConfig.saveDirectory)" -ForegroundColor White
Write-Host "Log Directory:   $($serverConfig.logDirectory)" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Configuration Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Server configuration completed successfully." -Level SUCCESS

Write-Host "Configuration File: $serverConfigPath" -ForegroundColor Yellow

if (Test-ServerProcess) {
    Write-Host "`n[INFO] Server is currently running." -ForegroundColor Yellow
    Write-Host "Restart the server for changes to take effect:" -ForegroundColor Yellow
    Write-Host "  .\10-Stop-Server.ps1" -ForegroundColor Gray
    Write-Host "  .\9-Start-Server.ps1" -ForegroundColor Gray
} else {
    Write-Host "`nNext Step: Run 9-Start-Server.ps1 to start the server." -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline
