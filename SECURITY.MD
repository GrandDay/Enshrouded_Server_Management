# Security Policy

## 🔒 Security Considerations

This project automates Windows server management and game server operations. While designed with security in mind, users must understand the security implications.

## ⚠️ Important Security Warnings

### Administrator Privileges

**Multiple scripts require administrator privileges:**
- Firewall rule creation/modification
- Windows Scheduled Task configuration
- System-wide directory creation
- Network configuration changes

**Risk:** Scripts running as Administrator have full system access. Always review script contents before execution.

**Mitigation:**
- Review all scripts before running
- Use dedicated VM for game server (isolation)
- Don't run on production systems
- Audit `ManagementLogs/` regularly

### Firewall Configuration

**Scripts automatically create Windows Firewall rules:**
- Opens UDP ports 15636 (game) and 15637 (query)
- Rules apply to all network profiles (Domain, Private, Public)

**Risk:** Exposed game server ports are publicly accessible if VM has external network adapter.

**Mitigation:**
- Use Hyper-V NAT or Internal switch for testing
- Use External switch only when ready for public access
- Consider changing default ports in configuration
- Review firewall rules: `Get-NetFirewallRule -DisplayName "*Enshrouded*"`
- Monitor network traffic for unexpected connections

### Plaintext Credentials

**Configuration file stores server password in plaintext:**
- `C:\EnshroudedServer\EnshroudedServerConfig.json` contains `Server.Password`

**Risk:** Anyone with file system access can read the server password.

**Mitigation:**
- Use strong server passwords
- Restrict NTFS permissions on configuration file:
  ```powershell
  $acl = Get-Acl "C:\EnshroudedServer\EnshroudedServerConfig.json"
  $acl.SetAccessRuleProtection($true, $false)
  $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }
  $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
  $acl.AddAccessRule($rule)
  Set-Acl "C:\EnshroudedServer\EnshroudedServerConfig.json" $acl
  ```
- Use empty password for public servers (no authentication)
- Don't reuse important passwords

### Scheduled Task Security

**Scripts 8 and 12 create scheduled tasks running as SYSTEM:**
- Highest privilege level
- Script 8: Automatic execution on boot ("Start Enshrouded Server")
- Script 12: Recurring restart at configurable interval ("Auto-Restart Enshrouded Server")
- No user interaction required

**Risk:** SYSTEM account has unrestricted access to local system.

**Mitigation:**
- Review task configuration: `Get-ScheduledTask -TaskName "Start Enshrouded Server"`
- Review restart task: `Get-ScheduledTask -TaskName "Auto-Restart Enshrouded Server"`
- Disable when not needed: `Disable-ScheduledTask -TaskName "Start Enshrouded Server"`
- Disable restart task: `Disable-ScheduledTask -TaskName "Auto-Restart Enshrouded Server"`
- Consider running as dedicated service account instead
- Audit task history regularly

### SteamCMD Downloads

