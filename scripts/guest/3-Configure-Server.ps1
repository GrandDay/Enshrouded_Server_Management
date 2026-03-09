<#
.SYNOPSIS
    Configures Enshrouded server settings.

.DESCRIPTION
    Reads settings from the management configuration file and applies them to
    the Enshrouded server configuration file (enshrouded_server.json).
    
    If no server config exists, the script launches the server executable
    briefly to let it generate a valid default configuration, then stops
    the server. This ensures the config file always uses the server's native
    JSON format, which PowerShell's ConvertTo-Json cannot reproduce exactly.
    
    After applying name, slot count, and query port from the management config
    via targeted text replacement, the script opens the server config in
    Notepad for the user to customize passwords, game settings, and other
    options.

.EXAMPLE
    .\3-Configure-Server.ps1
    Applies configuration from EnshroudedServerConfig.json to server.

.NOTES
    File Name  : 3-Configure-Server.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 3.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

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
$serverExe = Join-Path $config.Paths.ServerInstall "enshrouded_server.exe"

Write-Host "Management Config: C:\EnshroudedServer\EnshroudedServerConfig.json" -ForegroundColor Gray
Write-Host "Server Config:     $serverConfigPath`n" -ForegroundColor Gray

# ---------------------------------------------------------------
#  Step 1: Ensure enshrouded_server.json exists (seed if needed)
# ---------------------------------------------------------------
if (-not (Test-Path $serverConfigPath)) {
    Write-Host "No server configuration found. The server will be started" -ForegroundColor Yellow
    Write-Host "briefly to generate its default configuration file.`n" -ForegroundColor Yellow

    if (-not (Test-Path $serverExe)) {
        Write-ServerLog "Server executable not found: $serverExe" -Level ERROR
        Write-Host "[FAIL] Server executable not found: $serverExe" -ForegroundColor Red
        Write-Host "       Run 2-Download-Server.ps1 first." -ForegroundColor Gray
        exit 1
    }

    Write-Host "Launching server to generate default config..." -ForegroundColor Yellow
    Write-ServerLog "Launching server briefly to seed enshrouded_server.json." -Level INFO

    try {
        $seedProc = Start-Process -FilePath $serverExe `
            -WorkingDirectory $config.Paths.ServerInstall `
            -PassThru -ErrorAction Stop

        # Poll for the config file, up to 90 seconds
        $waited = 0
        $maxWait = 90
        while ($waited -lt $maxWait) {
            Start-Sleep -Seconds 5
            $waited += 5
            Write-Host "  Waiting for config generation... ($waited/$maxWait sec)" -ForegroundColor Gray

            if (Test-Path $serverConfigPath) {
                Write-Host "  [OK] Config file detected!" -ForegroundColor Green
                break
            }

            # If the process exited early, check if it created the file at exit
            if ($seedProc.HasExited) {
                if (Test-Path $serverConfigPath) {
                    Write-Host "  [OK] Config file detected!" -ForegroundColor Green
                }
                break
            }
        }

        # Stop the seeding process
        if (-not $seedProc.HasExited) {
            Write-Host "  Stopping seed server process..." -ForegroundColor Gray
            Stop-Process -Id $seedProc.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }

        if (-not (Test-Path $serverConfigPath)) {
            Write-ServerLog "Server did not generate config file within $maxWait seconds." -Level ERROR
            Write-Host "[FAIL] Server did not create enshrouded_server.json." -ForegroundColor Red
            Write-Host "       Try running the server manually to diagnose:" -ForegroundColor Gray
            Write-Host "       cd $($config.Paths.ServerInstall)" -ForegroundColor Gray
            Write-Host "       .\enshrouded_server.exe" -ForegroundColor Gray
            exit 1
        }

        Write-ServerLog "Server seeded config file successfully." -Level SUCCESS
    } catch {
        Write-ServerLog "Failed to launch server for config seeding: $($_.Exception.Message)" -Level ERROR
        Write-Host "[FAIL] Could not start server to generate config." -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------
#  Step 2: Apply management settings via text replacement
# ---------------------------------------------------------------
Write-Host "Loading server configuration..." -ForegroundColor Yellow

try {
    $rawJson = Get-Content $serverConfigPath -Raw -ErrorAction Stop
    Write-ServerLog "Loaded existing server configuration." -Level INFO
} catch {
    Write-ServerLog "Failed to read server config: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to read server configuration file." -ForegroundColor Red
    exit 1
}

Write-Host "Applying settings from management configuration..." -ForegroundColor Yellow

$newName = $config.Server.Name
$newSlots = $config.Server.SlotCount
$newQueryPort = $config.Server.QueryPort

# Replace "name" value — matches the first occurrence of "name": "..."
$rawJson = $rawJson -replace '("name":\s*)"[^"]*"', "`$1`"$newName`""

# Replace slotCount value — matches "slotCount": <number>
$rawJson = $rawJson -replace '("slotCount":\s*)\d+', "`${1}$newSlots"

# Replace queryPort value — matches "queryPort": <number>
$rawJson = $rawJson -replace '("queryPort":\s*)\d+', "`${1}$newQueryPort"

Write-ServerLog "Applied settings: Name='$newName', Slots=$newSlots, QueryPort=$newQueryPort" -Level INFO

# Write the modified config back, preserving the server's native formatting
try {
    [System.IO.File]::WriteAllText($serverConfigPath, $rawJson, [System.Text.Encoding]::UTF8)
    Write-ServerLog "Server configuration saved to: $serverConfigPath" -Level SUCCESS
    Write-Host "[OK] Server configuration updated successfully.`n" -ForegroundColor Green
} catch {
    Write-ServerLog "Failed to save server configuration: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to save server configuration." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------
#  Step 3: Display applied settings
# ---------------------------------------------------------------
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Applied Configuration" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "  Server Name:   $newName" -ForegroundColor White
Write-Host "  Max Players:   $newSlots" -ForegroundColor White
Write-Host "  Query Port:    $newQueryPort UDP" -ForegroundColor White

# ---------------------------------------------------------------
#  Step 4: Prompt user to customize passwords & game settings
# ---------------------------------------------------------------
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  Manual Configuration Required" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "`nThe server configuration file will now open in Notepad." -ForegroundColor White
Write-Host "Please review and customize the following settings:`n" -ForegroundColor White
Write-Host "  1. User Group Passwords  (userGroups -> password)" -ForegroundColor Cyan
Write-Host "     Set unique passwords for Admin, Friend, Guest, Visitor groups." -ForegroundColor Gray
Write-Host "     Players use these passwords to join with specific permissions.`n" -ForegroundColor Gray
Write-Host "  2. Game Settings          (gameSettings section)" -ForegroundColor Cyan
Write-Host "     Adjust difficulty, day/night duration, mining speed, etc.`n" -ForegroundColor Gray
Write-Host "  3. Voice / Text Chat      (enableVoiceChat, enableTextChat)" -ForegroundColor Cyan
Write-Host "     Enable or disable communication features.`n" -ForegroundColor Gray
Write-Host "Save the file and close Notepad when finished." -ForegroundColor White

Write-Host "`nPress Enter to open the configuration file..." -ForegroundColor Yellow
Read-Host

# Open in notepad and wait for the user to close it
Write-ServerLog "Opening server config in notepad for user customization." -Level INFO
$notepadProc = Start-Process -FilePath "notepad.exe" -ArgumentList $serverConfigPath -PassThru
$notepadProc.WaitForExit()
Write-ServerLog "User closed notepad. Verifying configuration..." -Level INFO

# ---------------------------------------------------------------
#  Step 5: Validate the edited config
# ---------------------------------------------------------------
Write-Host "`nValidating configuration file..." -ForegroundColor Yellow

try {
    $null = Get-Content $serverConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
    Write-Host "[OK] Configuration is valid JSON." -ForegroundColor Green
    Write-ServerLog "Server configuration validated successfully." -Level SUCCESS
} catch {
    Write-ServerLog "Server config has invalid JSON after editing: $($_.Exception.Message)" -Level ERROR
    Write-Host "[WARN] Configuration file has invalid JSON syntax!" -ForegroundColor Red
    Write-Host "       Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n       The server may fail to start with this config." -ForegroundColor Red
    Write-Host "       You can re-run this script or manually fix:" -ForegroundColor Yellow
    Write-Host "       notepad $serverConfigPath" -ForegroundColor Gray
}

# ---------------------------------------------------------------
#  Done
# ---------------------------------------------------------------
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
