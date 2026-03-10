<#
.SYNOPSIS
    Updates and restarts the Enshrouded dedicated server.

.DESCRIPTION
    Performs complete server update cycle:
    - Stops running server gracefully
    - Runs SteamCMD to download latest version
    - Starts server with updated files
    - Performs health check

.EXAMPLE
    .\5-Update-Server.ps1
    Updates server to latest version and restarts.

.NOTES
    File Name  : 5-Update-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1, SteamCMD installed
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Update & Restart Enshrouded Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting server update process..." -Level INFO

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

# Step 1: Stop server if running
Write-Host "[1/4] Stopping Server..." -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Gray

$proc = Test-ServerProcess
if ($proc) {
    Write-Host "Server is running (PID: $($proc.Id)). Stopping..." -ForegroundColor Gray
    Write-ServerLog "Stopping server process (PID: $($proc.Id))..." -Level INFO
    
    try {
        Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        Start-Sleep -Seconds 5
        
        # Verify stopped
        if (Test-ServerProcess) {
            Write-Host "[WARN] Server still running after stop attempt. Force killing..." -ForegroundColor Yellow
            Stop-Process -Name "enshrouded_server" -Force
            Start-Sleep -Seconds 3
        }
        
        Write-Host "[OK] Server stopped successfully." -ForegroundColor Green
        Write-ServerLog "Server stopped successfully." -Level SUCCESS
    } catch {
        Write-ServerLog "Error stopping server: $($_.Exception.Message)" -Level ERROR
        Write-Host "[WARN] Error stopping server, continuing..." -ForegroundColor Yellow
    }
} else {
    Write-Host "Server is not running." -ForegroundColor Gray
    Write-ServerLog "Server was not running (no action needed)." -Level INFO
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
    $process = Start-Process -FilePath $SteamCMD -ArgumentList $arguments -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 7) {
        Write-Host "`n[OK] Server files updated successfully." -ForegroundColor Green
        Write-ServerLog "SteamCMD update completed (exit code: $($process.ExitCode))." -Level SUCCESS
    } else {
        Write-Host "`n[WARN] SteamCMD exited with code $($process.ExitCode)." -ForegroundColor Yellow
        Write-ServerLog "SteamCMD update completed with exit code: $($process.ExitCode)." -Level WARN
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

# Step 4: Quick verification
Write-Host "`n[4/4] Verifying Server Status..." -ForegroundColor Yellow
Write-Host "---------------------------------" -ForegroundColor Gray

$verify = Test-ServerProcess
if ($verify) {
    Write-Host "[OK] Server is running (PID: $($verify.Id))." -ForegroundColor Green
    Write-ServerLog "Server started successfully (PID: $($verify.Id))." -Level SUCCESS
} else {
    Write-Host "[FAIL] Server process not detected." -ForegroundColor Red
    Write-ServerLog "Server failed to start." -Level ERROR
    Write-Host "`nCheck logs for errors:" -ForegroundColor Yellow
    Write-Host "  Management log: $managementLogFile" -ForegroundColor Gray
    Write-Host "  Server logs dir: $serverLogDir" -ForegroundColor Gray
    Write-Host "  SteamCMD logs dir: $steamCmdLogDir" -ForegroundColor Gray
    Write-Host "  Run detailed diagnostics: .\4-Health-Check.ps1" -ForegroundColor Gray
    exit 1
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Update & Restart Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Server update and restart completed successfully." -Level SUCCESS

Write-Host "Server Status: Running (PID: $($verify.Id))" -ForegroundColor Cyan

Show-ScriptMenu -CurrentScript "5-Update-Server.ps1"
