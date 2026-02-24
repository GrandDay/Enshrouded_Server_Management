<#
.SYNOPSIS
    Starts the Enshrouded dedicated server.

.DESCRIPTION
    Launches the enshrouded_server.exe process with proper working directory.
    Checks if server is already running before starting.

.EXAMPLE
    .\9-Start-Server.ps1
    Starts the Enshrouded server if not already running.

.NOTES
    File Name  : 9-Start-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Start Enshrouded Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting server..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration." -ForegroundColor Red
    exit 1
}

# Check if already running
$existing = Test-ServerProcess
if ($existing) {
    Write-Host "[INFO] Server is already running." -ForegroundColor Yellow
    Write-Host "       PID: $($existing.Id)" -ForegroundColor Gray
    Write-Host "       Started: $($existing.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    
    $uptime = (Get-Date) - $existing.StartTime
    Write-Host "       Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Gray
    
    Write-ServerLog "Server is already running (PID: $($existing.Id))." -Level INFO
    
    Write-Host "`nRun health check: .\4-Health-Check.ps1" -ForegroundColor Yellow
    exit 0
}

# Verify server executable exists
$ServerExe = Join-Path $config.Paths.ServerInstall "enshrouded_server.exe"

if (-not (Test-Path $ServerExe)) {
    Write-ServerLog "Server executable not found: $ServerExe" -Level ERROR
    Write-Host "[FAIL] Server executable not found." -ForegroundColor Red
    Write-Host "Expected location: $ServerExe" -ForegroundColor Gray
    Write-Host "`nRun 2-Download-Server.ps1 to install the server." -ForegroundColor Yellow
    exit 1
}

# Start server
Write-Host "Launching server..." -ForegroundColor Yellow
Write-Host "  Executable: $ServerExe" -ForegroundColor Gray
Write-Host "  Working Dir: $($config.Paths.ServerInstall)" -ForegroundColor Gray

try {
    Start-Process -FilePath $ServerExe -WorkingDirectory $config.Paths.ServerInstall -ErrorAction Stop
    Write-ServerLog "Server process launched." -Level INFO
    
    Write-Host "`nWaiting for server initialization..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    # Verify process started
    $proc = Test-ServerProcess
    if ($proc) {
        Write-Host "[OK] Server started successfully!" -ForegroundColor Green
        Write-Host "     PID: $($proc.Id)" -ForegroundColor Cyan
        Write-Host "     Started: $($proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
        
        Write-ServerLog "Server started successfully (PID: $($proc.Id))." -Level SUCCESS
    } else {
        Write-Host "[WARN] Server process not detected after launch." -ForegroundColor Yellow
        Write-Host "       The process may have exited immediately." -ForegroundColor Yellow
        Write-ServerLog "Server process not found after launch attempt." -Level WARN
        
        Write-Host "`nCheck server logs for startup errors:" -ForegroundColor Yellow
        $logDir = Join-Path $config.Paths.ServerInstall "logs"
        if (Test-Path $logDir) {
            $latestLog = Get-ChildItem $logDir -Filter *.log -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestLog) {
                Write-Host "  $($latestLog.FullName)" -ForegroundColor Gray
            }
        }
        exit 1
    }
    
} catch {
    Write-ServerLog "Failed to start server: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to start server process." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Server Started!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Server Information:" -ForegroundColor Cyan
Write-Host "  Name:       $($config.Server.Name)" -ForegroundColor White
Write-Host "  Game Port:  $($config.Server.GamePort) UDP" -ForegroundColor White
Write-Host "  Query Port: $($config.Server.QueryPort) UDP" -ForegroundColor White
Write-Host "  Max Players: $($config.Server.SlotCount)" -ForegroundColor White

# Get VM IP if possible
try {
    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*" -ErrorAction SilentlyContinue | 
        Where-Object {$_.IPAddress -ne '127.0.0.1'} | Select-Object -First 1).IPAddress
    
    if ($ipAddress) {
        Write-Host "`nConnect using IP: $ipAddress" -ForegroundColor Yellow
        Write-ServerLog "Server IP address: $ipAddress" -Level INFO
    }
} catch {
    # Silently continue if IP detection fails
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Wait 30-60 seconds for full initialization" -ForegroundColor Gray
Write-Host "  2. Run health check: .\4-Health-Check.ps1" -ForegroundColor Gray
Write-Host "  3. Connect from Enshrouded game client" -ForegroundColor Gray

Write-Host "`n" -NoNewline
