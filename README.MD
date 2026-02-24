# Enshrouded Dedicated Server — Windows PowerShell Management

> **Summative Project:** Automated PowerShell workflow for managing an Enshrouded dedicated game server on Windows 11 Pro / Hyper-V

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20Pro-0078D6.svg)](https://www.microsoft.com/windows)
[![Hyper-V](https://img.shields.io/badge/Hypervisor-Hyper--V-00BCF2.svg)](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.MD)

A complete PowerShell automation suite that replaces manual server management with scripted workflows. Adapted from Ubuntu Server + Wine + systemd model to native Windows PowerShell 5.1.

> **🎓 Educational Project:** Originally developed as a summative lab project demonstrating PowerShell automation, Windows Server administration, and Infrastructure as Code concepts. Designed for learning environments and personal/hobby use.

> **⚠️ Important:** This project is provided for educational purposes. Review [SECURITY.MD](SECURITY.MD) before deploying. Ensure compliance with [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/) and Enshrouded's terms of service when hosting game servers.

---

## 📑 Table of Contents

- [Pre-Flight Checklist](#-pre-flight-checklist)
- [Quick Start](#-quick-start)
- [Quick Reference Card](#-quick-reference-card)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [Usage Guide](#-usage-guide)
- [Script Success Criteria](#-script-success-criteria)
- [Daily Operations Checklists](#-daily-operations-checklists)
- [Common Workflows](#-common-workflows)
- [Troubleshooting Decision Trees](#-troubleshooting-decision-trees)
- [Testing & Validation Guide](#-testing--validation-guide)
- [Script Reference](#-script-reference)
- [Security Considerations](#-security-considerations)
- [Requirements](#-requirements)
- [Known Limitations](#-known-limitations)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)

---

## ✅ Pre-Flight Checklist

Before running scripts, verify all prerequisites are met:

### 🟨 Host Machine Requirements

- [ ] **Windows 11 Pro** with Hyper-V enabled

  ```powershell
  # Verify Hyper-V is installed (run on host as Administrator)
  Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
  ```

- [ ] **Hyper-V VM created** with appropriate resources:
  - 16+ GB RAM allocated
  - 4+ CPU cores
  - 40+ GB virtual disk space
  - External or NAT network adapter configured
- [ ] **Network connectivity** from host to internet
- [ ] **Administrator privileges** on host machine

### 🟦 Guest VM Requirements

- [ ] **Fresh Windows 11 Pro installation** (build 22000 or later)

  ```powershell
  # Check Windows version (run inside guest VM)
  [System.Environment]::OSVersion.Version
  ```

- [ ] **Windows Updates completed**

  ```powershell
  # Detect and Install Windows Updates
  wuauclt.exe /detectnow /updatenow
  ```

- [ ] **PowerShell 5.1 available** (built into Windows 11)

  ```powershell
  # Verify PowerShell version
  $PSVersionTable.PSVersion  # Should show 5.1.x
  ```

- [ ] **Network connectivity** verified

  ```powershell
  # Test internet access
  Test-NetConnection google.com -InformationLevel Detailed
  ```

- [ ] **Disk space available** (20+ GB free)

  ```powershell
  # Check free space on C: drive
  Get-PSDrive C | Select-Object Used, Free
  ```

- [ ] **Administrator privileges** available

  ```powershell
  # Run PowerShell as Administrator (right-click > Run as Administrator)
  ```

### 📋 Pre-Installation Notes

**⚠️ Important:** This guide uses visual indicators:

- 🟦 = **Guest VM** (run INSIDE the virtual machine)
- 🟨 = **Host Machine** (run ON YOUR PC, not inside VM)

**⏱️ Time Estimate:** Complete installation takes **15-20 minutes**

- Configuration: 2 minutes
- Dependencies: 3-5 minutes
- Server download: **10-15 minutes** (2-3 GB download)
- Initial configuration: 1 minute

---

## 🎯 Quick Start

### Prerequisites

- **Host:** Windows 11 Pro with Hyper-V enabled
- **Guest VM:** Fresh Windows 11 Pro installation
- **PowerShell:** 5.1 (built-in, no installation needed)
- **Network:** VM configured with external network access
- **Disk Space:** Minimum 20 GB free space on guest VM

**✅ Complete the [Pre-Flight Checklist](#-pre-flight-checklist) before proceeding.**

### 🟦 Installation (15-20 Minutes)

1. **Clone the repository to the guest VM:** *(2 min)*

   ```powershell
   # Run inside guest VM as Administrator
   cd C:\
   git clone https://github.com/GrandDay/Enshrouded_Server_Management.git EnshroudedServerManagement
   cd EnshroudedServerManagement
   ```

2. **Copy configuration template:** *(1 min)*

   ```powershell
   Copy-Item .\config\EnshroudedServerConfig.json C:\EnshroudedServer\EnshroudedServerConfig.json
   ```

3. **Edit configuration (optional):** *(1 min)*

   ```powershell
   notepad C:\EnshroudedServer\EnshroudedServerConfig.json
   ```

   *(Defaults work for most setups - server name, password, player slots)*

4. **Run automated setup:** *(12-18 min - includes 2-3 GB download)*

   ```powershell
   # This installs SteamCMD, downloads server files, and configures everything
   .\scripts\guest\0-Initial-Setup.ps1
   ```

   **⏳ Wait time:** Server download takes 10-15 minutes on typical broadband.

5. **Verify installation:** *(2 min - REQUIRED)*

   ```powershell
   # Start the server for the first time
   .\scripts\guest\9-Start-Server.ps1
   Start-Sleep -Seconds 30  # Wait for initialization
   
   # Run health check (should show 3/3 checks PASS)
   .\scripts\guest\4-Health-Check.ps1
   ```

   **✅ Success Criteria:** All health checks show "[OK]" in green.
   **❌ If failed:** See [Script Success Criteria](#-script-success-criteria) section.

6. **Setup auto-start (optional):** *(1 min)*

   ```powershell
   .\scripts\guest\8-Setup-ScheduledTask.ps1
   ```

7. **Start playing:**

   ```powershell
   .\scripts\guest\9-Start-Server.ps1
   .\scripts\guest\4-Health-Check.ps1
   ```

🎮 **Server is now running!** Connect from your Enshrouded game client using the VM's IP address.

---

## 📁 Project Structure

```
l:\5-0-summative-enshrouded-pshell\
├── scripts/
│   ├── guest/              # Run these inside the Windows 11 Pro VM
│   │   ├── Common-Functions.ps1
│   │   ├── 0-Initial-Setup.ps1
│   │   ├── 1-Install-Dependencies.ps1
│   │   ├── 2-Download-Server.ps1
│   │   ├── 3-Configure-Server.ps1
│   │   ├── 4-Health-Check.ps1
│   │   ├── 5-Update-Server.ps1
│   │   ├── 6-Setup-Alias.ps1
│   │   ├── 7-Backup-GameFiles.ps1
│   │   ├── 8-Setup-ScheduledTask.ps1
│   │   ├── 9-Start-Server.ps1
│   │   └── 10-Stop-Server.ps1
│   └── host/               # Run these on the Hyper-V host machine
│       ├── Backup-VMCheckpoint.ps1
│       └── Hibernate-VM.ps1
├── config/
│   └── EnshroudedServerConfig.json
├── tests/
│   ├── Config.Tests.ps1
│   ├── Scripts.Tests.ps1
│   └── Functional.Tests.ps1
├── docs/
│   └── Spec.MD             # Complete technical specification
└── README.MD               # This file
```

---

## ⚙️ Configuration

### Configuration File: `C:\EnshroudedServer\EnshroudedServerConfig.json`

All scripts read settings from this central configuration file.

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

### Key Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `Server.Name` | CUE-Verse Enshrouded | Server name visible in browser |
| `Server.Password` | *(empty)* | Leave empty for public, set for private |
| `Server.SlotCount` | 4 | Maximum players (4-16 typical) |
| `Server.GamePort` | 15636 | UDP port for game traffic |
| `Server.QueryPort` | 15637 | UDP port for server queries |
| `Backup.RetentionCount` | 5 | Number of backup archives to keep |
| `VM.Name` | Enshrouded-Server | Hyper-V VM name (for host scripts) |

**Note:** After changing configuration, run `3-Configure-Server.ps1` to apply server settings and restart the server for changes to take effect.

---

## 📖 Usage Guide

### 🟦 Guest VM Operations (Run inside the VM)

#### First-Time Setup

```powershell
# 1. Automated setup (runs scripts 1, 2, 3 automatically)
.\scripts\guest\0-Initial-Setup.ps1

# 2. Setup auto-start on boot
.\scripts\guest\8-Setup-ScheduledTask.ps1

# 3. Setup convenience alias for updates
.\scripts\guest\6-Setup-Alias.ps1
```

#### Daily Operations

```powershell
# Start server
.\scripts\guest\9-Start-Server.ps1

# Check server health (process, ports, logs)
.\scripts\guest\4-Health-Check.ps1

# Stop server
.\scripts\guest\10-Stop-Server.ps1

# Update server and restart
.\scripts\guest\5-Update-Server.ps1
# Or with alias (after running 6-Setup-Alias.ps1):
Update-Enshrouded
```

#### Maintenance

```powershell
# Backup game files
.\scripts\guest\7-Backup-GameFiles.ps1

# Update server configuration
notepad C:\EnshroudedServer\EnshroudedServerConfig.json
.\scripts\guest\3-Configure-Server.ps1

# View management logs
Get-Content C:\EnshroudedServer\ManagementLogs\$(Get-Date -Format 'yyyy-MM-dd').log -Tail 50

# View server logs
Get-ChildItem C:\EnshroudedServer\logs | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50
```

### 🟨 Host Operations (Run on Hyper-V host)

**\u26a0\ufe0f Run these on your PC, NOT inside the guest VM.**

```powershell
# Create VM checkpoint before major changes
.\scripts\host\Backup-VMCheckpoint.ps1 -VMName "Enshrouded-Server"

# Hibernate VM (save state and free resources)
.\scripts\host\Hibernate-VM.ps1 -VMName "Enshrouded-Server"

# Resume from hibernation
Start-VM -Name "Enshrouded-Server"
# Wait for VM to boot, then inside guest:
.\scripts\guest\9-Start-Server.ps1
```

---

## � Script Success Criteria

Use these success indicators to verify each script executed correctly.

### ✅ 0-Initial-Setup.ps1 — Automated First-Time Setup

**What It Does:** Orchestrates complete installation (runs scripts 1, 2, and 3 automatically).

**Success Looks Like:**

```
[OK] Configuration deployed successfully.
[OK] Dependencies installed successfully!
[OK] Server downloaded and verified successfully!
[OK] Server configured successfully!

Next Steps:
  1. Start server:      .\scripts\guest\9-Start-Server.ps1
  ...
```

**Verification Commands:**

```powershell
# Verify server executable exists and is correct size
Get-Item C:\EnshroudedServer\enshrouded_server.exe | Select-Object Length, LastWriteTime
# Length should be ~500+ MB

# Verify configuration deployed
Test-Path C:\EnshroudedServer\EnshroudedServerConfig.json

# Verify SteamCMD installed
Test-Path C:\SteamCMD\steamcmd.exe
```

**Failure Indicators:**

- ❌ `[FAIL]` messages in red
- ❌ Missing `enshrouded_server.exe` file
- ❌ SteamCMD errors about network or disk space
- ❌ VC++ Redistributable installation failed

**If Failed:** Check management logs at `C:\EnshroudedServer\ManagementLogs\<date>.log`

---

### ✅ 9-Start-Server.ps1 — Start Server Process

**What It Does:** Launches the Enshrouded server as a background process.

**Success Looks Like:**

```
[OK] Server started successfully!
     PID: 1234
     Server Name: Your Server Name
     Game Port: 15636 (UDP)
     Query Port: 15637 (UDP)
     Server IP: 192.168.1.100

Players can connect at: 192.168.1.100:15636
```

**Verification Commands:**

```powershell
# Verify process is running
Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue

# Check if process stayed running (wait 30 seconds then check again)
Start-Sleep -Seconds 30
Get-Process -Name "enshrouded_server"
```

**Failure Indicators:**

- ❌ `[WARN] Server process not detected after launch`
- ❌ Process starts then immediately exits
- ❌ No PID displayed

**If Failed:**

1. Check VC++ Redistributable is installed:

   ```powershell
   Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
   ```

2. Check server logs:

   ```powershell
   Get-ChildItem C:\EnshroudedServer\logs | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 50
   ```

3. Try manual launch to see errors:

   ```powershell
   cd C:\EnshroudedServer
   .\enshrouded_server.exe
   ```

---

### ✅ 4-Health-Check.ps1 — Server Health Validation

**What It Does:** Validates process status, UDP ports, and log health.

**Success Looks Like:**

```
========================================
  Enshrouded Server Health Check
========================================

[1/3] Process Status
-------------------
[OK] Server process is running
     PID:          1234
     Memory:       450.23 MB
     Uptime:       1d 5h 23m 15s

[2/3] UDP Port Status
---------------------
[OK] Game port (15636) is listening
[OK] Query port (15637) is listening

[3/3] Recent Log Activity
-------------------------
[OK] Server logs active (last entry: 2 seconds ago)

========================================
Summary: 3 passed, 0 warnings, 0 failed
[OK] Server is healthy and operational!
========================================
```

**Verification:** All three checks should show `[OK]` in green.

**Partial Failure (Common):**

```
[1/3] Process Status
[OK] Server process is running

[2/3] UDP Port Status
[WARN] UDP port not detected. Server may still be initializing.
```

**Action:** Wait 60 seconds and run health check again. Server initialization takes time.

**Complete Failure:**

```
[FAIL] Server process NOT found
```

**Action:** Run `.\scripts\guest\9-Start-Server.ps1`

---

### ✅ 5-Update-Server.ps1 — Update and Restart Workflow

**What It Does:** Stops server, updates via SteamCMD, restarts, and verifies.

**Success Looks Like:**

```
[OK] Server stopped successfully.
[OK] SteamCMD update completed.
[OK] Server started successfully!
[OK] Server is running (PID: 5678)
```

**Verification Commands:**

```powershell
# Verify server is running after update
Get-Process -Name "enshrouded_server"

# Run health check
.\scripts\guest\4-Health-Check.ps1
```

**Important Notes:**

- ⚠️ SteamCMD may return non-zero exit codes even on success (code 7 is common)
- ✅ Success = server process running after script completes
- ⏱️ Takes 2-5 minutes depending on update size

---

### ✅ 7-Backup-GameFiles.ps1 — Backup Creation

**What It Does:** Creates timestamped ZIP archive of game files with rotation.

**Success Looks Like:**

```
Backup created: enshrouded-backup-20260223_143022.zip
Size: 1.24 GB (compressed from 2.15 GB)
Files: 1,234
Compression: 42.3% reduction
Retention: Keeping last 5 backups, removed 2 old backups.
```

**Verification Commands:**

```powershell
# List recent backups
Get-ChildItem C:\EnshroudedServer\Backups\*.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 5 Name, Length, LastWriteTime

# Test backup integrity (extract to temp location)
$testPath = "C:\Temp\BackupTest"
Expand-Archive -Path "C:\EnshroudedServer\Backups\enshrouded-backup-*.zip" -DestinationPath $testPath -Force
Test-Path "$testPath\enshrouded_server.exe"  # Should return True
Remove-Item $testPath -Recurse -Force
```

**Failure Indicators:**

- ❌ No ZIP file created
- ❌ Zero-byte ZIP file
- ❌ Access denied errors

**If Failed:** Ensure server is stopped during backup for file lock prevention.

---

### ✅ 8-Setup-ScheduledTask.ps1 — Auto-Start Configuration

**What It Does:** Creates Windows Scheduled Task to auto-start server on boot.

**Success Looks Like:**

```
[OK] Scheduled task created: Start Enshrouded Server
     Trigger: At system startup (30 second delay)
     Action: C:\EnshroudedServer\enshrouded_server.exe
```

**Verification Commands:**

```powershell
# Verify task exists
Get-ScheduledTask -TaskName "Start Enshrouded Server"

# Test task execution immediately
Start-ScheduledTask -TaskName "Start Enshrouded Server"
Start-Sleep -Seconds 15
Get-Process -Name "enshrouded_server"  # Should show running process
```

**Full Test (Requires Reboot):**

```powershell
# Reboot VM
Restart-Computer

# After boot (wait 60 seconds), check if server auto-started
Get-Process -Name "enshrouded_server"

# Check task history
Get-ScheduledTaskInfo -TaskName "Start Enshrouded Server" | Select-Object LastRunTime, LastTaskResult
# LastTaskResult should be 0 (success)
```

**Disable Auto-Start:**

```powershell
Disable-ScheduledTask -TaskName "Start Enshrouded Server"
```

---

## 📅 Daily Operations Checklists

### 🟢 Starting a Play Session (3-5 minutes)

**When:** Beginning of gaming session

**Location:** 🟨 Start on host, then 🟦 continue in guest

#### Step 1: 🟨 Power On VM (Host Machine)

```powershell
# Run on Hyper-V host
Start-VM -Name "Enshrouded-Server"

# Wait for Windows to boot (30-60 seconds)
# You can monitor status with:
Get-VM -Name "Enshrouded-Server" | Select-Object Name, State, Uptime
```

**Success:** VM State shows "Running"

#### Step 2: 🟦 Connect to Guest VM

- Use Hyper-V Manager console connection, or
- RDP to guest VM IP address

#### Step 3: 🟦 Update and Start Server (Guest VM)

```powershell
# Run inside guest VM as Administrator
cd C:\EnshroudedServerManagement

# Option A: Update, then start
.\scripts\guest\5-Update-Server.ps1

# Option B: If alias configured
Update-Enshrouded
```

**Wait Time:** 2-3 minutes for update check and server start

**Success:**

```
[OK] Server started successfully!
Server IP: 192.168.1.100
```

#### Step 4: 🟦 Verify Server Health (Guest VM)

```powershell
# Run health check
.\scripts\guest\4-Health-Check.ps1
```

**Success:** All 3 checks show `[OK]`

**If Warnings:** Wait 30 seconds and recheck (ports may still be initializing)

#### Step 5: 🟦 Share Connection Info with Players

```powershell
# Get server IP address
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -ne "127.0.0.1"}).IPAddress | Select-Object -First 1
```

**Share with players:** `<IP-ADDRESS>:15636` (e.g., `192.168.1.100:15636`)

Players can now connect via Enshrouded game client server browser or direct connect.

---

### 🔴 Ending a Play Session (1-2 minutes)

**When:** After gaming session ends (before hibernating VM)

**Location:** 🟦 Guest VM, then 🟨 Host Machine

#### Step 1: 🟦 Stop Server Gracefully (Guest VM)

```powershell
# Run inside guest VM
cd C:\EnshroudedServerManagement
.\scripts\guest\10-Stop-Server.ps1
```

**Wait Time:** 5-30 seconds (graceful shutdown)

**Success:**

```
[OK] Server stopped successfully.
Process terminated gracefully.
```

**If Timeout:** Script will force-kill after 30 seconds (configurable)

#### Step 2: 🟨 Hibernate VM (Host Machine)

```powershell
# Run on Hyper-V host (NOT in guest VM)
cd C:\EnshroudedServerManagement
.\scripts\host\Hibernate-VM.ps1 -VMName "Enshrouded-Server"
```

**Success:**

```
[OK] VM saved successfully.
Memory freed: 16384 MB
```

**Benefits of Hibernation:**

- Frees host RAM and CPU immediately
- VM state preserved (instant resume)
- Faster than full shutdown/boot cycle
- Saves electricity on dedicated server PCs

**To Resume Later:**

```powershell
# On host
Start-VM -Name "Enshrouded-Server"

# Wait 60 seconds for resume, then inside guest:
.\scripts\guest\4-Health-Check.ps1
```

---

### 🔄 Weekly Maintenance (15-25 minutes)

**When:** Sunday evening (low player activity) or before major updates

**Location:** Both 🟦 Guest and 🟨 Host

#### Step 1: 🟦 Backup Game Files (Guest VM)

```powershell
# Inside guest VM
cd C:\EnshroudedServerManagement
.\scripts\guest\7-Backup-GameFiles.ps1
```

**Wait Time:** 2-5 minutes (depends on save size)

**Verify:**

```powershell
Get-ChildItem C:\EnshroudedServer\Backups\*.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

#### Step 2: 🟨 Create VM Checkpoint (Host Machine)

```powershell
# On Hyper-V host
cd C:\EnshroudedServerManagement
.\scripts\host\Backup-VMCheckpoint.ps1 -VMName "Enshrouded-Server"
```

**Wait Time:** 1-3 minutes

**Verify:**

```powershell
Get-VMCheckpoint -VMName "Enshrouded-Server" | Sort-Object CreationTime -Descending | Select-Object -First 1
```

#### Step 3: 🟦 Update Server (Guest VM)

```powershell
# Inside guest VM
.\scripts\guest\5-Update-Server.ps1
```

**Wait Time:** 3-10 minutes (if updates available)

#### Step 4: 🟦 Health Check (Guest VM)

```powershell
.\scripts\guest\4-Health-Check.ps1
```

**Success:** All checks pass

**If Failed:** Restore from checkpoint created in Step 2

#### Step 5: 🟨 Clean Old Checkpoints (Host Machine - Optional)

```powershell
# Keep only last 3 checkpoints to save disk space
Get-VMCheckpoint -VMName "Enshrouded-Server" | 
    Sort-Object CreationTime -Descending | 
    Select-Object -Skip 3 | 
    Remove-VMCheckpoint -Confirm:$false
```

#### Step 6: 🟦 Test Player Connection

- Connect from Enshrouded game client
- Verify world loads correctly
- Check for any performance issues

**Maintenance Complete!** Server is updated and backed up.

---

## �🔄 Common Workflows

### Workflow 1: Starting a Play Session

```powershell
# On Hyper-V host: Start VM if hibernated
Start-VM -Name "Enshrouded-Server"

# Inside guest VM: Update and start server
Update-Enshrouded  # Alias for 5-Update-Server.ps1

# Verify server health
.\scripts\guest\4-Health-Check.ps1

# Share server IP with players
ipconfig | Select-String "IPv4"
```

### Workflow 2: Ending a Play Session

```powershell
# Inside guest VM: Stop server gracefully
.\scripts\guest\10-Stop-Server.ps1

# On Hyper-V host: Hibernate VM to free resources
.\scripts\host\Hibernate-VM.ps1 -VMName "Enshrouded-Server"
```

### Workflow 3: Applying Game Updates

```powershell
# Inside guest VM: Backup before update
.\scripts\guest\7-Backup-GameFiles.ps1

# On Hyper-V host: Create checkpoint
.\scripts\host\Backup-VMCheckpoint.ps1 -VMName "Enshrouded-Server"

# Inside guest VM: Update and restart server
Update-Enshrouded

# Verify update successful
.\scripts\guest\4-Health-Check.ps1
```

### Workflow 4: Changing Server Settings

```powershell
# Edit configuration
notepad C:\EnshroudedServer\EnshroudedServerConfig.json

# Apply new settings
.\scripts\guest\3-Configure-Server.ps1

# Restart server for changes to take effect
.\scripts\guest\10-Stop-Server.ps1
.\scripts\guest\9-Start-Server.ps1
```

### Workflow 5: Weekly Maintenance

```powershell
# Inside guest VM
.\scripts\guest\7-Backup-GameFiles.ps1       # Backup game files
Update-Enshrouded                             # Update to latest version

# On Hyper-V host
.\scripts\host\Backup-VMCheckpoint.ps1 -VMName "Enshrouded-Server"

# Clean up old checkpoints (optional)
Get-VMCheckpoint -VMName "Enshrouded-Server" | 
    Sort-Object CreationTime -Descending | 
    Select-Object -Skip 5 | 
    Remove-VMCheckpoint -Confirm:$false
```

---

## 🛠️ Troubleshooting Decision Trees

### 🌳 Decision Tree: Server Won't Start

Follow this flowchart to diagnose server startup failures:

#### Question 1️⃣: Does `enshrouded_server.exe` exist?

**Check:**

```powershell
Test-Path C:\EnshroudedServer\enshrouded_server.exe
Get-Item C:\EnshroudedServer\enshrouded_server.exe | Select-Object Length, LastWriteTime
```

**❌ NO (returns False or file not found):**

- **Cause:** Server files not downloaded
- **Solution:** Run server download script

  ```powershell
  .\scripts\guest\2-Download-Server.ps1
  ```

- **Verify:** File should be ~500+ MB

**✅ YES:** Continue to Question 2

---

#### Question 2️⃣: Is Visual C++ Redistributable installed?

**Check:**

```powershell
$vcRedist = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue
if ($vcRedist) {
    Write-Host "[OK] VC++ Redistributable installed: Version $($vcRedist.Version)" -ForegroundColor Green
} else {
    Write-Host "[FAIL] VC++ Redistributable NOT installed" -ForegroundColor Red
}
```

**❌ NO (not installed):**

- **Cause:** Missing required runtime library
- **Solution:** Install VC++ Redistributable

  ```powershell
  # Manual download and install
  Start-Process "https://aka.ms/vs/17/release/vc_redist.x64.exe"
  # Or re-run dependencies script
  .\scripts\guest\1-Install-Dependencies.ps1
  ```

- **Verify:** Re-run check command above

**✅ YES:** Continue to Question 3

---

#### Question 3️⃣: Does process start then immediately exit?

**Check:**

```powershell
# Try to start server
.\scripts\guest\9-Start-Server.ps1

# Wait 10 seconds
Start-Sleep -Seconds 10

# Check if still running
$proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "[OK] Server is running" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Server exited after launch" -ForegroundColor Red
}
```

**❌ YES (process exits immediately):**

- **Cause:** Configuration error, missing DLLs, or permission issue
- **Solution:** Check server logs for specific error

  ```powershell
  # View most recent server log
  $logFile = Get-ChildItem C:\EnshroudedServer\logs -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($logFile) {
      Write-Host "Log file: $($logFile.FullName)" -ForegroundColor Cyan
      Get-Content $logFile.FullName -Tail 50
  } else {
      Write-Host "No log files found - server crashed before creating logs" -ForegroundColor Red
  }
  ```

- **Common Log Errors:**
  - `Missing DLL`: Install VC++ Redistributable (see Question 2)
  - `Access denied`: Run PowerShell as Administrator
  - `Port already in use`: Another process using port 15636/15637
  - `Configuration parse error`: Fix `enshrouded_server.json` syntax

- **Try manual launch to see console errors:**

  ```powershell
  cd C:\EnshroudedServer
  .\enshrouded_server.exe
  # Watch console output for errors
  ```

**✅ NO (process stays running):** Continue to Question 4

---

#### Question 4️⃣: Are UDP ports listening?

**Check:**

```powershell
# Check game port
$gamePort = Get-NetUDPEndpoint -LocalPort 15636 -ErrorAction SilentlyContinue
$queryPort = Get-NetUDPEndpoint -LocalPort 15637 -ErrorAction SilentlyContinue

if ($gamePort) {
    Write-Host "[OK] Game port 15636 is listening" -ForegroundColor Green
} else {
    Write-Host "[WARN] Game port 15636 NOT listening yet" -ForegroundColor Yellow
}

if ($queryPort) {
    Write-Host "[OK] Query port 15637 is listening" -ForegroundColor Green
} else {
    Write-Host "[WARN] Query port 15637 NOT listening yet" -ForegroundColor Yellow
}
```

**⚠️ NO (ports not listening but process running):**

- **Cause:** Server still initializing (takes 30-90 seconds after process start)
- **Solution:** Wait and recheck

  ```powershell
  Write-Host "Waiting 60 seconds for server initialization..." -ForegroundColor Yellow
  Start-Sleep -Seconds 60
  .\scripts\guest\4-Health-Check.ps1
  ```

- **If still failing after 2 minutes:** Check firewall rules

  ```powershell
  Get-NetFirewallRule -DisplayName "*Enshrouded*" | Select-Object DisplayName, Enabled, Direction, Action
  ```

**✅ YES (ports listening):** Server is running correctly! Continue to connectivity testing.

---

### 🌐 Decision Tree: Players Can't Connect

#### Question 1️⃣: Is server process running on guest?

**Check:**

```powershell
# Inside guest VM
Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
.\scripts\guest\4-Health-Check.ps1
```

**❌ NO:**

- **Solution:** Start the server

  ```powershell
  .\scripts\guest\9-Start-Server.ps1
  ```

- Return to [Server Won't Start](#-decision-tree-server-wont-start) decision tree if fails

**✅ YES:** Continue to Question 2

---

#### Question 2️⃣: Can you connect from WITHIN the guest VM?

**Test:**

1. Launch Enshrouded game client ON the guest VM (if possible)
2. Try connecting to `localhost:15636` or `127.0.0.1:15636`

**Alternative Test:**

```powershell
# Test localhost UDP connectivity
Test-NetConnection -ComputerName localhost -InformationLevel Detailed
# Note: This tests TCP, not UDP, but validates basic networking

# Check if server is bound to all interfaces
Get-NetUDPEndpoint -LocalPort 15636 | Select-Object LocalAddress, LocalPort
# LocalAddress should show 0.0.0.0 (all interfaces) or specific IP
```

**❌ NO (can't connect from localhost):**

- **Cause:** Server configuration issue or firewall blocking localhost
- **Solution:**
  1. Check server configuration:

     ```powershell
     Get-Content C:\EnshroudedServer\enshrouded_server.json | ConvertFrom-Json | Select-Object gamePort, queryPort
     ```

  2. Verify ports match config (15636/15637)
  3. Restart server after config changes

**✅ YES (localhost connection works):** Continue to Question 3

---

#### Question 3️⃣: Can the HOST connect to the GUEST VM?

**Get Guest IP:**

```powershell
# Inside guest VM
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown"}).IPAddress
# Example output: 192.168.1.100
```

**Test from Host:**

```powershell
# On Hyper-V host machine
$guestIP = "192.168.1.100"  # Use actual guest IP

# Test basic connectivity
Test-NetConnection -ComputerName $guestIP -InformationLevel Detailed

# Test specific port (TCP test only - UDP requires different tools)
Test-NetConnection -ComputerName $guestIP -Port 15636 -InformationLevel Detailed
```

**❌ NO (host can't reach guest):**

- **Cause:** Hyper-V network configuration or guest Windows Firewall
- **Solutions:**

  **A. Check Hyper-V Network Adapter:**

  ```powershell
  # On host
  Get-VMNetworkAdapter -VMName "Enshrouded-Server" | Select-Object SwitchName, MacAddress, IPAddresses
  ```

  - Should show "External" switch or configured NAT switch
  - **Fix:** Change to External switch for direct network access

    ```powershell
    Get-VM -Name "Enshrouded-Server" | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "External Switch Name"
    ```

  **B. Check Guest Windows Firewall:**

  ```powershell
  # Inside guest VM
  Get-NetFirewallProfile | Select-Object Name, Enabled
  
  # Temporarily disable for testing (TESTING ONLY!)
  Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
  
  # Re-test connection from host
  # If works: Firewall is the issue
  # Re-enable firewall:
  Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
  
  # Fix: Recreate firewall rules
  .\scripts\guest\1-Install-Dependencies.ps1
  ```

  **C. Check Guest IP Configuration:**

  ```powershell
  # Inside guest
  Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway
  ```

  - Should have valid IP, subnet, and gateway
  - **Fix:** Check Hyper-V virtual switch configuration

**✅ YES (host can reach guest):** Continue to Question 4

---

#### Question 4️⃣: Can EXTERNAL network connect?

**Test from another PC on network:**

```powershell
# From any computer on your local network
Test-NetConnection -ComputerName <guest-IP> -InformationLevel Detailed
```

**Try connecting from Enshrouded game client** on another PC

**❌ NO (external network can't connect):**

- **Cause:** Router firewall, NAT configuration, or ISP blocking

- **Solutions:**

  **A. Port Forwarding (if behind router):**
  - Access router admin panel (typically 192.168.1.1)
  - Forward UDP ports 15636 and 15637 to guest VM IP
  - Example router settings:

    ```
    Protocol: UDP
    External Port: 15636
    Internal IP: 192.168.1.100
    Internal Port: 15636
    ```

  **B. Check ISP Doesn't Block UDP Gaming Ports:**
  - Some ISPs block common gaming ports
  - Solution: Change server ports in config

    ```powershell
    # Edit config to use alternative ports
    notepad C:\EnshroudedServer\EnshroudedServerConfig.json
    # Change GamePort to 25636, QueryPort to 25637
    .\scripts\guest\3-Configure-Server.ps1
    .\scripts\guest\10-Stop-Server.ps1
    .\scripts\guest\9-Start-Server.ps1
    ```

  **C. Use VPN Solution (Hamachi, ZeroTier):**
  - Create virtual LAN for players
  - Bypasses port forwarding requirements
  - Players connect using VPN IP instead

  **D. Windows Firewall - Ensure rules allow external connections:**

  ```powershell
  # Inside guest VM
  Get-NetFirewallRule -DisplayName "*Enshrouded*" | Select-Object DisplayName, Enabled, Profile, Direction, Action
  
  # Rules should allow:
  # - Direction: Inbound
  # - Action: Allow
  # - Profile: Domain, Private, Public (all three)
  ```

**✅ YES:** Connection working! Server is fully operational.

---

### 🔄 Decision Tree: Backup and Restore Issues

#### Backup Creation Failed

**Check disk space:**

```powershell
Get-PSDrive C | Select-Object @{N="Free GB";E={[math]::Round($_.Free/1GB,2)}}, @{N="Used GB";E={[math]::Round($_.Used/1GB,2)}}
```

**Common Issues:**

- **Insufficient disk space:** Free up space or change backup location in config
- **Access denied:** Run PowerShell as Administrator
- **File locks:** Stop server before backup

  ```powershell
  .\scripts\guest\10-Stop-Server.ps1
  .\scripts\guest\7-Backup-GameFiles.ps1
  .\scripts\guest\9-Start-Server.ps1
  ```

#### Restore from Backup

**Extract backup:**

```powershell
# Stop server first
.\scripts\guest\10-Stop-Server.ps1

# List available backups
Get-ChildItem C:\EnshroudedServer\Backups\*.zip | Sort-Object LastWriteTime -Descending

# Extract backup to temporary location
$backupFile = "C:\EnshroudedServer\Backups\enshrouded-backup-20260223_143022.zip"
$restorePath = "C:\Temp\EnshroudedRestore"
Expand-Archive -Path $backupFile -DestinationPath $restorePath -Force

# Verify contents
Get-ChildItem $restorePath

# Copy restored files back (CAUTION: Overwrites current files!)
Copy-Item -Path "$restorePath\*" -Destination "C:\EnshroudedServer" -Recurse -Force

# Restart server
.\scripts\guest\9-Start-Server.ps1
```

---

## 🛠️ Legacy Troubleshooting (Original Issues)

### Issue: Server won't start after installation

**Symptoms:** `9-Start-Server.ps1` completes but health check shows process not running.

**Resolution:**

1. Check management logs:

   ```powershell
   Get-Content C:\EnshroudedServer\ManagementLogs\$(Get-Date -Format 'yyyy-MM-dd').log
   ```

2. Verify firewall rules:

   ```powershell
   Get-NetFirewallRule | Where-Object {$_.DisplayName -like '*Enshrouded*'}
   ```

3. Check Visual C++ Redistributable:

   ```powershell
   Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like '*Visual C++*'}
   ```

4. Try manual server launch:

   ```powershell
   cd C:\EnshroudedServer
   .\enshrouded_server.exe
   # Watch for error messages in console
   ```

### Issue: SteamCMD update fails

**Symptoms:** `5-Update-Server.ps1` or `2-Download-Server.ps1` hangs or reports errors.

**Resolution:**

1. Test SteamCMD manually:

   ```powershell
   C:\SteamCMD\steamcmd.exe +login anonymous +quit
   ```

2. Check network connectivity:

   ```powershell
   Test-NetConnection -ComputerName steamcdn-a.akamaihd.net -Port 443
   ```

3. Re-download SteamCMD:

   ```powershell
   Remove-Item C:\SteamCMD -Recurse -Force
   .\scripts\guest\1-Install-Dependencies.ps1
   ```

4. Check Steam service status: <https://steamstat.us/>

### Issue: Scheduled task doesn't auto-start server

**Symptoms:** Server not running after VM reboot.

**Resolution:**

1. Verify task exists:

   ```powershell
   Get-ScheduledTask -TaskName "Start Enshrouded Server"
   ```

2. Check task history:

   ```powershell
   Get-ScheduledTaskInfo -TaskName "Start Enshrouded Server"
   ```

3. Manually trigger task:

   ```powershell
   Start-ScheduledTask -TaskName "Start Enshrouded Server"
   Start-Sleep 15
   Get-Process enshrouded_server
   ```

4. Recreate task:

   ```powershell
   Unregister-ScheduledTask -TaskName "Start Enshrouded Server" -Confirm:$false
   .\scripts\guest\8-Setup-ScheduledTask.ps1
   ```

### Issue: Health check shows ports not listening

**Symptoms:** `4-Health-Check.ps1` reports "[WARN] UDP port not detected."

**Resolution:**

1. Verify server process running:

   ```powershell
   Get-Process enshrouded_server
   ```

2. Check for port conflicts:

   ```powershell
   Get-NetUDPEndpoint -LocalPort 15636, 15637
   ```

3. Temporarily disable firewall (test only):

   ```powershell
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
   # Test connection, then re-enable:
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
   ```

4. Verify configuration match:

   ```powershell
   Get-Content C:\EnshroudedServer\EnshroudedServerConfig.json | ConvertFrom-Json | Select-Object -ExpandProperty Server
   Get-Content C:\EnshroudedServer\enshrouded_server.json | ConvertFrom-Json
   ```

### Issue: Players can't connect

**Symptoms:** Server running and healthy, but players get connection timeout.

**Resolution:**

1. Verify VM network adapter is "External":

   ```powershell
   # On Hyper-V host:
   Get-VMNetworkAdapter -VMName "Enshrouded-Server"
   ```

2. Check VM firewall from host:

   ```powershell
   # Inside guest:
   Get-NetFirewallProfile | Select-Object Name, Enabled
   ```

3. Test port forwarding (if using NAT):

   ```powershell
   # On Hyper-V host (if using NAT switch):
   Add-NetNatStaticMapping -NatName "NATSwitch" -Protocol UDP -ExternalIPAddress 0.0.0.0/24 -ExternalPort 15636 -InternalIPAddress <VM_IP> -InternalPort 15636
   Add-NetNatStaticMapping -NatName "NATSwitch" -Protocol UDP -ExternalIPAddress 0.0.0.0/24 -ExternalPort 15637 -InternalIPAddress <VM_IP> -InternalPort 15637
   ```

4. Verify players using correct IP:

   ```powershell
   # Inside guest:
   (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet").IPAddress
   ```

### Issue: Backup fails with access denied

**Symptoms:** `7-Backup-GameFiles.ps1` reports permissions error.

**Resolution:**

1. Run PowerShell as Administrator

2. Check disk space:

   ```powershell
   Get-PSDrive C | Select-Object Used, Free
   ```

3. Stop server before backup:

   ```powershell
   .\scripts\guest\10-Stop-Server.ps1
   .\scripts\guest\7-Backup-GameFiles.ps1
   .\scripts\guest\9-Start-Server.ps1
   ```

4. Verify backup directory exists and is writable:

   ```powershell
   Test-Path C:\EnshroudedServer\Backups
   New-Item -Path C:\EnshroudedServer\Backups\test.txt -ItemType File -Force
   Remove-Item C:\EnshroudedServer\Backups\test.txt
   ```

### Issue: Host scripts can't find VM

**Symptoms:** `Backup-VMCheckpoint.ps1` or `Hibernate-VM.ps1` reports VM not found.

**Resolution:**

1. List all VMs:

   ```powershell
   Get-VM | Select-Object Name, State
   ```

2. Verify VM name matches config:

   ```powershell
   # Inside guest:
   Get-Content C:\EnshroudedServer\EnshroudedServerConfig.json | ConvertFrom-Json | Select-Object -ExpandProperty VM
   ```

3. Update config or pass correct name:

   ```powershell
   .\scripts\host\Backup-VMCheckpoint.ps1 -VMName "<actual-vm-name>"
   ```

4. Ensure Hyper-V module loaded:

   ```powershell
   Import-Module Hyper-V
   Get-Command -Module Hyper-V
   ```

---

## 🧪 Testing & Validation Guide

This project includes multiple testing layers: automated Pester tests and manual validation procedures.

### 🤖 Automated Testing with Pester

#### Install Pester (If Not Already Installed)

```powershell
# Check if Pester is installed
Get-Module -ListAvailable -Name Pester

# Install Pester if needed
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser

# Verify installation
Import-Module Pester
Get-Module Pester
```

#### Run All Tests

```powershell
# Navigate to project root
cd C:\EnshroudedServerManagement

# Run all tests (excludes integration tests by default)
Invoke-Pester -Path .\tests\

# Run with detailed output
Invoke-Pester -Path .\tests\ -Output Detailed
```

**Expected Results:**

```
Tests completed in 5.23s
Tests Passed: 45, Failed: 0, Skipped: 12 NotRun: 0
```

**Skipped Tests:** Integration tests marked `-Skip` require actual server installation.

---

#### Test Suite Details

### ✅ Config.Tests.ps1 — Configuration Validation

**What It Tests:**

- JSON syntax validity
- Required configuration sections present (Paths, VM, Server, Backup, Logging)
- Path formats (Windows absolute paths)
- Port numbers in valid range (1-65535)
- Slot count reasonable (1-16 players)
- Retention count positive (1-100)
- Default values correct

**Run Individually:**

```powershell
Invoke-Pester -Path .\tests\Config.Tests.ps1 -Output Detailed
```

**Expected Output:**

```
Describing Configuration File Tests
  Context Configuration Template Exists
    [+] Configuration template file should exist 12ms (11ms|1ms)
  Context JSON Syntax Validation
    [+] Configuration template should be valid JSON 45ms (43ms|2ms)
  ...
Tests Passed: 16, Failed: 0
```

**If Tests Fail:**

- Check `config\EnshroudedServerConfig.json` syntax (missing commas, brackets)
- Verify all required keys present
- Check port numbers are numeric and in range
- Verify paths use backslashes `\` not forward slashes `/`

---

### ✅ Scripts.Tests.ps1 — Script Quality Standards

**What It Tests:**

- All expected scripts exist (0-10, Common-Functions, host scripts)
- PowerShell syntax valid (no parse errors)
- Comment-based help present (.SYNOPSIS, .DESCRIPTION, .EXAMPLE)
- Logging standards (dot-sources Common-Functions, uses Write-ServerLog)
- Error handling (try/catch blocks or -ErrorAction)
- Configuration usage (calls Get-ServerConfig, minimal hardcoded paths)
- CmdletBinding and param blocks present
- Output formatting consistency (Write-Host with colors)
- Code style (no trailing whitespace, consistent indentation)
- Security (no hardcoded passwords, admin privilege checks)

**Run Individually:**

```powershell
Invoke-Pester -Path .\tests\Scripts.Tests.ps1 -Output Detailed
```

**Expected Output:**

```
Describing PowerShell Script Quality Tests
  Context Script Files Exist
    [+] Should have exactly 11 guest scripts 18ms
    [+] Should have exactly 2 host scripts 5ms
  Context PowerShell Syntax Validation
    [+] 0-Initial-Setup.ps1 should have valid PowerShell syntax 123ms
    [+] 1-Install-Dependencies.ps1 should have valid PowerShell syntax 98ms
  ...
Tests Passed: 48, Failed: 0
```

**If Tests Fail:**

- Check script has PowerShell syntax errors (run in ISE/VSCode)
- Add missing comment-based help blocks
- Ensure scripts dot-source Common-Functions.ps1
- Add try/catch blocks around risky operations

---

### ✅ Functional.Tests.ps1 — Functional & Integration Tests

**What It Tests:**

#### Unit Tests (Always Run)

- Common function availability and parameters
- Write-ServerLog accepts all log levels
- Test-ServerProcess returns correct types
- Get-ServerConfig loads configuration
- Format-ByteSize formats correctly (KB, MB, GB, TB)
- Directory creation behavior
- Process detection behavior
- Configuration loading behavior
- ZIP archive creation
- File rotation logic

#### Integration Tests (Marked -Skip by Default)

These require actual server installation and are skipped in normal test runs:

- Server installation directories exist
- Server executable present
- SteamCMD installed
- Process management (start/stop)
- Health check execution
- Backup file creation
- Configuration application
- UDP port detection

**Run Unit Tests Only:**

```powershell
Invoke-Pester -Path .\tests\Functional.Tests.ps1 -ExcludeTag "Integration","E2E" -Output Detailed
```

**Run Integration Tests (After Installation):**

```powershell
# WARNING: Requires complete server installation first
Invoke-Pester -Path .\tests\Functional.Tests.ps1 -Tag "Integration" -Output Detailed
```

**Expected Output (Unit Tests):**

```
Describing Common Functions Tests
  [+] Write-ServerLog function should be available 45ms
  [+] Write-ServerLog should accept Level parameter 23ms
  ...
Tests Passed: 22, Failed: 0, Skipped: 0
```

**Expected Output (Integration Tests):**

```
Describing Integration Test Markers
  [+] Server installation directory should exist 12ms
  [+] Server executable should exist 8ms
  ...
Tests Passed: 8, Failed: 0
```

---

### 🔍 Manual Validation Procedures

Automated tests validate code quality and configuration. Manual validation ensures **operational functionality**.

#### Post-Installation Validation Checklist

**Run AFTER completing Quick Start installation:**

##### ✅ Step 1: Verify All Files Installed

```powershell
# Check SteamCMD
Test-Path C:\SteamCMD\steamcmd.exe

# Check server executable
$serverExe = Get-Item C:\EnshroudedServer\enshrouded_server.exe
Write-Host "Server Size: $([math]::Round($serverExe.Length/1MB,2)) MB"
Write-Host "Last Modified: $($serverExe.LastWriteTime)"
# Expected: 500+ MB

# Check configuration deployed
Test-Path C:\EnshroudedServer\EnshroudedServerConfig.json

# Check firewall rules created
Get-NetFirewallRule -DisplayName "*Enshrouded*" | Select-Object DisplayName, Enabled
```

**Success Criteria:**

- ✅ All paths return `True`
- ✅ Server executable is 500+ MB
- ✅ Two firewall rules exist and are Enabled

---

##### ✅ Step 2: Verify VC++ Redistributable

```powershell
$vcRedist = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" -ErrorAction SilentlyContinue

if ($vcRedist) {
    Write-Host "[OK] VC++ Redistributable installed" -ForegroundColor Green
    Write-Host "     Version: $($vcRedist.Version)" -ForegroundColor Gray
} else {
    Write-Host "[FAIL] VC++ Redistributable NOT installed" -ForegroundColor Red
    Write-Host "       Server will NOT start without this!" -ForegroundColor Red
}
```

**Success Criteria:**

- ✅ Shows "[OK] VC++ Redistributable installed"
- ❌ If failed: Download from <https://aka.ms/vs/17/release/vc_redist.x64.exe> and install

---

##### ✅ Step 3: Test Server Process Launch

```powershell
# Start server
.\scripts\guest\9-Start-Server.ps1

# Wait for initialization
Write-Host "Waiting 30 seconds for server initialization..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Check if running
$proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue

if ($proc) {
    Write-Host "[OK] Server is running" -ForegroundColor Green
    Write-Host "     PID: $($proc.Id)" -ForegroundColor Gray
    Write-Host "     Memory: $([math]::Round($proc.WorkingSet64/1MB,2)) MB" -ForegroundColor Gray
} else {
    Write-Host "[FAIL] Server not running" -ForegroundColor Red
    Write-Host "       Check server logs for errors" -ForegroundColor Yellow
}
```

**Success Criteria:**

- ✅ Process exists with PID
- ✅ Memory usage 400-800 MB is typical
- ❌ If failed: Check [Server Won't Start Decision Tree](#-decision-tree-server-wont-start)

---

##### ✅ Step 4: Validate Health Check Passes

```powershell
.\scripts\guest\4-Health-Check.ps1
```

**Success Criteria:**

```
Summary: 3 passed, 0 warnings, 0 failed
[OK] Server is healthy and operational!
```

**Partial Success (Acceptable):**

```
Summary: 2 passed, 1 warnings, 0 failed
[WARN] UDP ports may still be initializing
```

- ⚠️ Wait another 30 seconds and recheck

**Failure:**

```
Summary: 0 passed, 0 warnings, 3 failed
```

- ❌ See troubleshooting decision trees

---

##### ✅ Step 5: Test Network Connectivity

**Get VM IP Address:**

```powershell
$vmIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -ne "127.0.0.1" -and $_.PrefixOrigin -ne "WellKnown"}).IPAddress
Write-Host "Server IP: $vmIP" -ForegroundColor Cyan
Write-Host "Connection String: ${vmIP}:15636" -ForegroundColor Green
```

**Test from Hyper-V Host:**

```powershell
# On host machine (not guest)
$guestIP = "192.168.1.100"  # Replace with actual guest IP
Test-NetConnection -ComputerName $guestIP -InformationLevel Detailed
```

**Success Criteria:**

- ✅ PingSucceeded: True
- ✅ TcpTestSucceeded: (may vary)

**Test from Game Client:**

1. Launch Enshrouded game
2. Go to Multiplayer → Join Game
3. Search for server by name OR direct connect to IP:15636
4. Verify server appears in list or connection succeeds

**Success Criteria:**

- ✅ Server visible in browser
- ✅ Can join and see game world

---

##### ✅ Step 6: Test Backup Functionality

```powershell
# Create backup
.\scripts\guest\7-Backup-GameFiles.ps1

# Verify backup created
$latestBackup = Get-ChildItem C:\EnshroudedServer\Backups\*.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestBackup) {
    Write-Host "[OK] Backup created successfully" -ForegroundColor Green
    Write-Host "     File: $($latestBackup.Name)" -ForegroundColor Gray
    Write-Host "     Size: $([math]::Round($latestBackup.Length/1MB,2)) MB" -ForegroundColor Gray
    Write-Host "     Created: $($latestBackup.LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Host "[FAIL] No backup file found" -ForegroundColor Red
}

# Test backup integrity (extract to temp location)
$testPath = "C:\Temp\BackupTest_$(Get-Random)"
Expand-Archive -Path $latestBackup.FullName -DestinationPath $testPath -Force

$extractedExe = Test-Path "$testPath\enshrouded_server.exe"
if ($extractedExe) {
    Write-Host "[OK] Backup integrity verified - files extractable" -ForegroundColor Green
} else {
    Write-Host "[WARN] Backup may be incomplete" -ForegroundColor Yellow
}

# Cleanup
Remove-Item $testPath -Recurse -Force -ErrorAction SilentlyContinue
```

**Success Criteria:**

- ✅ ZIP file created in Backups directory
- ✅ Size is reasonable (compressed, typically 60-80% of original)
- ✅ Files extract successfully

---

##### ✅ Step 7: Test Scheduled Task (Optional)

```powershell
# Only if you ran 8-Setup-ScheduledTask.ps1

# Verify task exists
$task = Get-ScheduledTask -TaskName "Start Enshrouded Server" -ErrorAction SilentlyContinue

if ($task) {
    Write-Host "[OK] Scheduled task exists" -ForegroundColor Green
    Write-Host "     State: $($task.State)" -ForegroundColor Gray
} else {
    Write-Host "[INFO] Scheduled task not configured (this is optional)" -ForegroundColor Yellow
}

# Test task execution
if ($task) {
    # Stop server first
    .\scripts\guest\10-Stop-Server.ps1
    Start-Sleep -Seconds 5
    
    # Trigger task
    Start-ScheduledTask -TaskName "Start Enshrouded Server"
    Write-Host "Waiting 15 seconds for task to start server..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    
    # Check if server started
    $proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "[OK] Scheduled task successfully started server" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Scheduled task did not start server" -ForegroundColor Red
        Write-Host "       Check task history for errors" -ForegroundColor Yellow
    }
}
```

**Success Criteria:**

- ✅ Task exists and is in "Ready" state
- ✅ Manual trigger successfully starts server
- ✅ After VM reboot, server auto-starts within 60 seconds

---

### 🎯 First-Time Setup Complete Validation

**You have successfully installed the Enshrouded server if ALL of the following are true:**

- [x] ✅ Step 1: All files verified (SteamCMD, server exe, config, firewall rules)
- [x] ✅ Step 2: VC++ Redistributable installed
- [x] ✅ Step 3: Server process starts and stays running
- [x] ✅ Step 4: Health check shows 3/3 passed (or 2/3 with port warnings that resolve after 60s wait)
- [x] ✅ Step 5: Network connectivity confirmed (host can ping guest)
- [x] ✅ Step 6: Backup created and verified
- [x] ✅ Step 7: (Optional) Scheduled task configured and tested

**If ANY step failed:** Return to [Troubleshooting Decision Trees](#️-troubleshooting-decision-trees)

**If ALL steps passed:** 🎉 **SERVER IS OPERATIONAL!** Proceed to [Daily Operations](#-daily-operations-checklists)

---

## 🧪 Testing

### Running Tests

**Note:** This section describes the legacy testing approach. See the comprehensive [Testing & Validation Guide](#-testing--validation-guide) section above for detailed procedures.

This project includes Pester tests to validate functionality.

```powershell
# Install Pester (if not already installed)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester -Path .\tests\

# Run specific test suite
Invoke-Pester -Path .\tests\Config.Tests.ps1
Invoke-Pester -Path .\tests\Scripts.Tests.ps1
Invoke-Pester -Path .\tests\Functional.Tests.ps1

# Run tests with code coverage
Invoke-Pester -Path .\tests\ -CodeCoverage .\scripts\guest\*.ps1
```

### Test Suites

**Config.Tests.ps1** — Validates configuration file structure and values

- JSON syntax validation
- Required keys present
- Path formats valid
- Port numbers in range
- Retention count positive

**Scripts.Tests.ps1** — Validates script quality and standards

- PowerShell syntax valid (all scripts parse)
- Comment-based help present
- Logging uses `Write-ServerLog`
- Error handling with try/catch
- No hardcoded paths (use config)

**Functional.Tests.ps1** — Validates script behavior (mocked and integration)

- Directory creation
- Process detection
- Backup file creation
- Configuration updates
- Integration test markers (skipped by default)

**See the comprehensive [Testing & Validation Guide](#-testing--validation-guide) section for detailed testing procedures including manual validation checklists.**

---

## 📋 Script Reference

### 🟦 Guest Scripts (Run inside Windows 11 Pro VM)

**⚠️ Run these INSIDE the virtual machine, not on the host.**

| Script | Purpose | Frequency | Admin Required |
|--------|---------|-----------|----------------|
| `0-Initial-Setup.ps1` | Automated first-time setup | One-time | ✅ Yes |
| `1-Install-Dependencies.ps1` | Install SteamCMD and prerequisites | One-time | ✅ Yes |
| `2-Download-Server.ps1` | Download Enshrouded server via SteamCMD | One-time + updates | ✅ Yes |
| `3-Configure-Server.ps1` | Apply server configuration | On config change | ✅ Yes |
| `4-Health-Check.ps1` | Validate server health | Every session | ❌ No |
| `5-Update-Server.ps1` | Restart and update server | Every session / on patch | ✅ Yes |
| `6-Setup-Alias.ps1` | Configure PowerShell profile alias | One-time | ❌ No |
| `7-Backup-GameFiles.ps1` | Backup game files to zip | Weekly / pre-update | ✅ Yes |
| `8-Setup-ScheduledTask.ps1` | Configure auto-start scheduled task | One-time | ✅ Yes |
| `9-Start-Server.ps1` | Start server process | On-demand | ✅ Yes |
| `10-Stop-Server.ps1` | Stop server process gracefully | Pre-update / end session | ✅ Yes |

**Note:** Admin privileges = "Run PowerShell as Administrator"

---

### 🟨 Host Scripts (Run on Hyper-V host machine)

**⚠️ Run these ON YOUR PC (the Hyper-V host), NOT inside the guest VM.**

| Script | Purpose | Frequency | Admin Required |
|--------|---------|-----------|----------------|
| `Backup-VMCheckpoint.ps1` | Create Hyper-V checkpoint | Weekly / pre-update | ✅ Yes |
| `Hibernate-VM.ps1` | Save VM state (hibernate) | End of every session | ✅ Yes |

**Note:** These scripts use Hyper-V PowerShell module, which is NOT available inside guest VMs.

---

### 📚 Common Functions

**Location:** `scripts\guest\Common-Functions.ps1`

**Purpose:** Shared utility functions used by all guest scripts.

| Function | Purpose | Parameters |
|----------|---------|------------|
| `Write-ServerLog` | Structured logging to file and console | `-Message`, `-Level` (INFO/WARN/ERROR/SUCCESS), `-ScriptName` |
| `Test-ServerProcess` | Check if server process is running | None |
| `Get-ServerConfig` | Load configuration from JSON file | `-ConfigPath` (optional) |
| `Test-AdminPrivileges` | Check if running as Administrator | None |
| `Format-ByteSize` | Format bytes to human-readable size | `-Bytes` |

**Usage Example:**

```powershell
# Dot-source the common functions in your script
. "$PSScriptRoot\Common-Functions.ps1"

# Use the functions
Write-ServerLog "Starting operation..." -Level INFO
$config = Get-ServerConfig
if (-not (Test-AdminPrivileges)) {
    Write-ServerLog "Admin privileges required!" -Level ERROR
    exit 1
}
```

---

## 📋 Script Reference

### Guest Scripts (Run inside Windows 11 Pro VM)

| Script | Purpose | Frequency |
|--------|---------|-----------|
| `0-Initial-Setup.ps1` | Automated first-time setup | One-time |
| `1-Install-Dependencies.ps1` | Install SteamCMD and prerequisites | One-time |
| `2-Download-Server.ps1` | Download Enshrouded server via SteamCMD | One-time + updates |
| `3-Configure-Server.ps1` | Apply server configuration | On change |
| `4-Health-Check.ps1` | Validate server health | Every session |
| `5-Update-Server.ps1` | Restart and update server | Every session / on patch |
| `6-Setup-Alias.ps1` | Configure PowerShell profile alias | One-time |
| `7-Backup-GameFiles.ps1` | Backup game files to zip | Weekly / pre-update |
| `8-Setup-ScheduledTask.ps1` | Configure auto-start scheduled task | One-time |
| `9-Start-Server.ps1` | Start server process | On-demand |
| `10-Stop-Server.ps1` | Stop server process gracefully | Pre-update / end session |

### Host Scripts (Run on Hyper-V host machine)

| Script | Purpose | Frequency |
|--------|---------|-----------|
| `Backup-VMCheckpoint.ps1` | Create Hyper-V checkpoint | Weekly / pre-update |
| `Hibernate-VM.ps1` | Save VM state (hibernate) | End of every session |

### Common Functions

| Function | Purpose |
|----------|---------|
| `Write-ServerLog` | Structured logging to file and console |

---

## 🔐 Security Considerations

**⚠️ IMPORTANT: Read [SECURITY.MD](SECURITY.MD) before deployment.**

### Quick Security Checklist

- ✅ **Use dedicated VM** - Don't run on personal/production systems
- ✅ **Review scripts** - All scripts require Administrator privileges
- ✅ **Firewall awareness** - Scripts open UDP ports 15636 and 15637
- ✅ **Plaintext passwords** - Server password stored unencrypted in config file
- ✅ **Network isolation** - Start with Hyper-V Internal/NAT switch, not External
- ✅ **Scheduled task** - Runs as SYSTEM account with highest privileges
- ✅ **Regular updates** - Keep Windows and server files updated
- ✅ **Backup strategy** - Both file-level and VM checkpoint backups recommended

### Security Features

- **Firewall:** Scripts configure Windows Firewall to allow only necessary ports (15636, 15637 UDP)
- **Scheduled Task:** Runs as SYSTEM account with highest privileges (necessary for server startup)
- **Passwords:** Server password stored in plain text in config files — use filesystem ACLs to restrict access
- **Network:** Consider using Hyper-V NAT or external switch with port forwarding for additional control
- **Backups:** Game saves stored in plain text — consider encrypting backup archives for sensitive worlds
- **Updates:** Server updates pulled anonymously from Steam (no credentials stored)
- **Logging:** Detailed audit trail in `ManagementLogs/` for troubleshooting and monitoring

**Detailed security information:** See [SECURITY.MD](SECURITY.MD) for comprehensive security policy, best practices, and vulnerability reporting.

---

## 📦 Requirements

### Platform Compatibility

**✅ Tested and Supported:**

- Windows 11 Pro (build 22000+)
- Windows Server 2022
- Hyper-V virtualization
- PowerShell 5.1 (built-in)

**❌ Not Supported:**

- Windows 10 (may work but untested)
- Windows Home editions (no Hyper-V)
- WSL/Linux environments
- Docker containers
- PowerShell Core/7+ (not tested, may work)
- Non-Windows platforms

### Guest VM Requirements

- **OS:** Windows 11 Pro (build 22000 or later)
- **CPU:** 4 cores minimum (Enshrouded recommendation)
- **RAM:** 16 GB minimum (Enshrouded recommendation: 16+ GB)
- **Disk:** 20 GB free space (10 GB server + 5 GB backups + 5 GB buffer)
- **Network:** External or NAT network adapter with internet access
- **PowerShell:** 5.1 (built-in)

### Host Requirements

- **OS:** Windows 11 Pro with Hyper-V enabled
- **CPU:** Support for hardware virtualization (Intel VT-x / AMD-V)
- **RAM:** Sufficient to allocate 16 GB to guest (24+ GB host total recommended)
- **Disk:** NVMe/SSD recommended for VM storage
- **Network:** Configured Hyper-V virtual switch (External or NAT)

### Software Dependencies (Installed Automatically)

- **SteamCMD** — Downloaded by `1-Install-Dependencies.ps1`
- **Visual C++ Redistributable** — Checked/installed by `1-Install-Dependencies.ps1`

## ⚠️ Known Limitations

### Technical Limitations

1. **Windows 11 Pro Required**
   - Hyper-V not available on Home editions
   - Professional/Enterprise licensing needed

2. **No Cross-Platform Support**
   - Scripts are Windows-specific (no Linux/macOS)
   - Uses Windows-only cmdlets (Hyper-V, NetFirewall)

3. **PowerShell 5.1 Only**
   - Not tested with PowerShell Core/7+
   - May have compatibility issues on non-Windows PowerShell

4. **Manual VM Management**
   - No automatic VM creation
   - Host scripts require manual execution (no remoting)
   - VM must be configured before running scripts

5. **Single Server Instance**
   - Scripts assume one server per VM
   - No multi-instance support
   - Hardcoded paths in configuration

6. **No Web Interface**
   - All management via PowerShell scripts
   - No GUI or web dashboard
   - Command-line only

7. **Limited Monitoring**
   - Basic health checks only
   - No performance metrics or alerting
   - Manual log review required

8. **Backup Limitations**
   - No incremental backups (full ZIP archives only)
   - No automated backup scheduling
   - Manual cleanup of old backups/checkpoints

### Security Limitations

1. **Plaintext Password Storage**
   - Configuration file stores password unencrypted
   - Mitigate with NTFS permissions (see [SECURITY.MD](SECURITY.MD))

2. **No Built-in Authentication**
   - Scripts don't implement user authentication
   - Relies on Windows user account security
   - SSH/remote access must be configured separately

3. **No Intrusion Detection**
   - No monitoring for malicious activity
   - User responsible for security monitoring

4. **Administrator Privileges Required**
   - Most scripts need elevation
   - Can't run in restricted environments

### Game Server Limitations

1. **Enshrouded-Specific**
   - Scripts tailored for Enshrouded game server
   - Not generalizable to other games without modification

2. **Steam Account Not Required**
   - Uses anonymous SteamCMD login
   - No Steam account features (workshop, achievements)

3. **No Mod Support**
   - No built-in mod management
   - Manual mod installation required

4. **Port Configuration**
   - Default ports 15636/15637
   - Changing ports requires config + firewall rule updates

### Operational Limitations

1. **No Automatic Failover**
   - Server crashes require manual restart
   - Scheduled task provides auto-start on boot only

2. **No Load Balancing**
   - Single server instance per VM
   - No clustering or horizontal scaling

3. **Limited Update Control**
   - SteamCMD always pulls latest version
   - No version pinning or rollback
   - May break on game updates

4. **English-Only Documentation**
   - All docs and comments in English
   - Scripts output in English

### Workarounds and Mitigation

Many limitations can be addressed:

- **Monitoring:** Integrate with external tools (PRTG, Nagios)
- **Web Interface:** Add separate web frontend
- **Automation:** Use Windows Task Scheduler for backups
- **Multi-instance:** Deploy multiple VMs with different configs
- **Authentication:** Implement PowerShell Remoting with certificates

See [CONTRIBUTING.MD](CONTRIBUTING.MD) if you'd like to help address these limitations!

---

## 🤝 Contributing

Contributions are welcome! This project serves as educational material and a practical tool.

**We welcome:**

- 🐛 Bug fixes and error handling improvements
- 📚 Documentation enhancements and translations
- ✅ Additional test coverage
- 🎨 Code quality and style improvements
- 💡 New features that maintain simplicity
- 🔒 Security improvements

**Guidelines:**

- Maintain PowerShell 5.1 compatibility (no external dependencies)
- Follow existing code style (see [CONTRIBUTING.MD](CONTRIBUTING.MD))
- Include tests for new features
- Update documentation (README and Spec.MD)
- Keep educational value (code should teach)

**Before contributing:**

1. Read [CONTRIBUTING.MD](CONTRIBUTING.MD) for detailed guidelines
2. Check existing issues and PRs to avoid duplicates
3. Open an issue to discuss major changes first
4. Test your changes with Pester: `Invoke-Pester -Path .\tests\`

**Code of Conduct:** Be respectful, constructive, and collaborative. This is a learning environment.

---

## 📝 License

**MIT License** - See [LICENSE](LICENSE) file for full text.

Copyright (c) 2026 Enshrouded Server Management Project Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

**The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.**

**THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.** See LICENSE file for complete terms.

### Third-Party Trademarks

- **Enshrouded™** is a trademark of Keen Games GmbH
- **Steam®** is a trademark of Valve Corporation
- **Windows®** is a trademark of Microsoft Corporation
- **Hyper-V®** is a trademark of Microsoft Corporation

**Disclaimer:** This project is not affiliated with, endorsed by, or sponsored by Keen Games GmbH, Valve Corporation, or Microsoft Corporation. All trademarks are property of their respective owners.

### Game Server Hosting Compliance

When using this software to host Enshrouded game servers, you must comply with:

- [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/)
- Enshrouded End User License Agreement (EULA)
- Keen Games GmbH Terms of Service
- Applicable local laws and regulations

**This software does not:**

- Modify game client or server files
- Bypass DRM or authentication mechanisms
- Redistribute copyrighted game content
- Violate Steam API Terms of Use

Users are solely responsible for ensuring their server hosting activities comply with all applicable terms and laws.

---

## 📚 Additional Resources

- **GitHub Repository:** <https://github.com/GrandDay/Enshrouded_Server_Management>
- **Complete Specification:** See [docs/Spec.MD](docs/Spec.MD) for detailed technical documentation
- **SteamCMD Documentation:** <https://developer.valvesoftware.com/wiki/SteamCMD>
- **Enshrouded Official:** <https://enshrouded.com/>
- **Hyper-V Documentation:** <https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/>
- **PowerShell Documentation:** <https://docs.microsoft.com/en-us/powershell/>

---

## 🆘 Support

### Logs Location

- **Management Logs:** `C:\EnshroudedServer\ManagementLogs\YYYY-MM-DD.log`
- **Server Logs:** `C:\EnshroudedServer\logs\*.log`
- **Windows Event Log:** Application log, source `PowerShell`

### Getting Help

1. Check [Troubleshooting](#-troubleshooting) section above
2. Review management logs for error messages
3. Run `4-Health-Check.ps1` for diagnostic output
4. Check [docs/Spec.MD](docs/Spec.MD) for detailed technical documentation

---

**Project Status:** ✅ Ready for Educational/Personal Use  
**Last Updated:** February 23, 2026  
**Version:** 1.0  
**License:** MIT License  
**Contributing:** See [CONTRIBUTING.MD](CONTRIBUTING.MD)  
**Security:** See [SECURITY.MD](SECURITY.MD)

