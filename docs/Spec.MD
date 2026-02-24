# PowerShell Workflow Spec — Enshrouded Dedicated Server (Windows 11 Pro / Hyper-V)

## Overview

This specification defines a **repeatable, end-to-end PowerShell workflow** for standing up, managing, and maintaining a dedicated Enshrouded game server inside a **Windows 11 Pro VM running on Hyper-V**. It adapts the existing Ubuntu Server workflow (bash + systemd + Wine) documented in the CUE-Verse lab environment into native PowerShell commands and scripts.

> **Enshrouded Steam App ID:** `2278520`  
> **Default Ports:** `15636` (game), `15637` (query)  
> **Target VM:** Clean Windows 11 Pro (Hyper-V guest)  
> **Reference model:** Ubuntu dedicated server setup using SteamCMD, Wine, and systemd service units

### Referenced Material

- Running a dedicated server for Enshrouded on Ubuntu — Primary bash/systemd/Wine workflow reference
- SteamCMD - Valve Developer Community — SteamCMD docs, SteamPS and PowerShellGSM PowerShell modules
- CUE-Verse Wide state SSOT — `min-enshrouded` VM 107 (ubuntu-server on pve-white-dell)
- Aeon Desktop and Linux User-space — Scripts Library, Systems Inventory, Articles & References databases

---

## Architecture Decisions

### Code Organization

- **Structure:** Standalone PowerShell scripts (not a module)
- **Rationale:** Simpler execution model, easier to understand workflow, better for educational/demonstration purposes
- **Location:** Scripts organized into `scripts/guest/` and `scripts/host/` directories

### Host/Guest Separation

- **Guest Scripts:** Run inside Windows 11 Pro VM, manage server installation and operations
- **Host Scripts:** Run on Hyper-V host, manage VM-level operations (checkpoints, hibernation)
- **Mechanism:** Manual execution — user runs host scripts separately on the host machine
- **Rationale:** Avoids PowerShell Remoting complexity, clearer separation of concerns

### Configuration Management

- **Approach:** Centralized JSON configuration file
- **Location:** `C:\EnshroudedServer\EnshroudedServerConfig.json` (on guest VM)
- **Template:** Provided in repository at `config/EnshroudedServerConfig.json`
- **Rationale:** Single source of truth, version controllable, eliminates parameter passing

### Logging & Error Handling

- **Approach:** File-based logging with structured format
- **Location:** `C:\EnshroudedServer\ManagementLogs\YYYY-MM-DD.log`
- **Format:** `[TIMESTAMP] [SCRIPT] [LEVEL] Message`
- **Levels:** INFO, WARN, ERROR, SUCCESS
- **Rationale:** Persistent audit trail, separate from game server logs, troubleshooting aid

### Auto-Start Behavior

- **Mechanism:** Windows Scheduled Task
- **Trigger:** System startup with 30-second delay
- **Action:** Launch `enshrouded_server.exe`
- **Rationale:** Native Windows solution, simple setup, appropriate for game server use case

### PowerShell Version

- **Target:** PowerShell 5.1
- **Rationale:** Built into Windows 11 Pro, no external dependencies, sufficient for all requirements

### Testing Strategy

- **Framework:** Pester
- **Coverage:** Configuration validation, script syntax, functional/integration tests
- **Location:** `tests/` directory
- **Rationale:** Validates critical functionality, ensures script quality

---

## Directory Structure

```
l:\5-0-summative-enshrouded-pshell\
├── scripts/
│   ├── guest/                           # Scripts run inside VM
│   │   ├── Common-Functions.ps1         # Shared logging and utilities
│   │   ├── 0-Initial-Setup.ps1          # Master setup script
│   │   ├── 1-Install-Dependencies.ps1   # Install SteamCMD and prerequisites
│   │   ├── 2-Download-Server.ps1        # Download Enshrouded server via SteamCMD
│   │   ├── 3-Configure-Server.ps1       # Apply server configuration
│   │   ├── 4-Health-Check.ps1           # Validate server health
│   │   ├── 5-Update-Server.ps1          # Restart and update server
│   │   ├── 6-Setup-Alias.ps1            # Configure PowerShell profile alias
│   │   ├── 7-Backup-GameFiles.ps1       # Backup game files to zip
│   │   ├── 8-Setup-ScheduledTask.ps1    # Configure auto-start scheduled task
│   │   ├── 9-Start-Server.ps1           # Start server process
│   │   └── 10-Stop-Server.ps1           # Stop server process gracefully
│   └── host/                            # Scripts run on Hyper-V host
│       ├── Backup-VMCheckpoint.ps1      # Create Hyper-V checkpoint
│       └── Hibernate-VM.ps1             # Save VM state (hibernate)
├── config/
│   └── EnshroudedServerConfig.json      # Configuration template
├── tests/
│   ├── Config.Tests.ps1                 # Configuration validation tests
│   ├── Scripts.Tests.ps1                # Script syntax and quality tests
│   └── Functional.Tests.ps1             # Functional and integration tests
├── docs/
│   └── Spec.MD                          # This specification document
├── .gitignore                           # Git ignore patterns
└── README.MD                            # User documentation and quick start guide
```

