# Enshrouded Dedicated Server — PowerShell Automation

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011%20Pro-0078D6.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

PowerShell scripts that automate setting up and managing an [Enshrouded](https://enshrouded.com/) dedicated game server on a Windows 11 Pro virtual machine.

**This is a class project** I built as a summative lab demonstrating PowerShell automation and Infrastructure as Code. I'm sharing it here for accountability and in case anyone else finds it useful. It targets a **fresh Windows VM with no pre-existing dependencies** — everything needed gets installed by the scripts.

> **⚠️ Review [SECURITY.MD](SECURITY.MD) before deploying.** These scripts run as Administrator, modify firewall rules, and create scheduled tasks.

---

## How It Works

The scripts walk you through going from a blank Windows 11 Pro VM to a running Enshrouded game server:

1. **Install dependencies** — SteamCMD and Visual C++ Redistributable are downloaded and installed automatically
2. **Download server** — SteamCMD pulls the Enshrouded dedicated server files (~2-3 GB)
3. **Configure** — A JSON config file controls server name, ports, player slots, and backup settings
4. **Run** — Start/stop the server, check health, update, and back up game files with individual scripts
5. **Optional** — Auto-start on boot via a Windows Scheduled Task, convenience PowerShell aliases, automatic scheduled restarts

All scripts use PowerShell 5.1 (built into Windows 11) with zero external module dependencies. Configuration is driven by a single JSON file. Logs go to `C:\EnshroudedServer\ManagementLogs\`.

For detailed technical documentation, see [docs/Spec.MD](docs/Spec.MD).

---

## Requirements

| Requirement | Details |
|-------------|---------|
| **VM OS** | Windows 11 Pro (build 22000+) — any hypervisor (Proxmox, VMware, VirtualBox, Hyper-V) or bare metal |
| **PowerShell** | 5.1 (built into Windows 11, no install needed) |
| **VM Resources** | 4+ CPU cores, 16+ GB RAM, 40+ GB disk |
| **Network** | Internet access for SteamCMD downloads |
| **Disk Space** | 20+ GB free on guest VM |
| **Privileges** | Administrator (for firewall rules, scheduled tasks, directory creation) |

Dependencies installed automatically by the scripts: **SteamCMD**, **Visual C++ Redistributable 2015-2022 x64**.

---

## Quick Start

### Installation (~15-20 min)

```powershell
# 1. Clone the repo inside your guest VM (run as Administrator)
cd C:\
git clone https://github.com/GrandDay/Enshrouded_Server_Management.git EnshroudedServerManagement
cd EnshroudedServerManagement

# 2. Run automated setup (installs dependencies, downloads server, configures)
.\scripts\guest\0-Initial-Setup.ps1
```

**⏳ The server download takes 10-15 minutes** on typical broadband.

If SteamCMD fails with a "No subscription" error, the dedicated server may require authentication. You can still test the automation workflow:

```powershell
.\scripts\guest\1-Install-Dependencies.ps1     # Install dependencies only
.\scripts\guest\2-Download-Server-Mock.ps1      # Create mock server files
.\scripts\guest\3-Configure-Server.ps1          # Configure
```

### Verify Installation

```powershell
.\scripts\guest\9-Start-Server.ps1
Start-Sleep -Seconds 30
.\scripts\guest\4-Health-Check.ps1       # Should show all checks passing
```

### Optional Setup

```powershell
.\scripts\guest\8-Setup-ScheduledTask.ps1    # Auto-start server on boot
.\scripts\guest\12-Schedule-Restart.ps1      # Auto-restart every 12 hours
.\scripts\guest\6-Setup-Alias.ps1            # Add "Update-Enshrouded" alias
```

---

## Project Structure

```
├── scripts/
│   ├── guest/                          # Run inside the Windows 11 Pro VM
│   │   ├── Common-Functions.ps1        # Shared logging and utility functions
│   │   ├── 0-Initial-Setup.ps1         # Master setup (runs 1, 2, 3)
│   │   ├── 1-Install-Dependencies.ps1  # SteamCMD + VC++ Redist + firewall
│   │   ├── 2-Download-Server.ps1       # Download server via SteamCMD
│   │   ├── 2-Download-Server-Mock.ps1  # Mock server files (for testing)
│   │   ├── 3-Configure-Server.ps1      # Apply JSON config to server
│   │   ├── 4-Health-Check.ps1          # Check process, ports, logs
│   │   ├── 5-Update-Server.ps1         # Stop → update → restart
│   │   ├── 6-Setup-Alias.ps1           # PowerShell profile alias
│   │   ├── 7-Backup-GameFiles.ps1      # Timestamped ZIP + rotation
│   │   ├── 8-Setup-ScheduledTask.ps1   # Auto-start on boot
│   │   ├── 9-Start-Server.ps1          # Start server process
│   │   ├── 10-Stop-Server.ps1          # Graceful shutdown
│   │   ├── 11-Restart-Server.ps1       # Restart server (stop, update, start)
│   │   ├── 12-Schedule-Restart.ps1     # Schedule automatic restarts
│   │   ├── Debug-SteamCMD.ps1          # SteamCMD connectivity diagnostics
│   │   └── Diagnose-ServerCrash.ps1    # Server crash diagnostics
├── config/
│   └── EnshroudedServerConfig.json     # Configuration template
├── tests/
│   ├── Config.Tests.ps1                # Config file validation
│   ├── Scripts.Tests.ps1               # Script quality/syntax checks
│   └── Functional.Tests.ps1            # Functional + integration tests
├── docs/
│   └── Spec.MD                         # Full technical specification
└── README.MD
```

---

## Configuration

All scripts read from a central JSON config file at `C:\EnshroudedServer\EnshroudedServerConfig.json`. A template is included in `config/`.

| Setting | Default | Description |
|---------|---------|-------------|
| `Paths.SteamCMD` | `C:\SteamCMD` | SteamCMD installation directory |
| `Paths.ServerInstall` | `C:\EnshroudedServer` | Server installation directory |
| `Paths.Backup` | `C:\EnshroudedServer\Backups` | Backup archive directory |
| `Paths.ManagementLogs` | `C:\EnshroudedServer\ManagementLogs` | Log file directory |
| `Server.Name` | VM-Enshrouded | Server name visible in server browser |
| `Server.SlotCount` | 4 | Max players (1-16) |
| `Server.GamePort` | 15636 | UDP game traffic port |
| `Server.QueryPort` | 15637 | UDP query port |
| `Backup.RetentionCount` | 5 | Number of backup archives to keep |
| `Restart.IntervalHours` | 12 | Hours between automatic server restarts |
| `Logging.Enabled` | true | Enable file logging |
| `Logging.EnableEventLogging` | true | Write to Windows Event Log (requires admin) |

After changing configuration, run `3-Configure-Server.ps1` to apply and restart the server.

---

## Usage

### Daily Operations

```powershell
# Start/stop server
.\scripts\guest\9-Start-Server.ps1
.\scripts\guest\10-Stop-Server.ps1

# Health check
.\scripts\guest\4-Health-Check.ps1

# Update server
.\scripts\guest\5-Update-Server.ps1

# Backup game files
.\scripts\guest\7-Backup-GameFiles.ps1

# Restart server (stop, update, start)
.\scripts\guest\11-Restart-Server.ps1

# View today's logs
Get-Content C:\EnshroudedServer\ManagementLogs\$(Get-Date -Format 'yyyy-MM-dd').log -Tail 50
```

### Diagnostic Scripts

```powershell
# Debug SteamCMD download issues
.\scripts\guest\Debug-SteamCMD.ps1

# Diagnose server crashes (exit code -1, missing DLLs, etc.)
.\scripts\guest\Diagnose-ServerCrash.ps1
```

---

## Testing

This project uses [Pester](https://pester.dev/) for automated testing. Tests are designed to run safely on any workstation — they don't require the game server to be installed.

```powershell
# Install Pester (if needed)
Install-Module -Name Pester -Force -SkipPublisherCheck

# Run all tests
Invoke-Pester -Path .\tests\

# Run a specific test suite
Invoke-Pester -Path .\tests\Config.Tests.ps1 -Output Detailed
Invoke-Pester -Path .\tests\Scripts.Tests.ps1 -Output Detailed
Invoke-Pester -Path .\tests\Functional.Tests.ps1 -Output Detailed
```

### Test Suites

| Suite | What It Tests |
|-------|---------------|
| **Config.Tests.ps1** | JSON syntax, required keys/sections, port ranges, path formats, default values |
| **Scripts.Tests.ps1** | PowerShell syntax (AST parsing), comment-based help, logging standards, error handling, code style |
| **Functional.Tests.ps1** | Common function behavior (logging, config loading, process detection, byte formatting), directory/archive operations, file rotation. Integration and E2E tests are present but skipped (require actual server). |

---

## Troubleshooting

### Common Issues

**SteamCMD "No subscription" error:**
The Enshrouded dedicated server app may require authentication. Use `2-Download-Server-Mock.ps1` to test the workflow, or try an authenticated SteamCMD login.

**Server crashes immediately (exit code -1):**
Usually means missing GPU acceleration or graphics libraries in the VM. Run `Diagnose-ServerCrash.ps1` for specifics. Ensure VC++ Redistributable is installed. Some VM platforms (Hyper-V without GPU-PV) may not support the server.

**Health check fails:**
Wait 30+ seconds after starting the server before running the health check. If ports aren't listening, check Windows Firewall rules: `Get-NetFirewallRule -DisplayName "*Enshrouded*"`.

**Pester tests fail or hang:**
Ensure you have Pester 5.x installed (`Install-Module Pester -Force -SkipPublisherCheck`). Tests are designed to run on any machine without admin privileges.

### Logs

| Log | Location |
|-----|----------|
| Management logs | `C:\EnshroudedServer\ManagementLogs\YYYY-MM-DD.log` |
| Server logs | `C:\EnshroudedServer\logs\*.log` |
| Windows Event Log | Application log, source `EnshroudedServerManagement` |

---

## Known Limitations

- **Windows 11 Pro required** — tested on Pro edition; Home may work but is unsupported
- **PowerShell 5.1 only** — not tested with PowerShell 7+
- **No cross-platform support** — Windows-specific cmdlets throughout
- **Single server instance per VM** — no multi-instance support
- **Plaintext password storage** — server passwords in config are unencrypted (see [SECURITY.MD](SECURITY.MD))
- **No web interface** — all management is command-line
- **Full backups only** — no incremental/differential backups
- **No automated backup scheduling** — backups are manual (or add your own scheduled task)
- **SteamCMD pulls latest version** — no version pinning or rollback
- **Server may not run in all VMs** — GPU/graphics dependencies can cause crashes in some hypervisors
- **Admin privileges required** — for firewall rules, scheduled tasks, and directory creation
- **LAN/external network access is user-managed** — the scripts configure Windows Firewall rules, but making the server reachable from other machines depends on your VM platform's network setup (bridged adapter, port forwarding, etc.)

---

## Security

See [SECURITY.MD](SECURITY.MD) for the full security policy. Key points:

- Scripts run as **Administrator** with full system access — review them before running
- **Firewall rules** are created automatically (UDP 15636/15637)
- **Scheduled task** runs as SYSTEM at highest privilege (auto-start and auto-restart)
- **Passwords** are stored in plaintext in the server config file
- **SteamCMD** is downloaded over HTTPS but binaries aren't signature-verified
- Use a **dedicated VM** — don't run these on a production or personal machine

---

## License

**MIT License** — see [LICENSE](LICENSE).

This project is not affiliated with Keen Games GmbH, Valve Corporation, or Microsoft Corporation. Enshrouded™, Steam®, and Windows® are trademarks of their respective owners. Comply with the [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/) and Enshrouded's terms when hosting servers.

---

## Contributing

Contributions welcome — see [CONTRIBUTING.MD](CONTRIBUTING.MD). Please maintain PowerShell 5.1 compatibility and include Pester tests for new features.

---

## Resources

- [docs/Spec.MD](docs/Spec.MD) — Full technical specification
- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [Pester Testing Framework](https://pester.dev/)

---

**Last Updated:** March 10, 2026 | **License:** MIT | **Security:** [SECURITY.MD](SECURITY.MD)
