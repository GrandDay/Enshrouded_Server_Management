<#
.SYNOPSIS
    Installs dependencies and SteamCMD for Enshrouded dedicated server.

.DESCRIPTION
    Performs initial system setup including:
    - Creates required directory structure
    - Downloads and extracts SteamCMD
    - Installs Visual C++ Redistributable (if needed)
    - Configures Windows Firewall rules for game ports

.EXAMPLE
    .\1-Install-Dependencies.ps1
    Runs dependency installation with default settings.

.NOTES
    File Name  : 1-Install-Dependencies.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1, Administrator privileges, Internet connection
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
Write-Host "  Install Dependencies" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting dependency installation..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration. Run 0-Initial-Setup.ps1 first." -ForegroundColor Red
    exit 1
}

# Step 1: Create directory structure
Write-Host "[1/4] Creating Directory Structure..." -ForegroundColor Yellow
Write-ServerLog "Creating directory structure..." -Level INFO

$directories = @(
    $config.Paths.SteamCMD,
    $config.Paths.ServerInstall,
    $config.Paths.Backup,
    $config.Paths.ManagementLogs
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "  Created: $dir" -ForegroundColor Gray
            Write-ServerLog "Created directory: $dir" -Level INFO
        } catch {
            Write-ServerLog "Failed to create directory $dir : $($_.Exception.Message)" -Level ERROR
            Write-Host "[FAIL] Failed to create directory: $dir" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  Exists:  $dir" -ForegroundColor Gray
    }
}

Write-Host "[OK] Directory structure ready." -ForegroundColor Green

# Step 2: Download and extract SteamCMD
Write-Host "`n[2/4] Downloading SteamCMD..." -ForegroundColor Yellow
Write-ServerLog "Downloading SteamCMD..." -Level INFO

$steamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
$steamCmdZip = Join-Path $env:TEMP "steamcmd.zip"
$steamCmdExe = Join-Path $config.Paths.SteamCMD "steamcmd.exe"

if (Test-Path $steamCmdExe) {
    Write-Host "  SteamCMD already installed." -ForegroundColor Gray
    Write-ServerLog "SteamCMD already present, skipping download." -Level INFO
} else {
    try {
        Write-Host "  Downloading from: $steamCmdUrl" -ForegroundColor Gray
        Invoke-WebRequest -Uri $steamCmdUrl -OutFile $steamCmdZip -UseBasicParsing -ErrorAction Stop
        Write-ServerLog "SteamCMD downloaded successfully." -Level SUCCESS
        
        Write-Host "  Extracting to: $($config.Paths.SteamCMD)" -ForegroundColor Gray
        Expand-Archive -Path $steamCmdZip -DestinationPath $config.Paths.SteamCMD -Force
        Remove-Item $steamCmdZip -Force
        Write-ServerLog "SteamCMD extracted successfully." -Level SUCCESS
        
        Write-Host "[OK] SteamCMD installed successfully." -ForegroundColor Green
    } catch {
        Write-ServerLog "Failed to download/extract SteamCMD: $($_.Exception.Message)" -Level ERROR
        Write-Host "[FAIL] Failed to install SteamCMD." -ForegroundColor Red
        exit 1
    }
}

# Step 3: Check/Install Visual C++ Redistributable
Write-Host "`n[3/4] Checking Visual C++ Redistributable..." -ForegroundColor Yellow
Write-ServerLog "Checking for Visual C++ Redistributable..." -Level INFO

