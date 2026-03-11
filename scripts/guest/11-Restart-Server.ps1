<#
.SYNOPSIS
    Restarts the Enshrouded dedicated server with an update pass.

.DESCRIPTION
    Performs a full server restart cycle designed for both manual and
    unattended (scheduled task) execution:
    - Stops the running server gracefully
    - Runs SteamCMD to apply any available update
    - Starts the server with updated files
    - Verifies the server process is running

.EXAMPLE
    .\11-Restart-Server.ps1
    Restarts the server (stop, update, start).

.NOTES
    File Name  : 11-Restart-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1, SteamCMD installed
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Restart Enshrouded Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting server restart cycle..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration." -ForegroundColor Red
    exit 1
}

$ServerExe = Join-Path $config.Paths.ServerInstall "enshrouded_server.exe"
$SteamCMD = Join-Path $config.Paths.SteamCMD "steamcmd.exe"
$serverLogDir = Join-Path $config.Paths.ServerInstall "logs"
$managementLogFile = Join-Path $config.Paths.ManagementLogs "$(Get-Date -Format 'yyyy-MM-dd').log"
$steamCmdLogDir = Join-Path $config.Paths.SteamCMD "logs"
$TimeoutSeconds = 30

# Step 1: Stop server if running
Write-Host "[1/4] Stopping Server..." -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Gray

$proc = Test-ServerProcess
if ($proc) {
    Write-Host "Server is running (PID: $($proc.Id)). Stopping..." -ForegroundColor Gray
    Write-ServerLog "Stopping server process (PID: $($proc.Id))..." -Level INFO

    try {
        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        Write-Host "  Stop signal sent. Waiting for process to exit..." -ForegroundColor Gray
    } catch {
        Write-ServerLog "Error sending stop signal: $($_.Exception.Message)" -Level ERROR
        Write-Host "[WARN] Error sending stop signal." -ForegroundColor Yellow
    }

    # Wait for clean shutdown
    $waited = 0
    while ((Test-ServerProcess) -and ($waited -lt $TimeoutSeconds)) {
        Start-Sleep -Seconds 1
        $waited++
        if ($waited % 5 -eq 0) {
            Write-Host "  Still waiting... ($waited / $TimeoutSeconds seconds)" -ForegroundColor DarkGray
        }
    }

    # Force kill if still running
    if (Test-ServerProcess) {
        Write-Host "[WARN] Server did not stop within $TimeoutSeconds seconds. Force killing..." -ForegroundColor Yellow
        Write-ServerLog "Server did not stop gracefully. Force killing..." -Level WARN
        try {
            Stop-Process -Name "enshrouded_server" -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
        } catch {
            Write-ServerLog "Error force stopping server: $($_.Exception.Message)" -Level ERROR
            Write-Host "[FAIL] Could not stop server." -ForegroundColor Red
            exit 1
        }
    }

    if (-not (Test-ServerProcess)) {
        Write-Host "[OK] Server stopped successfully." -ForegroundColor Green
        Write-ServerLog "Server stopped successfully." -Level SUCCESS
    } else {
        Write-Host "[FAIL] Server could not be stopped." -ForegroundColor Red
        Write-ServerLog "Failed to stop server process." -Level ERROR
        exit 1
    }
} else {
    Write-Host "Server is not running." -ForegroundColor Gray
    Write-ServerLog "Server was not running (no stop needed)." -Level INFO
}

# Step 2: Run SteamCMD update
Write-Host "`n[2/4] Updating Server Files..." -ForegroundColor Yellow
Write-Host "-------------------------------" -ForegroundColor Gray
Write-Host "Running SteamCMD (this may take several minutes)...`n" -ForegroundColor Gray
Write-ServerLog "Running SteamCMD update for App ID 2278520..." -Level INFO

