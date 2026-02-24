<#
.SYNOPSIS
    Stops the Enshrouded dedicated server.

.DESCRIPTION
    Gracefully stops the enshrouded_server process with configurable timeout.
    Attempts clean shutdown before forcing termination if necessary.

.PARAMETER TimeoutSeconds
    Maximum seconds to wait for graceful shutdown before forcing. Default: 30

.EXAMPLE
    .\10-Stop-Server.ps1
    Stops server with default 30-second timeout.

.EXAMPLE
    .\10-Stop-Server.ps1 -TimeoutSeconds 60
    Stops server with 60-second timeout.

.NOTES
    File Name  : 10-Stop-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$TimeoutSeconds = 30
)

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Stop Enshrouded Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Stopping server..." -Level INFO

# Check for running process
$proc = Test-ServerProcess

if (-not $proc) {
    Write-Host "[INFO] Server is not running." -ForegroundColor Yellow
    Write-ServerLog "Server is not running (no action needed)." -Level INFO
    exit 0
}

# Display current server info
Write-Host "Found running server:" -ForegroundColor Yellow
Write-Host "  PID:     $($proc.Id)" -ForegroundColor Gray
Write-Host "  Started: $($proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

$uptime = (Get-Date) - $proc.StartTime
Write-Host "  Uptime:  $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Gray

$memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
Write-Host "  Memory:  $memoryMB MB" -ForegroundColor Gray

Write-Host "`nStopping server (timeout: $TimeoutSeconds seconds)..." -ForegroundColor Yellow
Write-ServerLog "Stopping server process (PID: $($proc.Id), timeout: $TimeoutSeconds s)..." -Level INFO

# Attempt graceful shutdown
try {
    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
    Write-Host "  Stop signal sent. Waiting for process to exit..." -ForegroundColor Gray
} catch {
    Write-ServerLog "Error sending stop signal: $($_.Exception.Message)" -Level ERROR
    Write-Host "[WARN] Error sending stop signal." -ForegroundColor Yellow
}

# Wait for clean shutdown
$waited = 0
$checkInterval = 1  # Check every second

while ((Test-ServerProcess) -and ($waited -lt $TimeoutSeconds)) {
    Start-Sleep -Seconds $checkInterval
    $waited += $checkInterval
    
    # Show progress every 5 seconds
    if ($waited % 5 -eq 0) {
        Write-Host "  Still waiting... ($waited / $TimeoutSeconds seconds)" -ForegroundColor DarkGray
    }
}

# Verify stopped
$stillRunning = Test-ServerProcess

if ($stillRunning) {
    Write-Host "`n[WARN] Server did not stop within $TimeoutSeconds seconds." -ForegroundColor Yellow
    Write-Host "       Forcing termination..." -ForegroundColor Yellow
    Write-ServerLog "Server did not stop gracefully within timeout. Force killing..." -Level WARN
    
    try {
        Stop-Process -Name "enshrouded_server" -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        
        if (Test-ServerProcess) {
            Write-Host "[FAIL] Could not force stop server." -ForegroundColor Red
            Write-ServerLog "Failed to force stop server process." -Level ERROR
            exit 1
        } else {
            Write-Host "[OK] Server force-stopped." -ForegroundColor Green
            Write-ServerLog "Server force-stopped successfully." -Level WARN
        }
    } catch {
        Write-ServerLog "Error force stopping server: $($_.Exception.Message)" -Level ERROR
        Write-Host "[FAIL] Error force stopping server." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n[OK] Server stopped successfully." -ForegroundColor Green
    Write-Host "     Graceful shutdown completed in $waited seconds." -ForegroundColor Green
    Write-ServerLog "Server stopped gracefully after $waited seconds." -Level SUCCESS
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Server Stopped!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Server stop operation completed successfully." -Level SUCCESS

Write-Host "Server Status: Not Running" -ForegroundColor Cyan
Write-Host "`nTo start server: .\9-Start-Server.ps1" -ForegroundColor Yellow
Write-Host "`n" -NoNewline
