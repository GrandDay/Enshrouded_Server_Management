<#
.SYNOPSIS
    Hibernates the Enshrouded server VM by saving its state.

.DESCRIPTION
    Saves the running VM state to disk, freeing host resources (CPU, RAM).
    This script must be run on the Hyper-V host, not inside the guest VM.
    The VM can be quickly resumed later with Start-VM.

.PARAMETER VMName
    Name of the Hyper-V VM to hibernate. Defaults to "Enshrouded-Server".

.EXAMPLE
    .\Hibernate-VM.ps1
    Hibernates VM with default name.

.EXAMPLE
    .\Hibernate-VM.ps1 -VMName "My-Enshrouded-Server"
    Hibernates VM with custom name.

.NOTES
    File Name  : Hibernate-VM.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1, Hyper-V PowerShell module, Administrator privileges
    Location   : RUN ON HYPER-V HOST (not inside guest VM)
    Version    : 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$VMName = "Enshrouded-Server"
)

# Ensure running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[FAIL] This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Hibernate Hyper-V VM" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Ensure Hyper-V module is available
if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
    Write-Host "[FAIL] Hyper-V PowerShell module not found." -ForegroundColor Red
    Write-Host "This script must be run on a Hyper-V host with the Hyper-V module installed." -ForegroundColor Yellow
    exit 1
}

# Import Hyper-V module
try {
    Import-Module Hyper-V -ErrorAction Stop
} catch {
    Write-Host "[FAIL] Could not import Hyper-V module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify VM exists
Write-Host "Searching for VM: $VMName..." -ForegroundColor Yellow

$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if (-not $vm) {
    Write-Host "[FAIL] VM '$VMName' not found." -ForegroundColor Red
    Write-Host "`nAvailable VMs:" -ForegroundColor Yellow
    Get-VM | Select-Object Name, State | Format-Table -AutoSize
    exit 1
}

Write-Host "[OK] Found VM: $VMName" -ForegroundColor Green
Write-Host "     Current State: $($vm.State)" -ForegroundColor Gray
Write-Host "     Memory: $([math]::Round($vm.MemoryAssigned / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "     CPUs: $($vm.ProcessorCount)" -ForegroundColor Gray
Write-Host "     Uptime: $($vm.Uptime.Days)d $($vm.Uptime.Hours)h $($vm.Uptime.Minutes)m" -ForegroundColor Gray

# Check VM state
if ($vm.State -ne "Running") {
    Write-Host "`n[INFO] VM is already stopped (State: $($vm.State))." -ForegroundColor Yellow
    
    if ($vm.State -eq "Saved") {
        Write-Host "       VM state is already saved (hibernated)." -ForegroundColor Gray
    } elseif ($vm.State -eq "Off") {
        Write-Host "       VM is powered off." -ForegroundColor Gray
    }
    
    Write-Host "`nNo action needed." -ForegroundColor Cyan
    exit 0
}

# Display resource information before saving
$memorySavedGB = [math]::Round($vm.MemoryAssigned / 1GB, 2)

Write-Host "`nPreparing to save VM state..." -ForegroundColor Yellow
Write-Host "  This will free approximately $memorySavedGB GB of host RAM" -ForegroundColor Gray
Write-Host "  VM state will be preserved and can be resumed with Start-VM" -ForegroundColor Gray

Write-Host "`nSaving VM state (this may take a moment)..." -ForegroundColor Yellow

# Save VM state
try {
    $startTime = Get-Date
    
    Save-VM -Name $VMName -ErrorAction Stop
    
    $elapsed = (Get-Date) - $startTime
    
    Write-Host "[OK] VM state saved successfully!" -ForegroundColor Green
    Write-Host "     Duration: $([math]::Round($elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Cyan
    
} catch {
    Write-Host "[FAIL] Failed to save VM state: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify saved state
$vmAfter = Get-VM -Name $VMName -ErrorAction SilentlyContinue

if ($vmAfter.State -eq "Saved") {
    Write-Host "[OK] VM state verified: Saved" -ForegroundColor Green
} else {
    Write-Host "[WARN] VM state is: $($vmAfter.State) (expected: Saved)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  VM Hibernation Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "VM Status:" -ForegroundColor Cyan
Write-Host "  Name:          $VMName" -ForegroundColor White
Write-Host "  State:         $($vmAfter.State)" -ForegroundColor White
Write-Host "  Resources:     Released (CPU, RAM freed)" -ForegroundColor White
Write-Host "  Saved Memory:  ~$memorySavedGB GB" -ForegroundColor White

Write-Host "`nHost Benefits:" -ForegroundColor Cyan
Write-Host "  - Freed approximately $memorySavedGB GB of RAM" -ForegroundColor Green
Write-Host "  - Reduced CPU load from VM" -ForegroundColor Green
Write-Host "  - VM preserved and ready for quick resume" -ForegroundColor Green

Write-Host "`nTo Resume VM:" -ForegroundColor Yellow
Write-Host "  1. Start VM from host:           Start-VM -Name '$VMName'" -ForegroundColor Gray
Write-Host "  2. Wait for VM to resume (10-30 seconds)" -ForegroundColor Gray
Write-Host "  3. Check if server auto-started: (inside guest VM)" -ForegroundColor Gray
Write-Host "     If scheduled task configured, server should start automatically" -ForegroundColor Gray
Write-Host "     Otherwise, manually start:    .\scripts\guest\9-Start-Server.ps1" -ForegroundColor Gray

Write-Host "`nNote: VM memory is saved to disk. Resume time depends on amount of RAM." -ForegroundColor Gray
Write-Host "`n" -NoNewline
