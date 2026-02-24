<#
.SYNOPSIS
    Creates backup archive of Enshrouded server files.

.DESCRIPTION
    Creates a timestamped ZIP archive of the server installation directory,
    excluding logs and previous backups. Automatically rotates old backups
    based on configured retention count.

.EXAMPLE
    .\7-Backup-GameFiles.ps1
    Creates backup with default retention policy.

.NOTES
    File Name  : 7-Backup-GameFiles.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Backup Game Files" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting game files backup..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration." -ForegroundColor Red
    exit 1
}

# Backup configuration
$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$BackupFile = Join-Path $config.Paths.Backup "enshrouded-backup-$Timestamp.zip"
$SourceDir = $config.Paths.ServerInstall
$RetentionCount = $config.Backup.RetentionCount

Write-Host "Source Directory: $SourceDir" -ForegroundColor Gray
Write-Host "Backup File:      $BackupFile" -ForegroundColor Gray
Write-Host "Retention Count:  $RetentionCount backups`n" -ForegroundColor Gray

# Verify source directory exists
if (-not (Test-Path $SourceDir)) {
    Write-ServerLog "Source directory not found: $SourceDir" -Level ERROR
    Write-Host "[FAIL] Source directory not found." -ForegroundColor Red
    exit 1
}

# Ensure backup directory exists
if (-not (Test-Path $config.Paths.Backup)) {
    New-Item -ItemType Directory -Path $config.Paths.Backup -Force | Out-Null
    Write-ServerLog "Created backup directory: $($config.Paths.Backup)" -Level INFO
}

# Collect files to backup (exclude certain directories)
Write-Host "Collecting files to backup..." -ForegroundColor Yellow

$excludeDirs = @(
    $config.Paths.Backup,
    (Join-Path $SourceDir "logs"),
    $config.Paths.ManagementLogs
)

try {
    $filesToBackup = Get-ChildItem $SourceDir -Recurse -File -ErrorAction Stop | Where-Object {
        $filePath = $_.FullName
        $excluded = $false
        
        foreach ($excludeDir in $excludeDirs) {
            if ($filePath.StartsWith($excludeDir)) {
                $excluded = $true
                break
            }
        }
        
        -not $excluded
    }
    
    $fileCount = $filesToBackup.Count
    $totalSize = ($filesToBackup | Measure-Object -Property Length -Sum).Sum
    $totalSizeFormatted = Format-ByteSize $totalSize
    
    Write-Host "[OK] Found $fileCount files to backup ($totalSizeFormatted)" -ForegroundColor Green
    Write-ServerLog "Collected $fileCount files for backup ($totalSizeFormatted)." -Level INFO
} catch {
    Write-ServerLog "Error collecting files: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Error collecting files to backup." -ForegroundColor Red
    exit 1
}

# Create backup archive
Write-Host "`nCreating backup archive..." -ForegroundColor Yellow
Write-Host "(This may take several minutes depending on server size)`n" -ForegroundColor Gray

$startTime = Get-Date

try {
    # Create temp list file for better archive structure
    $fileListPath = Join-Path $env:TEMP "enshrouded-backup-$Timestamp.txt"
    $filesToBackup.FullName | Set-Content $fileListPath
    
    Compress-Archive -Path $filesToBackup.FullName -DestinationPath $BackupFile -CompressionLevel Optimal -ErrorAction Stop
    Remove-Item $fileListPath -Force -ErrorAction SilentlyContinue
    
    $elapsed = (Get-Date) - $startTime
    $backupSize = (Get-Item $BackupFile).Length
    $backupSizeFormatted = Format-ByteSize $backupSize
    $compressionRatio = [math]::Round((1 - ($backupSize / $totalSize)) * 100, 1)
    
    Write-Host "[OK] Backup created successfully!" -ForegroundColor Green
    Write-Host "     File:         $BackupFile" -ForegroundColor Cyan
    Write-Host "     Size:         $backupSizeFormatted (compression: $compressionRatio%)" -ForegroundColor Cyan
    Write-Host "     Duration:     $([math]::Round($elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Cyan
    
    Write-ServerLog "Backup created: $BackupFile ($backupSizeFormatted) in $([math]::Round($elapsed.TotalSeconds, 1))s." -Level SUCCESS
} catch {
    Write-ServerLog "Failed to create backup archive: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to create backup archive." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Rotate old backups
Write-Host "`nRotating old backups..." -ForegroundColor Yellow

$existingBackups = Get-ChildItem $config.Paths.Backup -Filter "enshrouded-backup-*.zip" -ErrorAction SilentlyContinue | 
    Sort-Object CreationTime -Descending

$backupCount = $existingBackups.Count
Write-Host "Found $backupCount backup(s) in directory." -ForegroundColor Gray

if ($backupCount -gt $RetentionCount) {
    $toDelete = $existingBackups | Select-Object -Skip $RetentionCount
    $deleteCount = $toDelete.Count
    
    Write-Host "Removing $deleteCount old backup(s) (keeping last $RetentionCount)..." -ForegroundColor Gray
    
    foreach ($old in $toDelete) {
        try {
            $oldSize = Format-ByteSize $old.Length
            Remove-Item $old.FullName -Force
            Write-Host "  Deleted: $($old.Name) ($oldSize)" -ForegroundColor DarkGray
            Write-ServerLog "Deleted old backup: $($old.Name)" -Level INFO
        } catch {
            Write-Host "  [WARN] Could not delete: $($old.Name)" -ForegroundColor Yellow
            Write-ServerLog "Could not delete old backup $($old.Name): $($_.Exception.Message)" -Level WARN
        }
    }
    
    Write-Host "[OK] Backup rotation complete." -ForegroundColor Green
} else {
    Write-Host "[OK] No rotation needed (under retention limit)." -ForegroundColor Green
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Backup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Backup process completed successfully." -Level SUCCESS

Write-Host "Backup Summary:" -ForegroundColor Cyan
Write-Host "  Latest Backup: $BackupFile" -ForegroundColor White
Write-Host "  Total Backups: $($existingBackups.Count)" -ForegroundColor White
Write-Host "  Backup Size:   $backupSizeFormatted" -ForegroundColor White

Write-Host "`nRestore Instructions:" -ForegroundColor Yellow
Write-Host "  1. Stop server:    .\10-Stop-Server.ps1" -ForegroundColor Gray
Write-Host "  2. Extract backup: Expand-Archive '$BackupFile' -DestinationPath 'C:\EnshroudedServer' -Force" -ForegroundColor Gray
Write-Host "  3. Start server:   .\9-Start-Server.ps1" -ForegroundColor Gray

Write-Host "`n" -NoNewline
