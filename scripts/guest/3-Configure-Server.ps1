<#
.SYNOPSIS
    Configures Enshrouded server settings.

.DESCRIPTION
    Reads settings from the management configuration file and applies them to
    the Enshrouded server configuration file (enshrouded_server.json).
    Creates the server config file with the full schema if it doesn't exist,
    including interactive password setup for user groups.

.PARAMETER ResetPasswords
    When specified, prompts to reset passwords for all user groups even when
    loading an existing server configuration.

.EXAMPLE
    .\3-Configure-Server.ps1
    Applies configuration from EnshroudedServerConfig.json to server.

.EXAMPLE
    .\3-Configure-Server.ps1 -ResetPasswords
    Applies configuration and prompts to reset all user group passwords.

.NOTES
    File Name  : 3-Configure-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 2.0
#>

[CmdletBinding()]
param(
    [switch]$ResetPasswords
)

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

# --- Helper: Generate a random password ---
function New-RandomPassword {
    param([int]$Length = 16)
    $chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&*'
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    $password = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    return $password
}

# --- Helper: Prompt for or generate a password for a user group ---
function Get-UserGroupPassword {
    param([string]$GroupName)
    Write-Host "`n  Enter password for '$GroupName' group (or press Enter to auto-generate):" -ForegroundColor Yellow -NoNewline
    $input = Read-Host " "
    if ([string]::IsNullOrWhiteSpace($input)) {
        $generated = New-RandomPassword -Length 16
        Write-Host "  [AUTO] Generated password for '$GroupName': $generated" -ForegroundColor Cyan
        return $generated
    }
    while ($input.Length -lt 8) {
        Write-Host "  [WARN] Password must be at least 8 characters. Try again:" -ForegroundColor Red -NoNewline
        $input = Read-Host " "
    }
    return $input
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Configure Server Settings" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting server configuration..." -Level INFO

# Load management configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration. Run 0-Initial-Setup.ps1 first." -ForegroundColor Red
    exit 1
}

# Server config file path
$serverConfigPath = Join-Path $config.Paths.ServerInstall "enshrouded_server.json"

Write-Host "Management Config: C:\EnshroudedServer\EnshroudedServerConfig.json" -ForegroundColor Gray
Write-Host "Server Config:     $serverConfigPath`n" -ForegroundColor Gray

# Track whether this is a new config (needs password setup)
$isNewConfig = $false

