<#
.SYNOPSIS
    Performs health check on Enshrouded dedicated server.

.DESCRIPTION
    Validates server health by checking:
    - Server process status
    - UDP port listeners
    - Process resource usage
    - Recent log entries
    Returns comprehensive diagnostic output.

.EXAMPLE
    .\4-Health-Check.ps1
    Runs complete health check with all tests.

.NOTES
    File Name  : 4-Health-Check.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-ServerLog "Starting health check..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[WARN] Could not load configuration. Using defaults." -ForegroundColor Yellow
    $config = @{
        Server = @{
            GamePort = 15636
            QueryPort = 15637
        }
        Paths = @{
            ServerInstall = "C:\EnshroudedServer"
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Enshrouded Server Health Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan

$allChecks = @()

# Check 1: Process Status
Write-Host "[1/3] Process Status" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Gray

$proc = Test-ServerProcess
if ($proc) {
    $uptime = (Get-Date) - $proc.StartTime
    $cpuTime = $proc.TotalProcessorTime
    $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
    $handleCount = $proc.HandleCount
    $threadCount = $proc.Threads.Count
    
    Write-Host "[OK] Server process is running" -ForegroundColor Green
    Write-Host "     PID:          $($proc.Id)" -ForegroundColor Gray
    Write-Host "     Started:      $($proc.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "     Uptime:       $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s" -ForegroundColor Gray
    Write-Host "     CPU Time:     $cpuTime" -ForegroundColor Gray
    Write-Host "     Memory:       $memoryMB MB" -ForegroundColor Gray
    Write-Host "     Threads:      $threadCount" -ForegroundColor Gray
    Write-Host "     Handles:      $handleCount" -ForegroundColor Gray
    
    Write-ServerLog "Process check PASSED - PID: $($proc.Id), Memory: $memoryMB MB, Uptime: $($uptime.TotalMinutes) mins" -Level SUCCESS
    $allChecks += @{Name="Process Status"; Status="PASS"}
} else {
    Write-Host "[FAIL] Server process NOT found" -ForegroundColor Red
    Write-Host "       The enshrouded_server process is not running." -ForegroundColor Red
    Write-Host "       Run: .\9-Start-Server.ps1" -ForegroundColor Yellow
    
    Write-ServerLog "Process check FAILED - enshrouded_server process not found." -Level ERROR
    $allChecks += @{Name="Process Status"; Status="FAIL"}
}

# Check 2: Port Status
Write-Host "`n[2/3] UDP Port Status" -ForegroundColor Yellow
Write-Host "---------------------" -ForegroundColor Gray

$ports = @($config.Server.GamePort, $config.Server.QueryPort)
$portNames = @("Game", "Query")
$portCheckPassed = $true

for ($i = 0; $i -lt $ports.Count; $i++) {
    $port = $ports[$i]
    $portName = $portNames[$i]
    
    $ep = Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue
    if ($ep) {
        Write-Host "[OK] UDP port $port ($portName) is listening" -ForegroundColor Green
        Write-Host "     Local Address: $($ep.LocalAddress):$($ep.LocalPort)" -ForegroundColor Gray
        Write-ServerLog "Port check PASSED - UDP $port ($portName) is listening." -Level SUCCESS
    } else {
        Write-Host "[FAIL] UDP port $port ($portName) NOT listening" -ForegroundColor Red
        Write-ServerLog "Port check FAILED - UDP $port ($portName) not listening." -Level ERROR
        $portCheckPassed = $false
    }
}

if ($portCheckPassed) {
    $allChecks += @{Name="Port Status"; Status="PASS"}
} else {
    $allChecks += @{Name="Port Status"; Status="FAIL"}
    Write-Host "`n     Troubleshooting:" -ForegroundColor Yellow
    Write-Host "     - Ensure server process is running" -ForegroundColor Gray
    Write-Host "     - Check firewall rules: Get-NetFirewallRule | Where-Object {`$_.DisplayName -like '*Enshrouded*'}" -ForegroundColor Gray
    Write-Host "     - Verify port configuration in enshrouded_server.json" -ForegroundColor Gray
}

# Check 3: Recent Logs
Write-Host "`n[3/3] Recent Server Logs" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Gray

$logDir = Join-Path $config.Paths.ServerInstall "logs"

if (Test-Path $logDir) {
    $latestLog = Get-ChildItem $logDir -Filter *.log -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($latestLog) {
        Write-Host "[OK] Log file found: $($latestLog.Name)" -ForegroundColor Green
        Write-Host "     Last Modified: $($latestLog.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        Write-Host "     Size: $(Format-ByteSize $latestLog.Length)" -ForegroundColor Gray
        
        Write-Host "`n     --- Last 30 Lines ---" -ForegroundColor Cyan
        try {
            $logLines = Get-Content $latestLog.FullName -Tail 30 -ErrorAction Stop
            foreach ($line in $logLines) {
                # Color code based on content
                if ($line -match "error|fail|exception" -and $line -notmatch "No error") {
                    Write-Host "     $line" -ForegroundColor Red
                } elseif ($line -match "warn|warning") {
                    Write-Host "     $line" -ForegroundColor Yellow
                } elseif ($line -match "started|ready|success") {
                    Write-Host "     $line" -ForegroundColor Green
                } else {
                    Write-Host "     $line" -ForegroundColor Gray
                }
            }
            
            Write-ServerLog "Log check PASSED - Recent logs retrieved from $($latestLog.Name)." -Level SUCCESS
            $allChecks += @{Name="Recent Logs"; Status="PASS"}
        } catch {
            Write-Host "     [WARN] Could not read log file: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-ServerLog "Log check WARNING - Could not read log file: $($_.Exception.Message)" -Level WARN
            $allChecks += @{Name="Recent Logs"; Status="WARN"}
        }
    } else {
        Write-Host "[INFO] No log files found yet." -ForegroundColor Yellow
        Write-Host "       Logs will appear after the server has been started." -ForegroundColor Gray
        Write-ServerLog "Log check INFO - No log files found (server may not have been started yet)." -Level INFO
        $allChecks += @{Name="Recent Logs"; Status="INFO"}
    }
} else {
    Write-Host "[INFO] Log directory not found: $logDir" -ForegroundColor Yellow
    Write-Host "       Logs will be created when the server starts." -ForegroundColor Gray
    Write-ServerLog "Log check INFO - Log directory does not exist yet." -Level INFO
    $allChecks += @{Name="Recent Logs"; Status="INFO"}
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Health Check Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$passCount = ($allChecks | Where-Object {$_.Status -eq "PASS"}).Count
$failCount = ($allChecks | Where-Object {$_.Status -eq "FAIL"}).Count
$warnCount = ($allChecks | Where-Object {$_.Status -eq "WARN"}).Count
$infoCount = ($allChecks | Where-Object {$_.Status -eq "INFO"}).Count

foreach ($check in $allChecks) {
    $color = switch ($check.Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host "$($check.Name): $($check.Status)" -ForegroundColor $color
}

Write-Host "`nResults: " -NoNewline
Write-Host "$passCount Passed" -ForegroundColor Green -NoNewline
Write-Host " | " -NoNewline
Write-Host "$failCount Failed" -ForegroundColor Red -NoNewline
Write-Host " | " -NoNewline
Write-Host "$warnCount Warnings" -ForegroundColor Yellow -NoNewline
Write-Host " | " -NoNewline
Write-Host "$infoCount Info" -ForegroundColor Cyan

if ($failCount -eq 0 -and $proc) {
    Write-Host "`n[OK] Server is healthy and operational!" -ForegroundColor Green
    Write-ServerLog "Health check PASSED - Server is healthy." -Level SUCCESS
} elseif ($failCount -eq 0 -and -not $proc) {
    Write-Host "`n[INFO] Server is not running." -ForegroundColor Yellow
    Write-ServerLog "Health check - Server is not running." -Level INFO
} else {
    Write-Host "`n[WARN] Server has issues that need attention." -ForegroundColor Yellow
    Write-ServerLog "Health check COMPLETED with $failCount failures and $warnCount warnings." -Level WARN
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
