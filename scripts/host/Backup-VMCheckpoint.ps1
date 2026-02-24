<#
.SYNOPSIS
    Creates a Hyper-V checkpoint (snapshot) of the Enshrouded server VM.

.DESCRIPTION
    Creates a timestamped Hyper-V checkpoint for VM backup before updates
    or configuration changes. This script must be run on the Hyper-V host,
    not inside the guest VM.

.PARAMETER VMName
    Name of the Hyper-V VM to checkpoint. Defaults to "Enshrouded-Server".

.EXAMPLE
    .\Backup-VMCheckpoint.ps1
    Creates checkpoint with default VM name.

.EXAMPLE
    .\Backup-VMCheckpoint.ps1 -VMName "My-Enshrouded-Server"
    Creates checkpoint for VM with custom name.

.NOTES
    File Name  : Backup-VMCheckpoint.ps1
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
Write-Host "  Create Hyper-V Checkpoint" -ForegroundColor Cyan
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
Write-Host "     State: $($vm.State)" -ForegroundColor Gray
Write-Host "     Memory: $([math]::Round($vm.MemoryAssigned / 1GB, 2)) GB" -ForegroundColor Gray
Write-Host "     Uptime: $($vm.Uptime.Days)d $($vm.Uptime.Hours)h $($vm.Uptime.Minutes)m" -ForegroundColor Gray

# Generate checkpoint name with timestamp
$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$CheckpointName = "Enshrouded-Backup-$Timestamp"

Write-Host "`nCreating checkpoint..." -ForegroundColor Yellow
Write-Host "  Checkpoint Name: $CheckpointName" -ForegroundColor Gray

# Create checkpoint
try {
    $startTime = Get-Date
    
    Checkpoint-VM -Name $VMName -SnapshotName $CheckpointName -ErrorAction Stop
    
    $elapsed = (Get-Date) - $startTime
    
    Write-Host "[OK] Hyper-V checkpoint created successfully!" -ForegroundColor Green
    Write-Host "     Duration: $([math]::Round($elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Cyan
    
} catch {
    Write-Host "[FAIL] Failed to create checkpoint: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify and display checkpoint details
try {
    $checkpoint = Get-VMCheckpoint -VMName $VMName -Name $CheckpointName -ErrorAction Stop
    
    Write-Host "`nCheckpoint Details:" -ForegroundColor Cyan
    Write-Host "  Name:         $($checkpoint.Name)" -ForegroundColor White
    Write-Host "  Created:      $($checkpoint.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "  Type:         $($checkpoint.CheckpointType)" -ForegroundColor White
    Write-Host "  Parent VM:    $($checkpoint.VMName)" -ForegroundColor White
    
    # Get checkpoint file size if available
    try {
        $checkpointPath = $checkpoint.Path
        if ($checkpointPath -and (Test-Path $checkpointPath)) {
            $checkpointSize = (Get-ChildItem $checkpointPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $checkpointSizeGB = [math]::Round($checkpointSize / 1GB, 2)
            Write-Host "  Size:         $checkpointSizeGB GB" -ForegroundColor White
        }
    } catch {
        # Silently continue if size calculation fails
    }
    
} catch {
    Write-Host "[WARN] Could not retrieve checkpoint details: $($_.Exception.Message)" -ForegroundColor Yellow
}

# List all checkpoints for this VM
Write-Host "`nAll Checkpoints for VM '$VMName':" -ForegroundColor Cyan
$allCheckpoints = Get-VMCheckpoint -VMName $VMName | Sort-Object CreationTime -Descending

if ($allCheckpoints) {
    $allCheckpoints | Select-Object Name, @{Name='Created';Expression={$_.CreationTime.ToString('yyyy-MM-dd HH:mm:ss')}}, CheckpointType | 
        Format-Table -AutoSize
    
    Write-Host "Total Checkpoints: $($allCheckpoints.Count)" -ForegroundColor Gray
} else {
    Write-Host "  No checkpoints found." -ForegroundColor Gray
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Checkpoint Created Successfully!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Checkpoint Information:" -ForegroundColor Cyan
Write-Host "  VM:        $VMName" -ForegroundColor White
Write-Host "  Checkpoint: $CheckpointName" -ForegroundColor White
Write-Host "  Status:    Active" -ForegroundColor White

Write-Host "`nManagement Commands:" -ForegroundColor Yellow
Write-Host "  View checkpoints:   Get-VMCheckpoint -VMName '$VMName'" -ForegroundColor Gray
Write-Host "  Restore checkpoint: Restore-VMCheckpoint -VMName '$VMName' -Name '$CheckpointName' -Confirm:`$false" -ForegroundColor Gray
Write-Host "  Delete checkpoint:  Remove-VMCheckpoint -VMName '$VMName' -Name '$CheckpointName' -Confirm:`$false" -ForegroundColor Gray

Write-Host "`n[INFO] Remember to clean up old checkpoints periodically to save disk space." -ForegroundColor Yellow
Write-Host "`n" -NoNewline