---

## Configuration Schema

**File:** `C:\EnshroudedServer\EnshroudedServerConfig.json`

```json
{
  "Paths": {
    "SteamCMD": "C:\\SteamCMD",
    "ServerInstall": "C:\\EnshroudedServer",
    "Backup": "C:\\EnshroudedServer\\Backups",
    "ManagementLogs": "C:\\EnshroudedServer\\ManagementLogs"
  },
  "VM": {
    "Name": "Enshrouded-Server",
    "HostPowerShellRemotingEnabled": false
  },
  "Server": {
    "Name": "CUE-Verse Enshrouded",
    "Password": "",
    "SlotCount": 4,
    "GamePort": 15636,
    "QueryPort": 15637
  },
  "Backup": {
    "RetentionCount": 5
  },
  "Logging": {
    "Enabled": true,
    "Level": "INFO"
  }
}
```

---

## Prompt Sequence & Workflow Steps

### Prompt 0 — Initial Setup (Automated)

**Script:** `0-Initial-Setup.ps1`

**Purpose:** Master script that automates the complete first-time setup by running scripts 1-3 in sequence.

**What the script does:**

1. Copy configuration template from repository to `C:\EnshroudedServer\EnshroudedServerConfig.json`
2. Display configuration and prompt user to review/edit (or accept defaults)
3. Execute script 1 (Install Dependencies)
4. Execute script 2 (Download Server)
5. Execute script 3 (Configure Server)
6. Display setup completion summary
7. Advise user to run script 8 (Setup Scheduled Task) for auto-start

**Usage:**

```powershell
.\scripts\guest\0-Initial-Setup.ps1
```

**Frequency:** Once per VM — initial deployment only.

---

### Prompt 1 — Install Dependencies & SteamCMD on a Clean Windows 11 Pro VM

**Script:** `1-Install-Dependencies.ps1`

**Purpose:** Bootstrap a fresh VM with everything needed to host a dedicated server.

**What the script does:**

1. Read configuration from `EnshroudedServerConfig.json`
2. Create working directory structure (`C:\SteamCMD`, `C:\EnshroudedServer`, `C:\EnshroudedServer\Backups`, `C:\EnshroudedServer\ManagementLogs`)
3. Download the SteamCMD Windows installer archive from Valve CDN
4. Extract SteamCMD to configured directory
5. Check for and install **Visual C++ Redistributable** if not present (required by SteamCMD and Enshrouded)
6. Configure Windows Firewall rules to allow inbound UDP on ports **15636** and **15637**
7. Log all operations with error handling

**Key PowerShell commands:**

```powershell
# Load configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

# Create directory structure
$Config.Paths.PSObject.Properties | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_.Value | Out-Null
}

# Download and extract SteamCMD
$steamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
$tempZip = Join-Path $env:TEMP "steamcmd.zip"
Invoke-WebRequest -Uri $steamCmdUrl -OutFile $tempZip -UseBasicParsing
Expand-Archive -Path $tempZip -DestinationPath $Config.Paths.SteamCMD -Force

# Firewall rules
New-NetFirewallRule -DisplayName "Enshrouded Game Port" -Direction Inbound `
    -Protocol UDP -LocalPort 15636 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Enshrouded Query Port" -Direction Inbound `
    -Protocol UDP -LocalPort 15637 -Action Allow -ErrorAction SilentlyContinue
```

**Frequency:** One-time setup per VM. Re-run only if rebuilding the VM from scratch.

**Example occurrence:** Provisioning a new Hyper-V guest for game server hosting.

---

### Prompt 2 — Download / Install the Enshrouded Dedicated Server via SteamCMD

**Script:** `2-Download-Server.ps1`

**Purpose:** Pull the dedicated server files from Steam using SteamCMD (anonymous login).

**What the script does:**

1. Read configuration for paths
2. Run SteamCMD with `+force_install_dir`, `+login anonymous`, `+app_update 2278520 validate`, `+quit`
3. Validate that `enshrouded_server.exe` exists in the install directory after completion
4. Report installed build version if available
5. Log operation with timestamps

**Key PowerShell commands:**

```powershell
# Load configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

# Install / update Enshrouded dedicated server
$SteamCMD = Join-Path $Config.Paths.SteamCMD "steamcmd.exe"
$InstallDir = $Config.Paths.ServerInstall