# Load or create server config
if (Test-Path $serverConfigPath) {
    Write-Host "Loading existing server configuration..." -ForegroundColor Yellow
    try {
        $serverConfig = Get-Content $serverConfigPath -Raw | ConvertFrom-Json
        Write-ServerLog "Loaded existing server configuration." -Level INFO
    } catch {
        Write-ServerLog "Failed to parse existing server config: $($_.Exception.Message)" -Level ERROR
        Write-Host "[FAIL] Failed to parse existing server configuration." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Creating new server configuration..." -ForegroundColor Yellow
    Write-ServerLog "Creating new server configuration file." -Level INFO
    $isNewConfig = $true

    # Build the full default server config matching the Enshrouded server schema
    $serverConfig = [ordered]@{
        name                = ""
        saveDirectory       = "./savegame"
        logDirectory        = "./logs"
        ip                  = "0.0.0.0"
        queryPort           = 15637
        slotCount           = 16
        tags                = @()
        voiceChatMode       = "Proximity"
        enableVoiceChat     = $false
        enableTextChat      = $true
        gameSettingsPreset  = "Default"
        gameSettings        = [ordered]@{
            playerHealthFactor              = 1
            playerManaFactor                = 1
            playerStaminaFactor             = 1
            playerBodyHeatFactor            = 1
            playerDivingTimeFactor          = 1.0
            enableDurability                = $true
            enableStarvingDebuff            = $false
            foodBuffDurationFactor          = 1
            fromHungerToStarving            = 600000000000
            shroudTimeFactor                = 1.0
            tombstoneMode                   = "AddTombstone"
            enableGliderTurbulences         = $true
            weatherFrequency                = "Normal"
            fishingDifficulty               = "Normal"
            miningDamageFactor              = 1.0
            plantGrowthSpeedFactor          = 1.0
            resourceDropStackAmountFactor   = 1.0
            factoryProductionSpeedFactor    = 1.0
            perkUpgradeRecyclingFactor      = 0.500000
            perkCostFactor                  = 1
            experienceCombatFactor           = 1
            experienceMiningFactor           = 1
            experienceExplorationQuestsFactor = 1
            randomSpawnerAmount             = "Normal"
            aggroPoolAmount                 = "Normal"
            enemyDamageFactor               = 1
            enemyHealthFactor               = 1
            enemyStaminaFactor              = 1
            enemyPerceptionRangeFactor      = 1
            bossDamageFactor                = 1
            bossHealthFactor                = 1
            threatBonus                     = 1
            pacifyAllEnemies                = $false
            tamingStartleRepercussion       = "LoseSomeProgress"
            dayTimeDuration                 = 1800000000000
            nightTimeDuration               = 720000000000
            curseModifier                   = "Normal"
        }
        userGroups          = @(
            [ordered]@{
                name                 = "Admin"
                password             = ""
                canKickBan           = $true
                canAccessInventories = $true
                canEditWorld         = $true
                canEditBase          = $true
                canExtendBase        = $true
                reservedSlots        = 0
            },
            [ordered]@{
                name                 = "Friend"
                password             = ""
                canKickBan           = $false
                canAccessInventories = $true
                canEditWorld         = $true
                canEditBase          = $true
                canExtendBase        = $true
                reservedSlots        = 0
            },
            [ordered]@{
                name                 = "Guest"
                password             = ""
                canKickBan           = $false
                canAccessInventories = $false
                canEditWorld         = $true
                canEditBase          = $false
                canExtendBase        = $false
                reservedSlots        = 0
            },
            [ordered]@{
                name                 = "Visitor"
                password             = ""
                canKickBan           = $false
                canAccessInventories = $false
                canEditWorld         = $false
                canEditBase          = $false
                canExtendBase        = $false
                reservedSlots        = 0
            }
        )
        bannedAccounts      = @()
    }

    # Convert to PSCustomObject for consistent property access
    $serverConfigJson = $serverConfig | ConvertTo-Json -Depth 10
    $serverConfig = $serverConfigJson | ConvertFrom-Json
}

# Apply settings from management config (only fields that exist in the real schema)
Write-Host "Applying settings from management configuration..." -ForegroundColor Yellow

$serverConfig.name = $config.Server.Name
$serverConfig.slotCount = $config.Server.SlotCount
$serverConfig.queryPort = $config.Server.QueryPort

Write-ServerLog "Applied settings: Name='$($serverConfig.name)', Slots=$($serverConfig.slotCount), QueryPort=$($serverConfig.queryPort)" -Level INFO

# --- Password setup for user groups ---
if ($isNewConfig -or $ResetPasswords) {
    if ($isNewConfig) {
        Write-Host "`n========================================" -ForegroundColor Yellow
        Write-Host "  User Group Password Setup" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "Each user group requires a password for players to join." -ForegroundColor Gray
        Write-Host "You can type a password or press Enter to auto-generate one." -ForegroundColor Gray
    } else {
        Write-Host "`n========================================" -ForegroundColor Yellow
        Write-Host "  Reset User Group Passwords" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
    }

    $passwordSummary = @()

    foreach ($group in $serverConfig.userGroups) {
        $pw = Get-UserGroupPassword -GroupName $group.name
        $group.password = $pw
        $passwordSummary += [PSCustomObject]@{ Group = $group.name; Password = $pw }
    }

    # Display password summary — user must save these
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  IMPORTANT: Save These Passwords!" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "Players will need these passwords to join your server." -ForegroundColor White
    Write-Host "Copy and store them in a safe place NOW.`n" -ForegroundColor White

    foreach ($entry in $passwordSummary) {
        Write-Host "  $($entry.Group): $($entry.Password)" -ForegroundColor Cyan
    }

    Write-Host "`n========================================`n" -ForegroundColor Magenta
    Write-ServerLog "User group passwords configured for groups: $($passwordSummary.Group -join ', ')" -Level SUCCESS

    Write-Host "Press Enter after you have saved the passwords..." -ForegroundColor Yellow
    Read-Host
}

# Write configuration back to disk
try {
    $serverConfig | ConvertTo-Json -Depth 10 | Set-Content $serverConfigPath -Encoding UTF8
    Write-ServerLog "Server configuration saved to: $serverConfigPath" -Level SUCCESS
    Write-Host "[OK] Server configuration saved successfully." -ForegroundColor Green
} catch {
    Write-ServerLog "Failed to save server configuration: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to save server configuration." -ForegroundColor Red
    exit 1
}

# Display active configuration
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Active Server Configuration" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Server Name:     $($serverConfig.name)" -ForegroundColor White
Write-Host "Max Players:     $($serverConfig.slotCount)" -ForegroundColor White
Write-Host "Query Port:      $($serverConfig.queryPort) UDP" -ForegroundColor White
Write-Host "Bind IP:         $($serverConfig.ip)" -ForegroundColor White
Write-Host "Save Directory:  $($serverConfig.saveDirectory)" -ForegroundColor White
Write-Host "Log Directory:   $($serverConfig.logDirectory)" -ForegroundColor White
Write-Host "Voice Chat:      $(if ($serverConfig.enableVoiceChat) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
Write-Host "Text Chat:       $(if ($serverConfig.enableTextChat) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
Write-Host "User Groups:     $($serverConfig.userGroups.Count) configured" -ForegroundColor White

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Configuration Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-ServerLog "Server configuration completed successfully." -Level SUCCESS

Write-Host "Configuration File: $serverConfigPath" -ForegroundColor Yellow

if (Test-ServerProcess) {
    Write-Host "`n[INFO] Server is currently running." -ForegroundColor Yellow
    Write-Host "Restart the server for changes to take effect:" -ForegroundColor Yellow
    Write-Host "  .\10-Stop-Server.ps1" -ForegroundColor Gray
    Write-Host "  .\9-Start-Server.ps1" -ForegroundColor Gray
} else {
    Write-Host "`nNext Step: Run 9-Start-Server.ps1 to start the server." -ForegroundColor Yellow
}

Write-Host "`n" -NoNewline

exit 0
