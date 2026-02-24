<#
.SYNOPSIS
    Downloads the Enshrouded dedicated server files via SteamCMD.

.DESCRIPTION
    Uses SteamCMD to download and install the Enshrouded dedicated server
    (Steam App ID: 2278520) with anonymous login and file validation.

.EXAMPLE
    .\2-Download-Server.ps1
    Downloads the server to the configured installation directory.

.NOTES
    File Name  : 2-Download-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1, SteamCMD installed, Internet connection
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Download Enshrouded Server" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting server download..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration. Run 0-Initial-Setup.ps1 first." -ForegroundColor Red
    exit 1
}

# Verify SteamCMD exists
$steamCmdExe = Join-Path $config.Paths.SteamCMD "steamcmd.exe"
if (-not (Test-Path $steamCmdExe)) {
    Write-ServerLog "SteamCMD not found at: $steamCmdExe" -Level ERROR
    Write-Host "[FAIL] SteamCMD not found. Run 1-Install-Dependencies.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "SteamCMD Location: $steamCmdExe" -ForegroundColor Gray
Write-Host "Install Directory: $($config.Paths.ServerInstall)" -ForegroundColor Gray
Write-Host "App ID: 2278520 (Enshrouded Dedicated Server)`n" -ForegroundColor Gray

# Download/Update server
Write-Host "Starting download... (this may take several minutes)" -ForegroundColor Yellow
Write-Host "================================================`n" -ForegroundColor Gray
Write-ServerLog "Executing SteamCMD to download/update App ID 2278520..." -Level INFO

$arguments = @(
    "+force_install_dir `"$($config.Paths.ServerInstall)`"",
    "+login anonymous",
    "+app_update 2278520 validate",
    "+quit"
)

try {
    $process = Start-Process -FilePath $steamCmdExe -ArgumentList $arguments -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-ServerLog "SteamCMD exited with code: $($process.ExitCode)" -Level WARN
        Write-Host "`n[WARN] SteamCMD returned exit code $($process.ExitCode)." -ForegroundColor Yellow
        Write-Host "This may be normal. Verifying installation..." -ForegroundColor Yellow
    }
    
    Write-ServerLog "SteamCMD process completed." -Level INFO
} catch {
    Write-ServerLog "SteamCMD execution failed: $($_.Exception.Message)" -Level ERROR
    Write-Host "`n[FAIL] Failed to run SteamCMD." -ForegroundColor Red
    exit 1
}

# Verify installation
Write-Host "`n================================================" -ForegroundColor Gray
Write-Host "Verifying installation..." -ForegroundColor Yellow

$serverExe = Join-Path $config.Paths.ServerInstall "enshrouded_server.exe"

if (Test-Path $serverExe) {
    Write-Host "[OK] Server executable found!" -ForegroundColor Green
    Write-ServerLog "Server installation verified: $serverExe" -Level SUCCESS
    
    # Get file version if available
    try {
        $fileInfo = Get-Item $serverExe
        $version = $fileInfo.VersionInfo.FileVersion
        if ($version) {
            Write-Host "     Version: $version" -ForegroundColor Cyan
            Write-ServerLog "Server version: $version" -Level INFO
        }
        $sizeFormatted = Format-ByteSize $fileInfo.Length
        Write-Host "     Size: $sizeFormatted" -ForegroundColor Cyan
        Write-Host "     Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Cyan
    } catch {
        Write-ServerLog "Could not retrieve file version info: $($_.Exception.Message)" -Level WARN
    }
} else {
    Write-ServerLog "Server executable not found after download: $serverExe" -Level ERROR
    Write-Host "[FAIL] enshrouded_server.exe not found." -ForegroundColor Red
    Write-Host "`nCheck SteamCMD output above for errors." -ForegroundColor Yellow
    Write-Host "Common issues:" -ForegroundColor Yellow
    Write-Host "  - Network connectivity problems" -ForegroundColor Gray
    Write-Host "  - Steam service temporarily unavailable" -ForegroundColor Gray
    Write-Host "  - Insufficient disk space" -ForegroundColor Gray
    exit 1
}

# Display installation size
try {
    $installSize = (Get-ChildItem $config.Paths.ServerInstall -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $installSizeFormatted = Format-ByteSize $installSize
    Write-Host "`nTotal installation size: $installSizeFormatted" -ForegroundColor Cyan
    Write-ServerLog "Total installation size: $installSizeFormatted" -Level INFO
} catch {
    # Silently continue if size calculation fails
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Server Download Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Server download completed successfully." -Level SUCCESS

Write-Host "Server Location: $($config.Paths.ServerInstall)" -ForegroundColor Yellow
Write-Host "`nNext Step: Run 3-Configure-Server.ps1 to configure server settings." -ForegroundColor Yellow
Write-Host "`n" -NoNewline