**Scripts download and execute SteamCMD from Valve:**
- Downloads from `https://steamcdn-a.akamaihd.net/`
- No signature verification (Valve doesn't sign Windows binaries)

**Risk:** Man-in-the-middle attack could replace SteamCMD with malicious binary.

**Mitigation:**
- Use HTTPS (already implemented)
- Verify file size matches expected (~2-3 MB)
- Download from trusted network only
- Consider manually downloading and verifying SteamCMD once

### Network Exposure

**Game server binds to all network interfaces:**
- Listens on 0.0.0.0 (all IPs)
- UDP protocol (no connection state)
- Query port reveals server information

**Risk:** Server accessible from any network the VM is connected to.

**Mitigation:**
- Use Hyper-V network isolation
- Configure Windows Firewall scope to specific networks
- Use VPN for player access (Hamachi, ZeroTier, etc.)
- Monitor connection logs for suspicious activity
- Consider IP whitelisting for private servers

### Log Files

**Scripts create detailed logs:**
- `C:\EnshroudedServer\ManagementLogs\` contains operation history
- May include IP addresses, usernames, error messages
- Windows Event Log entries written to Application log (source: `EnshroudedServerManagement`)
- PowerShell transcript logs capture full session output

**Risk:** Logs may contain sensitive information if shared publicly.

**Mitigation:**
- Review logs before sharing for troubleshooting
- Redact IP addresses and usernames
- Use `Manage-TranscriptLogs` to rotate transcript files (default 30-day retention)
- Restrict permissions on `ManagementLogs\` directory

### Windows Event Log Integration

**Scripts optionally write to the Windows Application Event Log:**
- Event source: `EnshroudedServerManagement`
- Requires administrator privileges to create the event source
- Controlled by `Logging.EnableEventLogging` in configuration (default: disabled when config is unavailable)

**Risk:** Event Log API calls (`[System.Diagnostics.EventLog]::SourceExists()`) require admin privileges and can throw `SecurityException` on non-admin sessions.

**Mitigation:**
- Event logging defaults to disabled when the configuration file cannot be read
- Set `EnableEventLogging` to `false` in config if Event Log writes are not needed
- Event Log failures are caught silently and do not affect script operation

### Environment Auto-Detection

**`Get-EnvironmentType` queries system hardware via WMI to detect the hypervisor:**
- Reads `Win32_BIOS`, `Win32_SystemEnclosure`, `Win32_ComputerSystem`, `Win32_PnPEntity`
- Checks for Hyper-V Integration Services (`vmicheartbeat`)
- Checks for QEMU Guest Agent service

**Risk:** WMI queries expose hardware and manufacturer information. No data is transmitted externally.

**Mitigation:**
- All detection is local only (no network calls)
- Results are used solely for GPU configuration decisions
- Override auto-detection via `Environment.EnvironmentOverride` in config

### Diagnostic Scripts

**`Debug-SteamCMD.ps1` and `Diagnose-ServerCrash.ps1` perform deep system inspection:**
- Check executable architecture and DLL dependencies
- Scan Windows Event Viewer for application errors
- Query installed Visual C++ and DirectX runtimes
- Test SteamCMD connectivity with various app IDs

**Risk:** Diagnostic output may reveal system details (installed software, DLL paths, event log entries).

**Mitigation:**
- Only run diagnostics when troubleshooting issues
- Review output before sharing publicly
- Diagnostic scripts do not modify system state

## 🎓 Educational Context

**This project is designed for learning environments:**
- Lab VMs (isolated from production networks)
- Educational demonstrations
- Personal/hobby use

**Not recommended for:**
- Production game server hosting
- Enterprise environments
- Servers handling sensitive data
- Unattended public-facing servers

## 🐛 Reporting Security Vulnerabilities

**If you discover a security vulnerability:**

### ⚠️ DO NOT open a public GitHub issue

Instead, please report responsibly:

1. **Email:** [Create private security advisory on GitHub]
2. **Include:**
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if known)
3. **Allow reasonable time** for fix before public disclosure

### What qualifies as a security vulnerability?

✅ **Report these:**
- Remote code execution
- Privilege escalation beyond expected admin requirements
- SQL injection or similar injection attacks (if applicable)
- Credential exposure beyond documented plaintext config
- Unintended data exposure
- Bypass of security controls

❌ **Not security vulnerabilities:**
- Scripts require Administrator privileges (by design)
- Configuration file stores passwords in plaintext (documented limitation)
- Firewall rules open ports (intended functionality)
- Man-in-the-middle attacks on unencrypted protocols (user responsibility)

## 📜 Security Best Practices for Users

### Before Installation

- [ ] Create dedicated VM for game server (don't use personal/work VM)
- [ ] Ensure host machine has updated antivirus
- [ ] Verify Hyper-V network configuration (start with Internal/NAT switch)
- [ ] Read all scripts before executing
- [ ] Take VM checkpoint before running scripts

### During Installation

- [ ] Run scripts only in PowerShell sessions you initiated
- [ ] Review firewall rules created: `Get-NetFirewallRule -DisplayName "*Enshrouded*"`
- [ ] Check scheduled task configuration: `Get-ScheduledTask -TaskName "Start Enshrouded Server"`
- [ ] Verify only expected network ports are listening

### After Installation

- [ ] Change default server password if using authentication
- [ ] Enable Windows Update on guest VM
- [ ] Configure log rotation (manual cleanup)
- [ ] Regular VM checkpoints for rollback capability
- [ ] Monitor `ManagementLogs\` for suspicious activity
- [ ] Test disaster recovery (restore from backup)

### For Public Servers

- [ ] Use strong, unique server password
- [ ] Consider VPN access instead of direct internet exposure
- [ ] Enable Windows Defender on guest VM
- [ ] Regularly update server files (`5-Update-Server.ps1`)
- [ ] Monitor player connections for abuse
- [ ] Have backup strategy (both file and VM checkpoints)

## 🔐 Compliance and Legal

### Steam Subscriber Agreement

Running an Enshrouded dedicated server is subject to:
- **Steam Subscriber Agreement** - https://store.steampowered.com/subscriber_agreement/
- **Enshrouded EULA** and Terms of Service
- Ensure your server usage complies with Keen Games GmbH policies

**This project does not:**
- Modify game files
- Bypass DRM or authentication
- Violate Steam API terms
- Redistribute game content

### Privacy Considerations

**Server logs may contain:**
- Player IP addresses
- Player usernames
- Connection timestamps
- Chat messages (if game includes chat)

**If hosting public servers:**
- Inform players about data collection
- Comply with applicable privacy laws (GDPR, CCPA, etc.)
- Have data retention and deletion policy
- Don't share player data with third parties

## 📚 Additional Resources

- [Microsoft Security Best Practices](https://docs.microsoft.com/en-us/security/)
- [PowerShell Security Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/security/)
- [Hyper-V Security](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/best-practices/)
- [Windows Firewall Configuration](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-firewall/)

## 📅 Last Updated

March 10, 2026

---

**Remember:** Security is a shared responsibility. Review, understand, and monitor all automated operations. 🔒