$vcRedistInstalled = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
if ($vcRedistInstalled -and $vcRedistInstalled.Installed -eq 1) {
    Write-Host "  Visual C++ Redistributable already installed." -ForegroundColor Gray
    Write-ServerLog "Visual C++ Redistributable detected (Version: $($vcRedistInstalled.Version))." -Level INFO
    Write-Host "[OK] Visual C++ Redistributable present." -ForegroundColor Green
} else {
    Write-Host "  Visual C++ Redistributable not detected." -ForegroundColor Yellow
    Write-Host "  Enshrouded server requires Visual C++ Redistributable." -ForegroundColor Yellow
    Write-Host "  Please download and install from:" -ForegroundColor Yellow
    Write-Host "  https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Cyan
    Write-ServerLog "Visual C++ Redistributable not found. User notified to install manually." -Level WARN
    
    Write-Host "`n  Install now? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    if ($response -eq 'Y' -or $response -eq 'y') {
        $vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcRedistPath = Join-Path $env:TEMP "vc_redist.x64.exe"
        
        try {
            Write-Host "  Downloading installer..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $vcRedistUrl -OutFile $vcRedistPath -UseBasicParsing
            
            Write-Host "  Running installer (this may take a few minutes)..." -ForegroundColor Gray
            Start-Process -FilePath $vcRedistPath -ArgumentList "/install", "/quiet", "/norestart" -Wait
            Remove-Item $vcRedistPath -Force
            
            Write-Host "[OK] Visual C++ Redistributable installed." -ForegroundColor Green
            Write-ServerLog "Visual C++ Redistributable installed successfully." -Level SUCCESS
        } catch {
            Write-ServerLog "Failed to install Visual C++ Redistributable: $($_.Exception.Message)" -Level ERROR
            Write-Host "[WARN] Failed to install automatically. Please install manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WARN] Skipped Visual C++ installation. Server may not start without it." -ForegroundColor Yellow
    }
}

# Step 4: Configure Windows Firewall
Write-Host "`n[4/4] Configuring Windows Firewall..." -ForegroundColor Yellow
Write-ServerLog "Configuring firewall rules..." -Level INFO

$gamePort = $config.Server.GamePort
$queryPort = $config.Server.QueryPort

# Check if rules already exist
$gameRule = Get-NetFirewallRule -DisplayName "Enshrouded Game Port" -ErrorAction SilentlyContinue
$queryRule = Get-NetFirewallRule -DisplayName "Enshrouded Query Port" -ErrorAction SilentlyContinue

if (-not $gameRule) {
    try {
        New-NetFirewallRule -DisplayName "Enshrouded Game Port" -Direction Inbound `
            -Protocol UDP -LocalPort $gamePort -Action Allow -ErrorAction Stop | Out-Null
        Write-Host "  Created firewall rule for game port $gamePort (UDP)" -ForegroundColor Gray
        Write-ServerLog "Created firewall rule for port $gamePort UDP." -Level SUCCESS
    } catch {
        Write-ServerLog "Failed to create firewall rule for port $gamePort : $($_.Exception.Message)" -Level ERROR
        Write-Host "[WARN] Failed to create game port firewall rule." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Firewall rule for game port $gamePort already exists." -ForegroundColor Gray
}

if (-not $queryRule) {
    try {
        New-NetFirewallRule -DisplayName "Enshrouded Query Port" -Direction Inbound `
            -Protocol UDP -LocalPort $queryPort -Action Allow -ErrorAction Stop | Out-Null
        Write-Host "  Created firewall rule for query port $queryPort (UDP)" -ForegroundColor Gray
        Write-ServerLog "Created firewall rule for port $queryPort UDP." -Level SUCCESS
    } catch {
        Write-ServerLog "Failed to create firewall rule for port $queryPort : $($_.Exception.Message)" -Level ERROR
        Write-Host "[WARN] Failed to create query port firewall rule." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Firewall rule for query port $queryPort already exists." -ForegroundColor Gray
}

Write-Host "[OK] Firewall configuration complete." -ForegroundColor Green

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Dependency Installation Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Dependency installation completed successfully." -Level SUCCESS

Write-Host "Installed Components:" -ForegroundColor Cyan
Write-Host "  - SteamCMD:    $($config.Paths.SteamCMD)" -ForegroundColor Gray
Write-Host "  - Directories: Created/Verified" -ForegroundColor Gray
Write-Host "  - Firewall:    Configured for ports $gamePort, $queryPort (UDP)" -ForegroundColor Gray

Write-Host "`nNext Step: Run 2-Download-Server.ps1 to download the Enshrouded server." -ForegroundColor Yellow
Write-Host "`n" -NoNewline