$arguments = @(
    "+force_install_dir `"$InstallDir`"",
    "+login anonymous",
    "+app_update 2278520 validate",
    "+quit"
)

Start-Process -FilePath $SteamCMD -ArgumentList $arguments -Wait -NoNewWindow

# Validate installation
$serverExe = Join-Path $InstallDir "enshrouded_server.exe"
if (Test-Path $serverExe) {
    Write-Host "[OK] Enshrouded server installed successfully." -ForegroundColor Green
    $version = (Get-Item $serverExe).VersionInfo.FileVersion
    Write-Host "     Version: $version" -ForegroundColor Cyan
} else {
    Write-Error "[FAIL] enshrouded_server.exe not found. Check SteamCMD output."
}
```

**Frequency:** Once on initial deploy. Also called by the update script (Script 5).

**Example occurrence:** First-time server setup, or restoring a server after a VM rebuild.

---

### Prompt 3 — Apply Server Configuration (enshrouded_server.json)

**Script:** `3-Configure-Server.ps1`

**Purpose:** Programmatically set server name, password, player slot count, and other settings in the Enshrouded config file — replacing the manual edit step.

**What the script does:**

1. Read management configuration from `EnshroudedServerConfig.json`
2. Read or create `enshrouded_server.json` in the server install directory
3. Update server settings: name, password, slotCount, gamePort, queryPort
4. Write the updated JSON back to disk with UTF-8 encoding
5. Display the active configuration for verification
6. Log configuration changes

**Key PowerShell commands:**

```powershell
# Load management configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

# Server config file path
$ServerConfigPath = Join-Path $Config.Paths.ServerInstall "enshrouded_server.json"

# Load or create server config
if (Test-Path $ServerConfigPath) {
    $ServerConfig = Get-Content $ServerConfigPath -Raw | ConvertFrom-Json
} else {
    $ServerConfig = [PSCustomObject]@{
        name = ""
        password = ""
        slotCount = 4
        gamePort = 15636
        queryPort = 15637
    }
}

# Apply settings from management config
$ServerConfig.name = $Config.Server.Name
$ServerConfig.password = $Config.Server.Password
$ServerConfig.slotCount = $Config.Server.SlotCount
$ServerConfig.gamePort = $Config.Server.GamePort
$ServerConfig.queryPort = $Config.Server.QueryPort

# Write back to disk
$ServerConfig | ConvertTo-Json -Depth 10 | Set-Content $ServerConfigPath -Encoding UTF8

Write-Host "[OK] Server config updated:" -ForegroundColor Green
Write-Host "     Name: $($ServerConfig.name)" -ForegroundColor Cyan
Write-Host "     Slots: $($ServerConfig.slotCount)" -ForegroundColor Cyan
Write-Host "     Ports: $($ServerConfig.gamePort) (game), $($ServerConfig.queryPort) (query)" -ForegroundColor Cyan
```

**Frequency:** On initial setup and whenever server settings need to change.

**Example occurrence:** Changing the server password before a new play session, or increasing slot count.

---

### Prompt 4 — Health Check: Process Validation, Port Check, Log Tail

**Script:** `4-Health-Check.ps1`

**Purpose:** Verify the Enshrouded server is running correctly — analogous to `systemctl status` and `journalctl` in the Ubuntu/systemd model.

**What the script does:**

1. Check if `enshrouded_server` process is running (`Get-Process`)
2. Verify listening UDP ports 15636/15637 (`Get-NetUDPEndpoint`)
3. Display process resource usage (CPU time, memory, uptime)
4. Tail the most recent server log entries (last 30 lines)
5. Return a pass/fail summary with color-coded output
6. Log health check results

**Key PowerShell commands:**

```powershell
# Load configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

Write-Host "`n=== Enshrouded Server Health Check ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# 1. Process check
$proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if ($proc) {
    $uptime = (Get-Date) - $proc.StartTime
    $cpuTime = $proc.TotalProcessorTime
    $memoryMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
    
    Write-Host "`n[OK] Server process running" -ForegroundColor Green
    Write-Host "     PID: $($proc.Id)" -ForegroundColor Gray
    Write-Host "     CPU Time: $cpuTime" -ForegroundColor Gray
    Write-Host "     Memory: $memoryMB MB" -ForegroundColor Gray
    Write-Host "     Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m" -ForegroundColor Gray
} else {
    Write-Host "`n[FAIL] Server process NOT found." -ForegroundColor Red
}

# 2. Port check
$ports = @($Config.Server.GamePort, $Config.Server.QueryPort)
Write-Host "`n--- Port Status ---" -ForegroundColor Cyan
foreach ($port in $ports) {
    $ep = Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue
    if ($ep) { 
        Write-Host "[OK] UDP port $port is listening." -ForegroundColor Green 
    } else { 
        Write-Host "[WARN] UDP port $port not detected." -ForegroundColor Yellow 
    }
}

# 3. Log tail (last 30 lines of most recent log)
$logDir = Join-Path $Config.Paths.ServerInstall "logs"
if (Test-Path $logDir) {
    $latestLog = Get-ChildItem $logDir -Filter *.log -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($latestLog) {
        Write-Host "`n--- Last 30 log lines ($($latestLog.Name)) ---" -ForegroundColor Cyan
        Get-Content $latestLog.FullName -Tail 30 | Write-Host -ForegroundColor Gray
    }
} else {
    Write-Host "`n[INFO] Log directory not found yet." -ForegroundColor Yellow
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
```

**Frequency:** Before and after every play session; after updates; during troubleshooting.

**Example occurrence:** Players report connection issues — run health check to confirm the server process is alive and ports are open.

---

### Prompt 5 — Restart / Update Script & PowerShell Alias

**Script:** `5-Update-Server.ps1`

**Purpose:** Stop the server, run a SteamCMD update pass, and restart the server with the latest version.

*This mirrors the Ubuntu model where `ExecStartPre` in the systemd unit runs `steamcmd +app_update` before `ExecStart` launches the server binary via Wine.*

**What the script does:**

1. Read configuration
2. Gracefully stop `enshrouded_server` process (if running)
3. Run SteamCMD `+app_update 2278520 validate` to pull any available update
4. Start `enshrouded_server.exe`
5. Wait 10 seconds for startup
6. Run the health check to confirm successful restart
7. Log entire operation sequence

**Key PowerShell commands:**

```powershell
# Load configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

$ServerExe = Join-Path $Config.Paths.ServerInstall "enshrouded_server.exe"
$SteamCMD = Join-Path $Config.Paths.SteamCMD "steamcmd.exe"

# 1. Stop server gracefully
$proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "[INFO] Stopping Enshrouded server (PID: $($proc.Id))..." -ForegroundColor Yellow
    Stop-Process -Id $proc.Id -Force
    Start-Sleep -Seconds 5
    Write-Host "[OK] Server stopped." -ForegroundColor Green
}

# 2. Run SteamCMD update
Write-Host "[INFO] Running SteamCMD update..." -ForegroundColor Cyan
$arguments = @(
    "+force_install_dir `"$($Config.Paths.ServerInstall)`"",
    "+login anonymous",
    "+app_update 2278520 validate",
    "+quit"
)
Start-Process -FilePath $SteamCMD -ArgumentList $arguments -Wait -NoNewWindow

# 3. Start server
Write-Host "[INFO] Starting Enshrouded server..." -ForegroundColor Cyan
Start-Process -FilePath $ServerExe -WorkingDirectory $Config.Paths.ServerInstall
Start-Sleep -Seconds 10

# 4. Quick health check
$verify = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if ($verify) {
    Write-Host "[OK] Server is running (PID: $($verify.Id))." -ForegroundColor Green
    Write-Host "[INFO] Run 4-Health-Check.ps1 for full validation." -ForegroundColor Cyan
} else {
    Write-Error "[FAIL] Server did not start. Check logs."
}
```

**Frequency:** Before every play session (ensures latest version); immediately when a patch is announced.

**Example occurrence:** Enshrouded releases a hotfix — run `Update-Enshrouded` alias to pull the patch and bring the server back up.

---

### Prompt 6 — Setup PowerShell Alias for Quick Updates

**Script:** `6-Setup-Alias.ps1`

**Purpose:** Register a PowerShell profile alias so the user can invoke the update script with a single command.

**What the script does:**

1. Determine the full path to `5-Update-Server.ps1`
2. Create PowerShell profile file if it doesn't exist
3. Add alias definition to profile: `Set-Alias -Name Update-Enshrouded -Value '<path>'`
4. Check for duplicates before adding
5. Optionally activate alias in current session
6. Display usage instructions

**Key PowerShell commands:**

```powershell
# Get script path
$ScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) "5-Update-Server.ps1"

# Alias definition
$AliasName = "Update-Enshrouded"
$AliasLine = "Set-Alias -Name $AliasName -Value '$ScriptPath'"

# Create profile if missing
if (!(Test-Path $PROFILE)) { 
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    Write-Host "[INFO] Created PowerShell profile: $PROFILE" -ForegroundColor Cyan
}

# Add alias if not already present
if (!(Select-String -Path $PROFILE -Pattern $AliasName -Quiet)) {
    Add-Content -Path $PROFILE -Value "`n# Enshrouded Server Management Alias"
    Add-Content -Path $PROFILE -Value $AliasLine
    Write-Host "[OK] Alias '$AliasName' added to profile." -ForegroundColor Green
} else {
    Write-Host "[INFO] Alias '$AliasName' already exists in profile." -ForegroundColor Yellow
}

# Activate in current session
Set-Alias -Name $AliasName -Value $ScriptPath
Write-Host "`n[OK] Alias active in current session." -ForegroundColor Green
Write-Host "     Usage: $AliasName" -ForegroundColor Cyan
Write-Host "     (Will be available in new sessions automatically)" -ForegroundColor Gray
```

**Frequency:** Once after initial setup.

**Example occurrence:** After running the initial setup script, run this to enable the convenient `Update-Enshrouded` shortcut.

---

### Prompt 7 — Backup: Game File Archive

**Script:** `7-Backup-GameFiles.ps1`

**Purpose:** Create a timestamped backup archive of the server installation directory, excluding logs and previous backups.

**What the script does:**

1. Read configuration for paths and retention count
2. Create timestamped zip file of `C:\EnshroudedServer` contents
3. Exclude: Backups directory, logs directory, ManagementLogs directory
4. Save backup zip to configured backup directory
5. Rotate old backups — keep the last N (from config)
6. Log backup file path, size, and duration

**Key PowerShell commands:**

```powershell
# Load configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$BackupFile = Join-Path $Config.Paths.Backup "enshrouded-backup-$Timestamp.zip"
$SourceDir = $Config.Paths.ServerInstall

Write-Host "[INFO] Starting game files backup..." -ForegroundColor Cyan

# Collect files to backup (exclude certain directories)
$excludeDirs = @(
    $Config.Paths.Backup,
    (Join-Path $SourceDir "logs"),
    $Config.Paths.ManagementLogs
)

$filesToBackup = Get-ChildItem $SourceDir -Recurse -File | Where-Object {
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

# Create backup archive
Compress-Archive -Path $filesToBackup.FullName -DestinationPath $BackupFile -CompressionLevel Optimal

$backupSize = (Get-Item $BackupFile).Length / 1MB
Write-Host "[OK] Backup created: $BackupFile" -ForegroundColor Green
Write-Host "     Size: $([math]::Round($backupSize, 2)) MB" -ForegroundColor Cyan

# Rotate backups — keep last N
$retentionCount = $Config.Backup.RetentionCount
$existingBackups = Get-ChildItem $Config.Paths.Backup -Filter "enshrouded-backup-*.zip" | 
    Sort-Object CreationTime -Descending

if ($existingBackups.Count -gt $retentionCount) {
    $toDelete = $existingBackups | Select-Object -Skip $retentionCount
    foreach ($old in $toDelete) {
        Remove-Item $old.FullName -Force
        Write-Host "[INFO] Removed old backup: $($old.Name)" -ForegroundColor Gray
    }
}

Write-Host "[OK] Backup rotation complete. Keeping last $retentionCount backups." -ForegroundColor Green
```

**Frequency:** Before every update; weekly as routine maintenance; before any major config change.

**Example occurrence:** About to apply a game update — create a backup first so files can be restored if the update causes issues.

---

### Prompt 8 — Setup Scheduled Task for Auto-Start

**Script:** `8-Setup-ScheduledTask.ps1`

**Purpose:** Configure Windows Scheduled Task to automatically start the Enshrouded server when the VM boots.

**What the script does:**

1. Read configuration for server paths
2. Create scheduled task named "Start Enshrouded Server"
3. Configure trigger: At system startup, delay 30 seconds
4. Configure action: Run `enshrouded_server.exe` from configured path
5. Set task to run with highest privileges, whether user is logged on or not
6. Register the task using `Register-ScheduledTask`
7. Log task creation and display status

**Key PowerShell commands:**

```powershell
# Load configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

$TaskName = "Start Enshrouded Server"
$ServerExe = Join-Path $Config.Paths.ServerInstall "enshrouded_server.exe"
$WorkingDir = $Config.Paths.ServerInstall

Write-Host "[INFO] Creating scheduled task: $TaskName" -ForegroundColor Cyan

# Define task action
$Action = New-ScheduledTaskAction -Execute $ServerExe -WorkingDirectory $WorkingDir

# Define task trigger (startup with delay)
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Trigger.Delay = "PT30S"  # 30-second delay

# Define task settings
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# Define task principal (run with highest privileges)
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
    -Settings $Settings -Principal $Principal -Force | Out-Null

Write-Host "[OK] Scheduled task created successfully." -ForegroundColor Green
Write-Host "     The server will start automatically 30 seconds after system boot." -ForegroundColor Cyan
Write-Host "     To disable: Disable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
```

**Frequency:** Once after initial setup (unless task needs reconfiguration).

**Example occurrence:** After setting up the server, run this to ensure it auto-starts on VM reboot.

---

### Prompt 9 — Start Server

**Script:** `9-Start-Server.ps1`

**Purpose:** Simple wrapper to manually start the Enshrouded server process.

**What the script does:**

1. Check if server is already running
2. If not running, start `enshrouded_server.exe` with proper working directory
3. Wait briefly for process initialization
4. Verify process started successfully
5. Log startup operation

**Key PowerShell commands:**

```powershell
# Load configuration
$Config = Get-Content "C:\EnshroudedServer\EnshroudedServerConfig.json" | ConvertFrom-Json

# Check if already running
$existing = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "[INFO] Server is already running (PID: $($existing.Id))." -ForegroundColor Yellow
    exit 0
}

# Start server
$ServerExe = Join-Path $Config.Paths.ServerInstall "enshrouded_server.exe"
Write-Host "[INFO] Starting Enshrouded server..." -ForegroundColor Cyan

Start-Process -FilePath $ServerExe -WorkingDirectory $Config.Paths.ServerInstall

# Wait and verify
Start-Sleep -Seconds 5
$proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "[OK] Server started successfully (PID: $($proc.Id))." -ForegroundColor Green
    Write-Host "     Run 4-Health-Check.ps1 for full validation." -ForegroundColor Cyan
} else {
    Write-Error "[FAIL] Server failed to start. Check logs."
}
```

**Frequency:** On-demand when server needs manual start.

**Example occurrence:** After stopping the server for maintenance, use this to restart it without updating.

---

### Prompt 10 — Stop Server

**Script:** `10-Stop-Server.ps1`

**Purpose:** Gracefully stop the Enshrouded server process.

**What the script does:**

1. Check if server process is running
2. If running, send stop signal with configurable timeout
3. Wait for process to terminate cleanly
4. Verify process has stopped
5. Log shutdown operation

**Key PowerShell commands:**

```powershell
# Configuration
$TimeoutSeconds = 30

