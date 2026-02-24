# Enshrouded Dedicated Server — Windows PowerShell Management

> **Summative Project:** Automated PowerShell workflow for managing an Enshrouded dedicated game server on Windows 11 Pro / Hyper-V

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20Pro-0078D6.svg)](https://www.microsoft.com/windows)
[![Hyper-V](https://img.shields.io/badge/Hypervisor-Hyper--V-00BCF2.svg)](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/)

A complete, production-ready PowerShell automation suite that replaces manual server management with scripted workflows. Adapted from the existing Ubuntu Server + Wine + systemd model to native Windows using PowerShell 5.1.

---

## 🎯 Quick Start

### Prerequisites

- **Host:** Windows 11 Pro with Hyper-V enabled
- **Guest VM:** Fresh Windows 11 Pro installation
- **PowerShell:** 5.1 (built-in, no installation needed)
- **Network:** VM configured with external network access
- **Disk Space:** Minimum 10 GB free space on guest VM

### Installation (5 Minutes)

1. **Clone the repository to the guest VM:**
   ```powershell
   cd C:\
   git clone <repository-url> EnshroudedServerManagement
   cd EnshroudedServerManagement
   ```

2. **Copy configuration template:**
   ```powershell
   Copy-Item .\config\EnshroudedServerConfig.json C:\EnshroudedServer\EnshroudedServerConfig.json
   ```

3. **Edit configuration (optional):**
   ```powershell
   notepad C:\EnshroudedServer\EnshroudedServerConfig.json
   ```
   *(Defaults work for most setups)*

4. **Run automated setup:**
   ```powershell
   .\scripts\guest\0-Initial-Setup.ps1
   ```
   *(This installs SteamCMD, downloads the server, and configures everything)*

5. **Setup auto-start (optional):**
   ```powershell
   .\scripts\guest\8-Setup-ScheduledTask.ps1
   ```

6. **Start playing:**
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

### Guest VM Operations (Run inside the VM)

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

### Host Operations (Run on Hyper-V host)

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

## 🔄 Common Workflows

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

## 🛠️ Troubleshooting

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

4. Check Steam service status: https://steamstat.us/

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

## 🧪 Testing

### Running Tests

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
- Integration test markers

### Manual Integration Testing

See [docs/Spec.MD](docs/Spec.MD) section "Testing Strategy" for complete manual integration test checklist.

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

- **Firewall:** Scripts configure Windows Firewall to allow only necessary ports (15636, 15637 UDP)
- **Scheduled Task:** Runs as SYSTEM account with highest privileges (necessary for server startup)
- **Passwords:** Server password stored in plain text in config files — use filesystem ACLs to restrict access
- **Network:** Consider using Hyper-V NAT or external switch with port forwarding for additional control
- **Backups:** Game saves stored in plain text — consider encrypting backup archives for sensitive worlds
- **Updates:** Server updates pulled anonymously from Steam (no credentials stored)

---

## 📦 Requirements

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

---

## 🤝 Contributing

This is a summative project for educational purposes. Contributions welcome for:

- Bug fixes
- Performance improvements
- Documentation enhancements
- Additional test coverage
- PowerShell best practices

Please maintain compatibility with PowerShell 5.1 and follow existing code style.

---

## 📝 License

This project is provided for educational and personal use.

Enshrouded is a trademark of Keen Games GmbH. This project is not affiliated with or endorsed by Keen Games GmbH or Steam/Valve Corporation.

---

## 📚 Additional Resources

- **Complete Specification:** See [docs/Spec.MD](docs/Spec.MD) for detailed technical documentation
- **SteamCMD Documentation:** https://developer.valvesoftware.com/wiki/SteamCMD
- **Enshrouded Official:** https://enshrouded.com/
- **Hyper-V Documentation:** https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/
- **PowerShell Documentation:** https://docs.microsoft.com/en-us/powershell/

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

**Project Status:** ✅ Production Ready  
**Last Updated:** February 23, 2026  
**Version:** 1.0
