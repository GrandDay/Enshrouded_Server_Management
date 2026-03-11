<#
.SYNOPSIS
    Schedules automatic server restarts using Windows Task Scheduler.

.DESCRIPTION
    Creates a Windows Scheduled Task that runs 11-Restart-Server.ps1 on a
    recurring interval (default: every 12 hours). The restart script stops
    the server, applies any SteamCMD update, and starts it back up with
    full management logging.

.EXAMPLE
    .\12-Schedule-Restart.ps1
    Creates the auto-restart scheduled task using the configured interval.

.NOTES
    File Name  : 12-Schedule-Restart.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1, Administrator privileges
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

# Ensure running as administrator
if (-not (Test-AdminPrivileges)) {
    Write-ServerLog "This script requires administrator privileges." -Level ERROR
    Write-Host "`nPlease run PowerShell as Administrator and try again." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Schedule Automatic Server Restarts" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Setting up scheduled restart task..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration." -ForegroundColor Red
    exit 1
}

$TaskName = "Auto-Restart Enshrouded Server"
$RestartScript = Join-Path $PSScriptRoot "11-Restart-Server.ps1"
$intervalHours = 12

# Read interval from config if available
if ($config.Restart -and $config.Restart.IntervalHours) {
    $intervalHours = [int]$config.Restart.IntervalHours
}

# Validate interval
if ($intervalHours -lt 1 -or $intervalHours -gt 168) {
    Write-ServerLog "Restart.IntervalHours ($intervalHours) is out of range (1-168). Using default of 12." -Level WARN
    $intervalHours = 12
}

# Verify restart script exists
if (-not (Test-Path $RestartScript)) {
    Write-ServerLog "Restart script not found: $RestartScript" -Level ERROR
    Write-Host "[FAIL] Restart script not found." -ForegroundColor Red
    Write-Host "Expected location: $RestartScript" -ForegroundColor Gray
    exit 1
}

Write-Host "Task Name:        $TaskName" -ForegroundColor Gray
Write-Host "Restart Script:   $RestartScript" -ForegroundColor Gray
Write-Host "Restart Interval: Every $intervalHours hours`n" -ForegroundColor Gray

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "[INFO] Scheduled task already exists." -ForegroundColor Yellow
    Write-Host "`nRecreate task? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host

    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "[INFO] Scheduled task setup cancelled." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-ServerLog "Removed existing scheduled task." -Level INFO
}

# Create task components
Write-Host "Creating scheduled task..." -ForegroundColor Yellow

try {
    # Define task action — run PowerShell executing the restart script
    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RestartScript`"" `
        -WorkingDirectory $PSScriptRoot
    Write-Host "  [OK] Task action defined" -ForegroundColor Green

    # Define task trigger — repeating interval
    $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Hours $intervalHours) `
        -RepetitionDuration (New-TimeSpan -Days 9999)
    Write-Host "  [OK] Task trigger defined (every $intervalHours hours)" -ForegroundColor Green

    # Define task settings
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit (New-TimeSpan -Hours 0)  # No time limit
    Write-Host "  [OK] Task settings configured" -ForegroundColor Green

    # Define task principal (run as SYSTEM with highest privileges)
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Write-Host "  [OK] Task principal defined (SYSTEM account)" -ForegroundColor Green

    # Register the task
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
        -Settings $Settings -Principal $Principal -Force | Out-Null

    Write-Host "`n[OK] Scheduled task created successfully." -ForegroundColor Green
    Write-ServerLog "Scheduled task '$TaskName' created (every $intervalHours hours)." -Level SUCCESS

} catch {
    Write-ServerLog "Failed to create scheduled task: $($_.Exception.Message)" -Level ERROR
    Write-Host "`n[FAIL] Failed to create scheduled task." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify task creation
$verifyTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($verifyTask) {
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName

    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name:          $($verifyTask.TaskName)" -ForegroundColor Gray
    Write-Host "  State:         $($verifyTask.State)" -ForegroundColor Gray
    Write-Host "  Last Run Time: $($taskInfo.LastRunTime)" -ForegroundColor Gray
    Write-Host "  Next Run Time: $($taskInfo.NextRunTime)" -ForegroundColor Gray
    Write-Host "  Interval:      Every $intervalHours hours" -ForegroundColor Gray
    Write-Host "  Actions:       Run 11-Restart-Server.ps1" -ForegroundColor Gray
} else {
    Write-Host "[WARN] Could not verify task creation." -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Restart Task Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Scheduled restart task setup completed successfully." -Level SUCCESS

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  - Server will restart every $intervalHours hours" -ForegroundColor White
Write-Host "  - Each restart: stop server, update via SteamCMD, start server" -ForegroundColor White
Write-Host "  - Task runs as SYSTEM with highest privileges" -ForegroundColor White
Write-Host "  - All restart activity logged to ManagementLogs" -ForegroundColor White

Write-Host "`nTo change the interval:" -ForegroundColor Yellow
Write-Host "  1. Edit Restart.IntervalHours in EnshroudedServerConfig.json" -ForegroundColor Gray
Write-Host "  2. Re-run this script to recreate the task" -ForegroundColor Gray

Write-Host "`nManagement Commands:" -ForegroundColor Yellow
Write-Host "  Disable task:  Disable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "  Enable task:   Enable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "  Remove task:   Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor Gray
Write-Host "  Manual run:    Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray

Show-ScriptMenu -CurrentScript "12-Schedule-Restart.ps1"
