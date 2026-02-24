<#
.SYNOPSIS
    Sets up Windows Scheduled Task for server auto-start.

.DESCRIPTION
    Creates a Windows Scheduled Task that automatically starts the Enshrouded
    server when the system boots, with a 30-second delay.

.EXAMPLE
    .\8-Setup-ScheduledTask.ps1
    Creates the auto-start scheduled task.

.NOTES
    File Name  : 8-Setup-ScheduledTask.ps1
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
Write-Host "  Setup Auto-Start Scheduled Task" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Setting up scheduled task for auto-start..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration." -ForegroundColor Red
    exit 1
}

$TaskName = "Start Enshrouded Server"
$ServerExe = Join-Path $config.Paths.ServerInstall "enshrouded_server.exe"
$WorkingDir = $config.Paths.ServerInstall

# Verify server executable exists
if (-not (Test-Path $ServerExe)) {
    Write-ServerLog "Server executable not found: $ServerExe" -Level ERROR
    Write-Host "[FAIL] Server executable not found." -ForegroundColor Red
    Write-Host "Run 2-Download-Server.ps1 first to install the server." -ForegroundColor Yellow
    exit 1
}

Write-Host "Task Name:        $TaskName" -ForegroundColor Gray
Write-Host "Server Executable: $ServerExe" -ForegroundColor Gray
Write-Host "Working Directory: $WorkingDir`n" -ForegroundColor Gray

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
    # Define task action
    $Action = New-ScheduledTaskAction -Execute $ServerExe -WorkingDirectory $WorkingDir
    Write-Host "  [OK] Task action defined" -ForegroundColor Green
    
    # Define task trigger (startup with 30-second delay)
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Trigger.Delay = "PT30S"  # ISO 8601 duration format: 30 seconds
    Write-Host "  [OK] Task trigger defined (startup + 30s delay)" -ForegroundColor Green
    
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
    Write-ServerLog "Scheduled task '$TaskName' created successfully." -Level SUCCESS
    
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
    Write-Host "  Next Run Time: At system startup" -ForegroundColor Gray
    Write-Host "  Actions:       Run enshrouded_server.exe" -ForegroundColor Gray
} else {
    Write-Host "[WARN] Could not verify task creation." -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Scheduled Task Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Scheduled task setup completed successfully." -Level SUCCESS

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  - Server will start automatically 30 seconds after system boot" -ForegroundColor White
Write-Host "  - Task runs as SYSTEM with highest privileges" -ForegroundColor White
Write-Host "  - Auto-restart enabled (up to 3 attempts)" -ForegroundColor White

Write-Host "`nManagement Commands:" -ForegroundColor Yellow
Write-Host "  Disable task:  Disable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "  Enable task:   Enable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
Write-Host "  Remove task:   Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor Gray
Write-Host "  Manual start:  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray

Write-Host "`n[INFO] Reboot the VM to test auto-start functionality." -ForegroundColor Yellow
Write-Host "`n" -NoNewline