# Check for running process
$proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Host "[INFO] Server is not running." -ForegroundColor Yellow
    exit 0
}

Write-Host "[INFO] Stopping Enshrouded server (PID: $($proc.Id))..." -ForegroundColor Cyan

# Request graceful shutdown
Stop-Process -Id $proc.Id -Force

# Wait for clean shutdown
$waited = 0
while ((Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue) -and ($waited -lt $TimeoutSeconds)) {
    Start-Sleep -Seconds 1
    $waited++
}

# Verify stopped
$stillRunning = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if ($stillRunning) {
    Write-Host "[WARN] Server did not stop within $TimeoutSeconds seconds. Force killing..." -ForegroundColor Yellow
    Stop-Process -Name "enshrouded_server" -Force
}

Write-Host "[OK] Server stopped successfully." -ForegroundColor Green
```

**Frequency:** Before updates, before backups, end of play sessions.

**Example occurrence:** About to run a server update — stop the server first to ensure clean update.

---

### Host Script 1 — Backup: Hyper-V Checkpoint

**Script:** `Backup-VMCheckpoint.ps1` (Run on Hyper-V **host**, not guest)

**Purpose:** Create a point-in-time Hyper-V checkpoint (snapshot) of the VM state.

> **Note:** This script runs on the **Hyper-V host**, not inside the guest VM. Use PowerShell on the host machine.

**What the script does:**

1. Accept VM name as parameter (or read from config if accessible)
2. Create a Hyper-V checkpoint with timestamped name
3. Verify checkpoint creation
4. Display checkpoint information

**Key PowerShell commands:**

```powershell
param(
    [Parameter(Mandatory=$false)]
    [string]$VMName = "Enshrouded-Server"
)

$Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$CheckpointName = "Enshrouded-Backup-$Timestamp"

Write-Host "[INFO] Creating Hyper-V checkpoint for VM: $VMName" -ForegroundColor Cyan
Write-Host "       Checkpoint name: $CheckpointName" -ForegroundColor Gray

try {
    Checkpoint-VM -Name $VMName -SnapshotName $CheckpointName -ErrorAction Stop
    Write-Host "[OK] Hyper-V checkpoint created successfully." -ForegroundColor Green
    
    # Display checkpoint info
    $checkpoint = Get-VMCheckpoint -VMName $VMName -Name $CheckpointName
    Write-Host "`nCheckpoint Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($checkpoint.Name)" -ForegroundColor Gray
    Write-Host "  Created: $($checkpoint.CreationTime)" -ForegroundColor Gray
    Write-Host "  Type: $($checkpoint.CheckpointType)" -ForegroundColor Gray
    
} catch {
    Write-Error "[FAIL] Failed to create checkpoint: $_"
    exit 1
}

Write-Host "`n[INFO] To restore: Restore-VMCheckpoint -VMName '$VMName' -Name '$CheckpointName' -Confirm:`$false" -ForegroundColor Yellow
```

**Frequency:** Before every game update; weekly as routine maintenance; before major configuration changes.

**Example occurrence:** About to install a server update — create checkpoint first so VM can be rolled back if update causes issues.

---

### Host Script 2 — Hibernate: Graceful Shutdown + VM State Save

**Script:** `Hibernate-VM.ps1` (Run on Hyper-V **host**, not guest)

**Purpose:** Save the VM state to free host resources when server is not in use.

> **Note:** This script runs on the **Hyper-V host**, not inside the guest VM. Optionally stop the server process inside the guest first.

**What the script does:**

1. Accept VM name as parameter
2. Optionally check if VM is running
3. Save VM state using `Save-VM` (preserves RAM to disk)
4. Verify VM state is saved
5. Display resource reclamation message
6. Provide resume instructions

**Key PowerShell commands:**

```powershell
param(
    [Parameter(Mandatory=$false)]
    [string]$VMName = "Enshrouded-Server"
)

