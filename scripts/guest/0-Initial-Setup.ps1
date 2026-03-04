<#
.SYNOPSIS
    Automated initial setup for Enshrouded dedicated server.

.DESCRIPTION
    Master setup script that performs complete first-time server setup by running
    scripts 1, 2, and 3 in sequence. Handles configuration deployment, dependency
    installation, server download, and initial configuration.

.PARAMETER ConfigPath
    Path to the configuration template file. Defaults to repository config template.

.EXAMPLE
    .\0-Initial-Setup.ps1
    Runs automated setup with default configuration.

.EXAMPLE
    .\0-Initial-Setup.ps1 -ConfigPath "C:\Custom\config.json"
    Runs setup with custom configuration file.

.NOTES
    File Name  : 0-Initial-Setup.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1, Administrator privileges
    Version    : 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "$PSScriptRoot\..\..\config\EnshroudedServerConfig.json"
)

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

# Initialize transcript logging
Write-Host "[*] Initializing transcript logging..." -ForegroundColor Gray
$transcriptPath = Initialize-TranscriptLogging
if ($transcriptPath) {
    Write-Host "    Transcript: $transcriptPath" -ForegroundColor Gray
}

# Ensure running as administrator
if (-not (Test-AdminPrivileges)) {
    Write-ServerLog "This script requires administrator privileges." -Level ERROR
    Write-Host "`nPlease run PowerShell as Administrator and try again." -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Enshrouded Server - Initial Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting initial setup..." -Level INFO

# Step 1: Deploy configuration
Write-Host "`n[Step 1/4] Deploying Configuration" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Gray

$targetConfigPath = "C:\EnshroudedServer\EnshroudedServerConfig.json"

if (-not (Test-Path $ConfigPath)) {
    Write-ServerLog "Configuration template not found: $ConfigPath" -Level ERROR
    Write-Host "`nERROR: Configuration template not found." -ForegroundColor Red
    Write-Host "Expected location: $ConfigPath" -ForegroundColor Gray
    exit 1
}

# Create target directory if needed
$targetDir = Split-Path $targetConfigPath -Parent
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Write-ServerLog "Created directory: $targetDir" -Level INFO
}

# Copy configuration
try {
    Copy-Item -Path $ConfigPath -Destination $targetConfigPath -Force
    Write-ServerLog "Configuration deployed to: $targetConfigPath" -Level SUCCESS
    Write-Host "[OK] Configuration deployed successfully." -ForegroundColor Green
} catch {
    Write-ServerLog "Failed to deploy configuration: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to deploy configuration." -ForegroundColor Red
    exit 1
}

# Display configuration
Write-Host "`nCurrent Configuration:" -ForegroundColor Cyan
$config = Get-Content $targetConfigPath | ConvertFrom-Json
Write-Host "  Server Name: $($config.Server.Name)" -ForegroundColor Gray
Write-Host "  Max Players: $($config.Server.SlotCount)" -ForegroundColor Gray
Write-Host "  Game Port:   $($config.Server.GamePort)" -ForegroundColor Gray
Write-Host "  Query Port:  $($config.Server.QueryPort)" -ForegroundColor Gray
Write-Host "  Password:    $(if ($config.Server.Password) { '(set - private server)' } else { '(not set - public server)' })" -ForegroundColor Gray

Write-Host "`nPress Enter to continue with these settings, or Ctrl+C to exit and edit configuration..." -ForegroundColor Yellow
Read-Host

# Step 1.5: Environment Detection
Write-Host "`n[Step 1.5/4] Environment Detection" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Gray
Write-ServerLog "Starting environment detection..." -Level INFO