$arguments = @(
    "+force_install_dir `"$($config.Paths.ServerInstall)`"",
    "+login anonymous",
    "+app_update 2278520",
    "+quit"
)

try {
    $updateProcess = Start-Process -FilePath $SteamCMD -ArgumentList $arguments -Wait -NoNewWindow -PassThru

    if ($updateProcess.ExitCode -eq 0 -or $updateProcess.ExitCode -eq 7) {
        Write-Host "`n[OK] Server files updated successfully." -ForegroundColor Green
        Write-ServerLog "SteamCMD update completed (exit code: $($updateProcess.ExitCode))." -Level SUCCESS
    } else {
        Write-Host "`n[WARN] SteamCMD exited with code $($updateProcess.ExitCode)." -ForegroundColor Yellow
        Write-ServerLog "SteamCMD update completed with exit code: $($updateProcess.ExitCode)." -Level WARN
    }
} catch {
    Write-ServerLog "SteamCMD update failed: $($_.Exception.Message)" -Level ERROR
    Write-Host "`n[FAIL] Failed to run SteamCMD update." -ForegroundColor Red
    Write-Host "Attempting to start server with existing files..." -ForegroundColor Yellow
}

# Step 3: Start server
Write-Host "`n[3/4] Starting Server..." -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Gray

if (-not (Test-Path $ServerExe)) {
    Write-ServerLog "Server executable not found: $ServerExe" -Level ERROR
    Write-Host "[FAIL] Server executable not found." -ForegroundColor Red
    exit 1
}

Write-Host "Launching enshrouded_server.exe..." -ForegroundColor Gray
Write-ServerLog "Starting server process..." -Level INFO

try {
    $startedProcess = Start-Process -FilePath $ServerExe -WorkingDirectory $config.Paths.ServerInstall -PassThru -ErrorAction Stop
    Write-Host "Server process launched. Waiting for initialization..." -ForegroundColor Gray
    Start-Sleep -Seconds 10

    if ($startedProcess.HasExited) {
        Write-ServerLog "Server process exited immediately with code: $($startedProcess.ExitCode)" -Level ERROR
        Write-Host "[FAIL] Server exited immediately after launch." -ForegroundColor Red
        Write-Host "       Exit code: $($startedProcess.ExitCode)" -ForegroundColor Red

        Write-Host "`nLog locations:" -ForegroundColor Yellow
        Write-Host "  Management log: $managementLogFile" -ForegroundColor Gray
        Write-Host "  Server logs dir: $serverLogDir" -ForegroundColor Gray
        Write-Host "  SteamCMD logs dir: $steamCmdLogDir" -ForegroundColor Gray

        if (Test-Path $serverLogDir) {
            $latestServerLog = Get-ChildItem $serverLogDir -Filter *.log -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestServerLog) {
                Write-Host "`nLast 20 lines from: $($latestServerLog.FullName)" -ForegroundColor Yellow
                Get-Content $latestServerLog.FullName -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Host "  $_" -ForegroundColor Gray
                }
            }
        }

        exit 1
    }
} catch {
    Write-ServerLog "Failed to start server: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to start server process." -ForegroundColor Red
    Write-Host "`nLog locations:" -ForegroundColor Yellow
    Write-Host "  Management log: $managementLogFile" -ForegroundColor Gray
    Write-Host "  Server logs dir: $serverLogDir" -ForegroundColor Gray
    Write-Host "  SteamCMD logs dir: $steamCmdLogDir" -ForegroundColor Gray
    exit 1
}

# Step 4: Verify server is running
Write-Host "`n[4/4] Verifying Server Status..." -ForegroundColor Yellow
Write-Host "---------------------------------" -ForegroundColor Gray

$verify = Test-ServerProcess
if ($verify) {
    Write-Host "[OK] Server is running (PID: $($verify.Id))." -ForegroundColor Green
    Write-ServerLog "Server restarted successfully (PID: $($verify.Id))." -Level SUCCESS
} else {
    Write-Host "[FAIL] Server process not detected." -ForegroundColor Red
    Write-ServerLog "Server failed to start after restart." -Level ERROR
    Write-Host "`nCheck logs for errors:" -ForegroundColor Yellow
    Write-Host "  Management log: $managementLogFile" -ForegroundColor Gray
    Write-Host "  Server logs dir: $serverLogDir" -ForegroundColor Gray
    Write-Host "  SteamCMD logs dir: $steamCmdLogDir" -ForegroundColor Gray
    exit 1
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Server Restart Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Server restart cycle completed successfully." -Level SUCCESS

Write-Host "Server Status: Running (PID: $($verify.Id))" -ForegroundColor Cyan

Show-ScriptMenu -CurrentScript "11-Restart-Server.ps1"