Write-Host "[INFO] Hibernating VM: $VMName" -ForegroundColor Cyan

# Check VM state
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Error "[FAIL] VM '$VMName' not found."
    exit 1
}

if ($vm.State -ne "Running") {
    Write-Host "[INFO] VM is already stopped (State: $($vm.State))." -ForegroundColor Yellow
    exit 0
}

# Save VM state
try {
    Write-Host "[INFO] Saving VM state (this may take a moment)..." -ForegroundColor Cyan
    Save-VM -Name $VMName -ErrorAction Stop
    
    Write-Host "[OK] VM state saved successfully." -ForegroundColor Green
    Write-Host "     Host resources (CPU, RAM) are now freed." -ForegroundColor Green
    
} catch {
    Write-Error "[FAIL] Failed to save VM state: $_"
    exit 1
}

# Display resume instructions
Write-Host "`n=== To Resume ===" -ForegroundColor Cyan
Write-Host "1. Start VM:     Start-VM -Name '$VMName'" -ForegroundColor Gray
Write-Host "2. Wait for boot (VM will resume saved state)" -ForegroundColor Gray
Write-Host "3. Inside guest: .\9-Start-Server.ps1  (if server was stopped before hibernation)" -ForegroundColor Gray
```

**Frequency:** After every play session ends; when no players will be online for an extended period.

**Example occurrence:** Game night ends at 11 PM — hibernate the server to free host RAM and CPU until the next session.

---

## Common Functions — Shared Logging Utility

**Script:** `Common-Functions.ps1`

**Purpose:** Provide shared logging and utility functions used by all guest scripts.

**Functions:**

### Write-ServerLog

Structured logging function that writes to both console and log file.

```powershell
function Write-ServerLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory=$false)]
        [string]$ScriptName = (Split-Path -Leaf $PSCommandPath)
    )
    
    # Load configuration for log path
    $configPath = "C:\EnshroudedServer\EnshroudedServerConfig.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        $logDir = $config.Paths.ManagementLogs
    } else {
        $logDir = "C:\EnshroudedServer\ManagementLogs"
    }
    
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Log file: one per day
    $logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
    
    # Format: [TIMESTAMP] [SCRIPT] [LEVEL] Message
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$ScriptName] [$Level] $Message"
    
    # Write to file
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    
    # Write to console with color
    $color = switch ($Level) {
        'INFO'    { 'Cyan' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        'SUCCESS' { 'Green' }
        default   { 'White' }
    }
    
    Write-Host "[$Level] $Message" -ForegroundColor $color
}
```

**Usage in scripts:**

```powershell
# Dot-source the common functions at the top of each script
. (Join-Path (Split-Path -Parent $PSScriptRoot) "Common-Functions.ps1")

