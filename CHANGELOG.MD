# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-23

### 🎉 Initial Public Release

First public release of the Enshrouded Server Management automation suite.

#### Added - Core Features

**Documentation:**

- Comprehensive README.MD with 2000+ lines of documentation
- Complete technical specification (docs/Spec.MD)
- Pre-flight checklist for requirements validation
- Quick reference card for common operations
- Script success criteria for all operations
- Daily operations checklists (start/end session, weekly maintenance)
- Troubleshooting decision trees (server won't start, connectivity, backup/restore)
- Testing and validation guide with manual procedures
- MIT License (LICENSE file)
- Contributing guidelines (CONTRIBUTING.MD)
- Security policy and best practices (SECURITY.MD)

**Guest VM Scripts (11 scripts):**

- `0-Initial-Setup.ps1` - Master automation orchestrator
- `1-Install-Dependencies.ps1` - SteamCMD, VC++ Redistributable, firewall rules
- `2-Download-Server.ps1` - Enshrouded server download via SteamCMD
- `3-Configure-Server.ps1` - Apply configuration to server
- `4-Health-Check.ps1` - Comprehensive health validation (process, ports, logs)
- `5-Update-Server.ps1` - Stop, update, restart workflow
- `6-Setup-Alias.ps1` - PowerShell profile convenience alias
- `7-Backup-GameFiles.ps1` - Timestamped ZIP backups with rotation
- `8-Setup-ScheduledTask.ps1` - Auto-start on boot configuration
- `9-Start-Server.ps1` - Server process launcher
- `10-Stop-Server.ps1` - Graceful shutdown with timeout
- `Common-Functions.ps1` - Shared utilities (logging, config, admin check)

**Host Machine Scripts (2 scripts):**

- `Backup-VMCheckpoint.ps1` - Hyper-V snapshot creation
- `Hibernate-VM.ps1` - VM state save for resource management

**Configuration:**

- Centralized JSON configuration (`EnshroudedServerConfig.json`)
- Template with sensible defaults
- Supports server name, password, ports, slots, backup retention

**Testing:**

- Pester test framework integration
- `Config.Tests.ps1` - Configuration validation (16 tests)
- `Scripts.Tests.ps1` - Script quality standards (48 tests)
- `Functional.Tests.ps1` - Unit and integration tests (22+ tests)
- Manual validation procedures with 7-step checklist

**Logging:**

- Structured logging with Write-ServerLog function
- File-based logs in ManagementLogs/ directory
- Color-coded console output (INFO, WARN, ERROR, SUCCESS)
- Timestamped entries with script name

**Error Handling:**

- Try/catch blocks in all critical operations
- Graceful degradation where possible
- Detailed error messages with remediation guidance
- Non-zero exit codes on failure

#### Technical Details

**Platform:**

- Windows 11 Pro (build 22000+)
- PowerShell 5.1 (no external dependencies)
- Hyper-V virtualization
- Native Windows commands only

**Architecture:**

- Standalone PowerShell scripts (not a module)
- Guest/host script separation
- Configuration-driven design
- No hardcoded credentials

**Features:**

- Automated installation workflow
- Health monitoring
- Backup and restore capabilities
- Update management
- Auto-start on boot
- VM lifecycle management

#### Security

- Windows Firewall rule automation
- Scheduled task with SYSTEM privileges
- Plaintext password storage (documented limitation)
- Comprehensive security documentation
- Audit logging for all operations

#### Known Limitations

See README.MD "Known Limitations" section for complete list:

- Windows 11 Pro required (Hyper-V)
- No cross-platform support
- PowerShell 5.1 only
- Manual VM management
- Single server instance per VM
- No web interface
- Limited monitoring
- Plaintext password storage
- Administrator privileges required

#### Dependencies

**Installed Automatically:**

- SteamCMD (downloaded from Valve CDN)
- Visual C++ Redistributable 2015-2022 x64

**Built-in (No Installation):**

- PowerShell 5.1
- Hyper-V cmdlets
- NetFirewall cmdlets
- NetTCPIP cmdlets

---

## Release Notes

### Version 1.0.0 Highlights

✅ **Complete end-to-end automation** from fresh Windows VM to running game server  
✅ **Production-ready for educational/personal use** with comprehensive documentation  
✅ **Zero external dependencies** - pure PowerShell 5.1  
✅ **Extensive testing coverage** - automated and manual validation procedures  
✅ **Security-conscious design** - documented risks and mitigation strategies  

### Tested Environments

- Windows 11 Pro 22H2 (build 22621)
- Windows 11 Pro 23H2 (build 22631)
- Hyper-V on Windows 11 Pro
- PowerShell 5.1.22621

### Not Tested

- Windows 10 (may work but unsupported)
- Windows Server editions
- PowerShell Core 7+
- Non-Hyper-V virtualization (VMware, VirtualBox)

---

## Future Roadmap

**Potential Future Enhancements** (contributions welcome):

- [ ] PowerShell Core 7+ compatibility testing
- [ ] Windows Server 2022 compatibility validation
- [ ] Automated backup scheduling
- [ ] Performance monitoring and metrics
- [ ] Web-based dashboard
- [ ] Multi-instance support
- [ ] Discord/Slack integration for notifications
- [ ] Encrypted configuration file option
- [ ] Remote management via PowerShell Remoting
- [ ] Rollback to previous server version
- [ ] Health check API endpoint
- [ ] Prometheus metrics exporter

See [CONTRIBUTING.MD](CONTRIBUTING.MD) to help implement these features!

---

## Credits

**Original Development:** Summative lab project demonstrating PowerShell automation and Infrastructure as Code

**License:** MIT License - see [LICENSE](LICENSE)

**Trademarks:** Enshrouded™ is a trademark of Keen Games GmbH. This project is not affiliated with or endorsed by Keen Games GmbH, Valve Corporation, or Microsoft Corporation.

---

[1.0.0]: https://github.com/yourusername/enshrouded-server-management/releases/tag/v1.0.0