try {
    $detectedEnv = Get-EnvironmentType
    Write-Host "`nDetected Environment: $($detectedEnv.EnvironmentType)" -ForegroundColor Cyan
    Write-Host "  Detection Method: $($detectedEnv.DetectionMethod)" -ForegroundColor Gray
    Write-Host "  Is Virtual Machine: $($detectedEnv.IsVM)" -ForegroundColor Gray
    Write-Host "  Confidence Level: $($detectedEnv.Confidence)" -ForegroundColor Gray
    
    Write-ServerLog "Detected environment: $($detectedEnv.EnvironmentType) (Method: $($detectedEnv.DetectionMethod), Confidence: $($detectedEnv.Confidence))" -Level INFO
    
    # Prompt user to confirm or override
    Write-Host "`nIs this detection correct?" -ForegroundColor Yellow
    
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new('&Yes', 'Use detected environment'),
        [System.Management.Automation.Host.ChoiceDescription]::new('&No', 'Choose different environment'),
        [System.Management.Automation.Host.ChoiceDescription]::new('&Manual Override', 'Manually specify environment (expert option)')
    )
    
    $choiceResult = $Host.UI.PromptForChoice("Environment Confirmation", "Please confirm the detected environment", $choices, 0)
    
    $environmentToUse = $detectedEnv.EnvironmentType
    $needsOverride = $false
    
    if ($choiceResult -eq 1) {
        # User wants to choose different environment
        Write-Host "`nSelect your environment:" -ForegroundColor Yellow
        $envChoices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new('&HyperV', 'Windows Hyper-V Virtual Machine'),
            [System.Management.Automation.Host.ChoiceDescription]::new('&Proxmox', 'Proxmox/QEMU Virtual Machine'),
            [System.Management.Automation.Host.ChoiceDescription]::new('&BareMetal', 'Bare Metal / Physical Hardware'),
            [System.Management.Automation.Host.ChoiceDescription]::new('&WSL', 'Windows Subsystem for Linux')
        )
        
        $envChoice = $Host.UI.PromptForChoice("Environment Selection", "Select your hosting environment", $envChoices, 0)
        $environmentToUse = @('HyperV', 'Proxmox', 'BareMetal', 'WSL')[$envChoice]
        $needsOverride = $true
        Write-ServerLog "User selected environment override: $environmentToUse" -Level INFO
    } elseif ($choiceResult -eq 2) {
        # Expert manual override
        Write-Host "`nSelect environment (expert mode):" -ForegroundColor Yellow
        Write-Host "  1 - HyperV" -ForegroundColor Gray
        Write-Host "  2 - Proxmox" -ForegroundColor Gray
        Write-Host "  3 - BareMetal" -ForegroundColor Gray
        Write-Host "  4 - WSL" -ForegroundColor Gray
        $selection = Read-Host "Enter choice (1-4)"
        
        $environmentToUse = @('HyperV', 'Proxmox', 'BareMetal', 'WSL')[[int]$selection - 1]
        $needsOverride = $true
        Write-ServerLog "Expert mode override: $environmentToUse" -Level INFO
    }
    
    # Store environment in configuration
    $config.Environment.DetectedEnvironment = $detectedEnv.EnvironmentType
    if ($needsOverride) {
        $config.Environment.EnvironmentOverride = $environmentToUse
    }
    
    # Save updated configuration
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $targetConfigPath -Encoding UTF8
    Write-ServerLog "Configuration updated with environment: $environmentToUse" -Level SUCCESS
    Write-Host "[OK] Environment configured: $environmentToUse" -ForegroundColor Green
} catch {
    Write-ServerLog "Environment detection failed: $($_.Exception.Message)" -Level ERROR
    Write-Host "`n[WARN] Environment auto-detection failed. Proceeding with manual configuration step." -ForegroundColor Yellow
    $environmentToUse = "BareMetal"  # Safe fallback
}

Write-Host "`nPress Enter to continue..." -ForegroundColor Yellow
Read-Host

# Step 2: Install Dependencies
Write-Host "`n[Step 2/4] Installing Dependencies" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Gray
Write-ServerLog "Executing: 1-Install-Dependencies.ps1" -Level INFO

try {
    & "$PSScriptRoot\1-Install-Dependencies.ps1"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Script returned exit code: $LASTEXITCODE"
    }
    Write-ServerLog "Dependency installation completed successfully." -Level SUCCESS
} catch {
    Write-ServerLog "Dependency installation failed: $($_.Exception.Message)" -Level ERROR
    Write-Host "`n[FAIL] Setup failed at dependency installation step." -ForegroundColor Red
    Write-Host "Check logs at: C:\EnshroudedServer\ManagementLogs\" -ForegroundColor Gray
    exit 1
}

# Step 3: Download Server
Write-Host "`n[Step 3/4] Downloading Enshrouded Server" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Gray
Write-ServerLog "Executing: 2-Download-Server.ps1" -Level INFO

try {
    & "$PSScriptRoot\2-Download-Server.ps1"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Script returned exit code: $LASTEXITCODE"
    }
    Write-ServerLog "Server download completed successfully." -Level SUCCESS
} catch {
    Write-ServerLog "Server download failed: $($_.Exception.Message)" -Level ERROR
    Write-Host "`n[FAIL] Setup failed at server download step." -ForegroundColor Red
    Write-Host "Check logs at: C:\EnshroudedServer\ManagementLogs\" -ForegroundColor Gray
    exit 1
}

# Step 4: Configure Server
Write-Host "`n[Step 4/4] Configuring Server Settings" -ForegroundColor Yellow
Write-Host "------------------------------------------------" -ForegroundColor Gray
Write-ServerLog "Executing: 3-Configure-Server.ps1" -Level INFO

try {
    & "$PSScriptRoot\3-Configure-Server.ps1"
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Script returned exit code: $LASTEXITCODE"
    }
    Write-ServerLog "Server configuration completed successfully." -Level SUCCESS
} catch {
    Write-ServerLog "Server configuration failed: $($_.Exception.Message)" -Level ERROR
    Write-Host "`n[FAIL] Setup failed at server configuration step." -ForegroundColor Red
    Write-Host "Check logs at: C:\EnshroudedServer\ManagementLogs\" -ForegroundColor Gray
    exit 1
}

# Setup complete
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Initial Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Initial setup completed successfully." -Level SUCCESS

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Setup auto-start:  .\scripts\guest\8-Setup-ScheduledTask.ps1" -ForegroundColor Gray
Write-Host "  2. Setup alias:       .\scripts\guest\6-Setup-Alias.ps1" -ForegroundColor Gray
Write-Host "  3. Start server:      .\scripts\guest\9-Start-Server.ps1" -ForegroundColor Gray
Write-Host "  4. Check health:      .\scripts\guest\4-Health-Check.ps1" -ForegroundColor Gray

Write-Host "`nServer Installation Directory: $($config.Paths.ServerInstall)" -ForegroundColor Yellow
Write-Host "Configuration File: $targetConfigPath" -ForegroundColor Yellow
Write-Host "Management Logs: $($config.Paths.ManagementLogs)" -ForegroundColor Yellow

Write-Host "`n" -NoNewline