# Use throughout the script
Write-ServerLog "Starting server installation..." -Level INFO
Write-ServerLog "Server started successfully." -Level SUCCESS
Write-ServerLog "Port 15636 not responding." -Level WARN
Write-ServerLog "Failed to download SteamCMD: $($_.Exception.Message)" -Level ERROR
```

---

## Workflow Summary Table

| **Prompt** | **Script** | **Action** | **Scope** | **Frequency** |
|------------|------------|------------|-----------|---------------|
| 0 | `0-Initial-Setup.ps1` | Automated first-time setup | Guest VM | One-time |
| 1 | `1-Install-Dependencies.ps1` | Install SteamCMD + prerequisites | Guest VM | One-time |
| 2 | `2-Download-Server.ps1` | Download Enshrouded server | Guest VM | One-time (+ updates) |
| 3 | `3-Configure-Server.ps1` | Apply server configuration | Guest VM | On change |
| 4 | `4-Health-Check.ps1` | Validate server health | Guest VM | Every session |
| 5 | `5-Update-Server.ps1` | Restart and update server | Guest VM | Every session / on patch |
| 6 | `6-Setup-Alias.ps1` | Configure PowerShell alias | Guest VM | One-time |
| 7 | `7-Backup-GameFiles.ps1` | Backup game files to zip | Guest VM | Weekly / pre-update |
| 8 | `8-Setup-ScheduledTask.ps1` | Configure auto-start task | Guest VM | One-time |
| 9 | `9-Start-Server.ps1` | Start server process | Guest VM | On-demand |
| 10 | `10-Stop-Server.ps1` | Stop server process | Guest VM | Pre-update / end session |
| Host 1 | `Backup-VMCheckpoint.ps1` | Create Hyper-V checkpoint | Hyper-V Host | Weekly / pre-update |
| Host 2 | `Hibernate-VM.ps1` | Save VM state (hibernate) | Hyper-V Host | End of every session |

---

## Adaptation Notes (Ubuntu → Windows PowerShell)

| **Ubuntu / Bash Model** | **Windows / PowerShell Equivalent** |
|-------------------------|-------------------------------------|
| `apt install` • `dpkg --add-architecture` | `Invoke-WebRequest` • `Expand-Archive` (SteamCMD zip) |
| SteamCMD via shell script | `Start-Process steamcmd.exe -Wait` |
| Wine (`wine64 enshrouded_server.exe`) | Native `enshrouded_server.exe` (no translation layer needed) |
| `systemd` service unit (ExecStart/ExecStartPre) | `.ps1` script + Windows Scheduled Task |
| `systemctl start/stop/status` | `Start-Process` / `Stop-Process` / `Get-Process` |
| `journalctl -u enshrouded` | `Get-Content -Tail` on log files + structured management logs |
| `ufw allow` | `New-NetFirewallRule` |
| Proxmox snapshots (`qm snapshot`) | `Checkpoint-VM` (Hyper-V) |
| `systemctl stop` • VM shutdown | `Stop-Process` • `Save-VM` (Hyper-V state save) |
| `nano enshrouded_server.json` | `ConvertFrom-Json` / `ConvertTo-Json` / `Set-Content` |
| Bash script with functions | PowerShell script with dot-sourced common functions |
| `cron` for scheduled tasks | Windows Task Scheduler (`Register-ScheduledTask`) |
| `tar.gz` backups | `Compress-Archive` (.zip) |

---

## Troubleshooting

### Server won't start after installation

1. Run `4-Health-Check.ps1` to diagnose
2. Check firewall rules: `Get-NetFirewallRule | Where-Object {$_.DisplayName -like '*Enshrouded*'}`
3. Verify Visual C++ Redistributable installed: `Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like '*Visual C++*'}`
4. Check management logs in `C:\EnshroudedServer\ManagementLogs\`
5. Check server logs in `C:\EnshroudedServer\logs\`

### SteamCMD update fails

1. Check network connectivity
2. Verify `steamcmd.exe` exists in configured path
3. Try manual SteamCMD run: `.\steamcmd.exe +login anonymous +quit`
4. Check Steam service status (may be down for maintenance)

### Scheduled task doesn't auto-start server

1. Verify task exists: `Get-ScheduledTask -TaskName "Start Enshrouded Server"`
2. Check task history: `Get-ScheduledTaskInfo -TaskName "Start Enshrouded Server"`
3. Ensure task runs as SYSTEM with highest privileges
4. Manually trigger: `Start-ScheduledTask -TaskName "Start Enshrouded Server"`

### Health check shows ports not listening

1. Verify server process is actually running
2. Check for port conflicts: `Get-NetUDPEndpoint -LocalPort 15636, 15637`
3. Temporarily disable firewall for testing: `Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False`
4. Verify port configuration in `enshrouded_server.json` matches `EnshroudedServerConfig.json`

### Backup fails with access denied

1. Run PowerShell as Administrator
2. Verify backup directory exists and is writable
3. Check disk space: `Get-PSDrive C | Select-Object Used,Free`
4. Ensure no locks on files being backed up (stop server first)

### Host scripts can't find VM

1. Verify VM name matches configuration: `Get-VM | Select-Object Name`
2. Ensure Hyper-V PowerShell module loaded: `Import-Module Hyper-V`
3. Run host scripts with elevated privileges (Administrator)
4. Check Hyper-V service status: `Get-Service vmms`

---

## Testing Strategy

### Configuration Tests (`Config.Tests.ps1`)

- Validate JSON syntax and structure
- Verify all required keys present
- Validate path formats
- Validate port numbers in valid range (1-65535)
- Validate retention count is positive integer

### Script Quality Tests (`Scripts.Tests.ps1`)

- Validate PowerShell syntax (all scripts parse without errors)
- Check for comment-based help in all scripts
- Verify logging calls use `Write-ServerLog`
- Verify error handling with try/catch blocks
- Check for hardcoded paths (should use config)

### Functional Tests (`Functional.Tests.ps1`)

- Mock test: Installation creates required directories
- Mock test: Health check detects process correctly
- Mock test: Backup creates zip file with expected name format
- Mock test: Configuration updates JSON correctly
- Integration test markers (require actual server installation)

### Integration Testing (Manual)

1. Fresh Windows 11 Pro VM
2. Clone repository
3. Run `0-Initial-Setup.ps1`
4. Verify all directories created
5. Verify SteamCMD downloaded and extracted
6. Verify server files downloaded
7. Verify configuration applied
8. Start server with `9-Start-Server.ps1`
9. Run `4-Health-Check.ps1` — all checks green
10. Connect from game client
11. Run `7-Backup-GameFiles.ps1` — backup created
12. Run `5-Update-Server.ps1` — server restarts successfully
13. Run `10-Stop-Server.ps1` — server stops cleanly
14. On host: Run `Backup-VMCheckpoint.ps1` — checkpoint created
15. On host: Run `Hibernate-VM.ps1` — VM state saved
16. On host: `Start-VM` — VM resumes from saved state

---

## Future Enhancements (Out of Scope)

- **PowerShell Remoting:** Enable host scripts to invoke guest scripts remotely
- **Web Dashboard:** Real-time server status and control panel
- **Discord Integration:** Server status notifications via webhook
- **Automatic Updates:** Scheduled task to check for and apply updates
- **Player Whitelist Management:** Scripts to manage player access
- **Performance Monitoring:** Track server resource usage over time
- **Multi-Server Support:** Manage multiple Enshrouded instances on different VMs
- **Cloud Backup:** Sync backups to Azure Blob Storage or AWS S3
- **Configuration Profiles:** Switch between different server configurations (PvP, PvE, etc.)

---

## References

- **SteamCMD Documentation:** <https://developer.valvesoftware.com/wiki/SteamCMD>
- **Enshrouded Steam Page:** <https://store.steampowered.com/app/1203620/Enshrouded/>
- **Hyper-V PowerShell Module:** <https://docs.microsoft.com/en-us/powershell/module/hyper-v/>
- **Windows Task Scheduler:** <https://docs.microsoft.com/en-us/windows/win32/taskschd/>
- **Pester Testing Framework:** <https://pester.dev/>

---

## Document History

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-23 | 1.0 | Initial specification based on Ubuntu workflow adaptation |

---

*This specification serves as the authoritative reference for the Enshrouded Windows 11 Pro dedicated server PowerShell workflow. All implementation must adhere to the architecture decisions and guidelines outlined in this document.*
