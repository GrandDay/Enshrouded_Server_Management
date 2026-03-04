<#
.SYNOPSIS
    Creates mock Enshrouded server files for testing/educational purposes.

.DESCRIPTION
    When the actual SteamCMD download fails (e.g., incorrect app ID), this script
    creates a placeholder server structure that allows testing the automation
    workflow without requiring actual server binaries.
    
    ⚠️  This is for TESTING ONLY. A mock server cannot actually host games.

.EXAMPLE
    .\2-Download-Server-Mock.ps1
    Creates mock server files for testing subsequent automation scripts.

.NOTES
    File Name  : 2-Download-Server-Mock.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Mock Server Setup (Testing Mode)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "⚠️  WARNING: This creates MOCK files for testing only." -ForegroundColor Yellow
Write-Host "    A mock server cannot host actual games.`n" -ForegroundColor Yellow

Write-ServerLog "Creating mock server structure for testing..." -Level WARN

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration. Run 0-Initial-Setup.ps1 first." -ForegroundColor Red
    exit 1
}

$serverPath = $config.Paths.ServerInstall
$mockExe = Join-Path $serverPath "enshrouded_server.exe"

# Create server directory
if (-not (Test-Path $serverPath)) {
    New-Item -ItemType Directory -Path $serverPath -Force | Out-Null
    Write-ServerLog "Created server directory: $serverPath" -Level INFO
}

# Create mock executable (empty file with .exe extension)
Write-Host "[1/4] Creating mock server executable..." -ForegroundColor Yellow
try {
    # Create a minimal Windows executable (PE header stub)
    $peStub = [byte[]]@(
        0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00,
        0xB8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    )
    [System.IO.File]::WriteAllBytes($mockExe, $peStub)
    
    Write-Host "  Created: $mockExe" -ForegroundColor Gray
    Write-ServerLog "Created mock executable: $mockExe" -Level SUCCESS
} catch {
    Write-ServerLog "Failed to create mock executable: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Could not create mock executable." -ForegroundColor Red
    exit 1
}

# Create typical server directory structure
Write-Host "`n[2/4] Creating directory structure..." -ForegroundColor Yellow
$mockDirs = @(
    "saves",
    "logs",
    "config"
)

foreach ($dir in $mockDirs) {
    $dirPath = Join-Path $serverPath $dir
    if (-not (Test-Path $dirPath)) {
        New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
        Write-Host "  Created: $dir/" -ForegroundColor Gray
    }
}

# Create mock server files
Write-Host "`n[3/4] Creating mock configuration files..." -ForegroundColor Yellow
$mockFiles = @{
    "enshrouded_server.json" = @{
        "name" = "Mock Server"
        "version" = "1.0.0-mock"
        "mode" = "testing"
    } | ConvertTo-Json
    
    "logs\server.log" = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Mock server log file created for testing`n"
    
    "README_MOCK.txt" = @"
========================================
MOCK SERVER - TESTING ONLY
========================================

This is a mock Enshrouded server structure created for
testing the PowerShell automation workflow.

This is NOT a real server and cannot host games.

Reasons for mock setup:
- Actual SteamCMD app ID may be incorrect or unavailable
- Educational/demonstration purposes
- Testing automation scripts without real server binaries

To use a real server:
1. Verify correct Enshrouded dedicated server app ID
2. Update app ID in 2-Download-Server.ps1
3. Delete this mock structure and run actual download

Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
========================================
"@
}

foreach ($file in $mockFiles.Keys) {
    $filePath = Join-Path $serverPath $file
    $mockFiles[$file] | Out-File -FilePath $filePath -Encoding UTF8 -Force
    Write-Host "  Created: $file" -ForegroundColor Gray
}

# Display summary
Write-Host "`n[4/4] Verification..." -ForegroundColor Yellow
$mockExeInfo = Get-Item $mockExe
$sizeFormatted = Format-ByteSize $mockExeInfo.Length
Write-Host "  Mock executable: $sizeFormatted" -ForegroundColor Gray
Write-Host "  Created: $($mockExeInfo.CreationTime)" -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Mock Server Setup Complete" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Mock server structure created successfully." -Level SUCCESS

Write-Host "Mock server location: $serverPath" -ForegroundColor Cyan
Write-Host "`n⚠️  Remember: This is for TESTING ONLY" -ForegroundColor Yellow
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  - Run 3-Configure-Server.ps1 to test configuration workflow" -ForegroundColor Gray
Write-Host "  - Run 4-Health-Check.ps1 to test health check logic" -ForegroundColor Gray
Write-Host "  - Run other scripts to validate automation workflow" -ForegroundColor Gray
Write-Host "`nTo use a real server:" -ForegroundColor Yellow
Write-Host "  1. Find correct Enshrouded dedicated server app ID" -ForegroundColor Gray
Write-Host "  2. Delete $serverPath" -ForegroundColor Gray
Write-Host "  3. Run 2-Download-Server.ps1 with correct app ID" -ForegroundColor Gray

Write-Host "`n" -NoNewline

