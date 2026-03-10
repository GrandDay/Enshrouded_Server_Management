<#
.SYNOPSIS
    Common functions and utilities for Enshrouded server management scripts.

.DESCRIPTION
    This module provides shared functionality used across all Enshrouded server
    management scripts, including structured logging and utility functions.

.NOTES
    File Name  : Common-Functions.ps1
    Author     : Enshrouded Server Management Project
    Version    : 1.0
    Date       : 2026-02-23
#>

function Write-ServerLog {
    <#
    .SYNOPSIS
        Writes structured log entries to both file and console.
    
    .DESCRIPTION
        Provides consistent logging across all server management scripts with
        color-coded console output and structured file logging.
    
    .PARAMETER Message
        The log message to write.
    
    .PARAMETER Level
        The severity level of the log entry. Valid values: INFO, WARN, ERROR, SUCCESS
    
    .PARAMETER ScriptName
        The name of the calling script. Auto-detected if not provided.
    
    .EXAMPLE
        Write-ServerLog "Starting server installation..." -Level INFO
    
    .EXAMPLE
        Write-ServerLog "Server started successfully." -Level SUCCESS
    
    .EXAMPLE
        Write-ServerLog "Port 15636 not responding." -Level WARN
    
    .EXAMPLE
        Write-ServerLog "Failed to download: $($_.Exception.Message)" -Level ERROR
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory=$false)]
        [string]$ScriptName
    )
    
    # Auto-detect script name if not provided
    if (-not $ScriptName) {
        if ($PSCommandPath) {
            $ScriptName = Split-Path -Leaf $PSCommandPath
        } else {
            $ScriptName = "Interactive"
        }
    }
    
    # Load configuration for log path
    $configPath = "C:\EnshroudedServer\EnshroudedServerConfig.json"
    if (Test-Path $configPath) {
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $logDir = $config.Paths.ManagementLogs
        } catch {
            $logDir = "C:\EnshroudedServer\ManagementLogs"
        }
    } else {
        $logDir = "C:\EnshroudedServer\ManagementLogs"
    }
    
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        } catch {
            Write-Warning "Could not create log directory: $logDir"
            $logDir = $env:TEMP
        }
    }
    
    # Log file: one per day
    $logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').log"
    
    # Format: [TIMESTAMP] [SCRIPT] [LEVEL] Message
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$ScriptName] [$Level] $Message"
    
    # Write to file
    try {
        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Warning "Could not write to log file: $logFile"
    }
    
    # Write to Windows Event Log if enabled
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        $enableEventLogging = $config.Logging.EnableEventLogging
    } catch {
        $enableEventLogging = $false  # Default to disabled (requires admin privileges)
    }
    
    if ($enableEventLogging) {
        Write-EventLogEntry -Message $Message -Level $Level -ScriptName $ScriptName -ErrorAction SilentlyContinue
    }
    
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

function Write-EventLogEntry {
    <#
    .SYNOPSIS
        Writes log entries to Windows Application Event Log.
    
    .DESCRIPTION
        Writes structured entries to the Windows Application Event Log with
        appropriate severity levels mapped from script log levels.
    
    .PARAMETER Message
        The log message to write.
    
    .PARAMETER Level
        The severity level (INFO, WARN, ERROR, SUCCESS). Maps to EventLog levels.
    
    .PARAMETER ScriptName
        The name of the script that generated the log entry.
    
    .NOTES
        Requires administrator privileges. Entry source is "EnshroudedServerManagement"
    
    .EXAMPLE
        Write-EventLogEntry -Message "Server started" -Level SUCCESS -ScriptName "9-Start-Server.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory=$false)]
        [string]$ScriptName = "Unknown"
    )
    
    try {
        # Map script levels to EventLog severity levels
        $eventLevel = switch ($Level) {
            'INFO'    { [System.Diagnostics.EventLogEntryType]::Information }
            'SUCCESS' { [System.Diagnostics.EventLogEntryType]::Information }
            'WARN'    { [System.Diagnostics.EventLogEntryType]::Warning }
            'ERROR'   { [System.Diagnostics.EventLogEntryType]::Error }
            default   { [System.Diagnostics.EventLogEntryType]::Information }
        }
        
        # Ensure event source exists
        $eventSource = "EnshroudedServerManagement"
        $logName = "Application"
        
        if (-not ([System.Diagnostics.EventLog]::SourceExists($eventSource))) {
            # Create source if it doesn't exist (requires admin)
            [System.Diagnostics.EventLog]::CreateEventSource($eventSource, $logName)
        }
        
        # Format event message with timestamp and script name
        $eventMessage = "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [Script: $ScriptName] [$Level]`r`n$Message"
        
        # Write to Application Event Log
        $eventLog = New-Object System.Diagnostics.EventLog($logName)
        $eventLog.Source = $eventSource
        $eventLog.WriteEntry($eventMessage, $eventLevel, 1000)
    } catch {
        # Silently fail if Event Log writing fails (not critical)
        Write-Debug "Failed to write to Event Log: $($_.Exception.Message)"
    }
}

function Initialize-TranscriptLogging {
    <#
    .SYNOPSIS
        Initializes PowerShell transcript logging for the current session.
    
    .DESCRIPTION
        Starts a PowerShell transcript to capture all command history and output.
        Creates daily transcript files in the ManagementLogs directory.
        Only starts transcript if not already running (prevents nested transcripts).
    
    .OUTPUTS
        String - Path to transcript file being written to
    
    .EXAMPLE
        $transcriptPath = Initialize-TranscriptLogging
        Write-Host "Transcript recording to: $transcriptPath"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    # Check if transcript is already running
    if ($PSCommandPath) {
        $hostStatus = Get-Command -CommandType Cmdlet -Name 'Stop-Transcript' -ErrorAction SilentlyContinue
        if ($hostStatus -and (Test-TranscriptRunning)) {
            Write-Debug "Transcript already running in parent session."
            return $null
        }
    }
    
    try {
        # Load configuration for log path
        $configPath = "C:\EnshroudedServer\EnshroudedServerConfig.json"
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                $logDir = $config.Paths.ManagementLogs
            } catch {
                $logDir = "C:\EnshroudedServer\ManagementLogs"
            }
        } else {
            $logDir = "C:\EnshroudedServer\ManagementLogs"
        }
        
        # Ensure log directory exists
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # Create transcript file path with timestamp
        $transcriptFile = Join-Path $logDir "Transcript-$(Get-Date -Format 'yyyy-MM-dd').log"
        
        # Start transcript (append to daily file)
        Start-Transcript -Path $transcriptFile -Append -NoClobber -ErrorAction Stop | Out-Null
        
        Write-Debug "Transcript started at: $transcriptFile"
        return $transcriptFile
    } catch {
        Write-ServerLog "Failed to initialize transcript logging: $($_.Exception.Message)" -Level WARN
        return $null
    }
}

function Test-TranscriptRunning {
    <#
    .SYNOPSIS
        Tests if a PowerShell transcript is currently running.
    
    .OUTPUTS
        Boolean - $true if transcript is active, $false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    try {
        # If Stop-Transcript works without error, we're in a transcript session
        # We test by checking the shell's transcript state
        $transcriptPath = $null
        if ($PSVersionTable.PSVersion -ge "5.0") {
            # PowerShell 5.0+ has transcript info in the runspace
            $transcriptState = Get-History -ErrorAction SilentlyContinue
            return $false  # More reliable: just prevent nested transcripts by checking output stream
        }
        return $false
    } catch {
        return $false
    }
}

function Manage-TranscriptLogs {
    <#
    .SYNOPSIS
        Manages PowerShell transcript log rotation and cleanup.
    
    .DESCRIPTION
        Removes transcript log files older than the specified retention days (default 30).
        Should be called periodically to prevent disk space issues.
    
    .PARAMETER RetentionDays
        Number of days to retain transcript logs. Older logs are deleted.
        Default: 30 days
    
    .PARAMETER LogPath
        Path to the logs directory. Uses config path if not specified.
    
    .EXAMPLE
        Manage-TranscriptLogs -RetentionDays 30
    
    .EXAMPLE
        Manage-TranscriptLogs -LogPath "C:\EnshroudedServer\ManagementLogs" -RetentionDays 45
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$RetentionDays = 30,
        
        [Parameter(Mandatory=$false)]
        [string]$LogPath
    )
    
    try {
        # Determine log path
        if (-not $LogPath) {
            $configPath = "C:\EnshroudedServer\EnshroudedServerConfig.json"
            if (Test-Path $configPath) {
                try {
                    $config = Get-Content $configPath -Raw | ConvertFrom-Json
                    $LogPath = $config.Paths.ManagementLogs
                } catch {
                    $LogPath = "C:\EnshroudedServer\ManagementLogs"
                }
            } else {
                $LogPath = "C:\EnshroudedServer\ManagementLogs"
            }
        }
        
        if (-not (Test-Path $LogPath)) {
            Write-ServerLog "Transcript log path does not exist: $LogPath" -Level WARN
            return
        }
        
        # Find and remove transcript files older than retention period
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        $transcriptPattern = "Transcript-*.log"
        $oldTranscripts = Get-ChildItem -Path $LogPath -Filter $transcriptPattern -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        foreach ($transcript in $oldTranscripts) {
            try {
                Remove-Item -Path $transcript.FullName -Force -ErrorAction Stop
                Write-ServerLog "Removed old transcript log: $($transcript.Name)" -Level INFO
            } catch {
                Write-ServerLog "Failed to remove transcript log $($transcript.Name): $($_.Exception.Message)" -Level WARN
            }
        }
        
        if ($oldTranscripts.Count -eq 0) {
            Write-ServerLog "No transcript logs older than $RetentionDays days to clean up." -Level INFO
        }
    } catch {
        Write-ServerLog "Error managing transcript logs: $($_.Exception.Message)" -Level ERROR
    }
}

function Test-ServerProcess {
    <#
    .SYNOPSIS
        Tests if the Enshrouded server process is running.
    
    .DESCRIPTION
        Checks for the enshrouded_server process and returns process object if found.
    
    .OUTPUTS
        System.Diagnostics.Process or $null if not running
    
    .EXAMPLE
        $proc = Test-ServerProcess
        if ($proc) { Write-Host "Server running with PID: $($proc.Id)" }
    #>
    [CmdletBinding()]
    [OutputType([System.Diagnostics.Process])]
    param()
    
    Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
}

function Get-ServerConfig {
    <#
    .SYNOPSIS
        Loads the server management configuration file.
    
    .DESCRIPTION
        Reads and parses the EnshroudedServerConfig.json file, returning a
        PowerShell object with all configuration settings.
    
    .OUTPUTS
        PSCustomObject with configuration settings
    
    .EXAMPLE
        $config = Get-ServerConfig
        $serverPath = $config.Paths.ServerInstall
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath = "C:\EnshroudedServer\EnshroudedServerConfig.json"
    )
    
    if (-not (Test-Path $ConfigPath)) {
        Write-ServerLog "Configuration file not found: $ConfigPath" -Level ERROR
        throw "Configuration file not found: $ConfigPath"
    }
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        Write-ServerLog "Failed to parse configuration file: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Tests if the current PowerShell session has administrator privileges.
    
    .DESCRIPTION
        Checks if the current user is running with elevated (administrator) permissions.
    
    .OUTPUTS
        Boolean - $true if running as administrator, $false otherwise
    
    .EXAMPLE
        if (-not (Test-AdminPrivileges)) {
            Write-Error "This script requires administrator privileges."
            exit 1
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-EnvironmentType {
    <#
    .SYNOPSIS
        Detects the hypervisor/host environment type.
    
    .DESCRIPTION
        Automatically detects whether the system is running in Hyper-V, Proxmox, WSL, or bare metal.
        Returns the detected environment type along with confidence level.
        Respects user overrides stored in configuration.
    
    .OUTPUTS
        PSCustomObject with properties:
        - EnvironmentType (string): HyperV, Proxmox, WSL, or BareMetal
        - DetectionMethod (string): How the environment was determined
        - IsVM (boolean): Whether running in a virtual machine
        - Confidence (string): High, Medium, Low
    
    .EXAMPLE
        $env = Get-EnvironmentType
        Write-Host "Detected environment: $($env.EnvironmentType) ($($env.Confidence) confidence)"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    try {
        # First check for config override
        $configPath = "C:\EnshroudedServer\EnshroudedServerConfig.json"
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($config.Environment.EnvironmentOverride) {
                    Write-ServerLog "Using environment override from configuration: $($config.Environment.EnvironmentOverride)" -Level INFO
                    return @{
                        EnvironmentType   = $config.Environment.EnvironmentOverride
                        DetectionMethod   = "ConfigOverride"
                        IsVM              = $config.Environment.EnvironmentOverride -ne "BareMetal"
                        Confidence        = "UserSpecified"
                    } | ConvertTo-PSCustomObject
                }
            } catch {
                Write-Debug "Failed to read environment override from config: $($_.Exception.Message)"
            }
        }
        
        # Check for WSL
        if (Test-Path "/proc/version" -ErrorAction SilentlyContinue -PathType Leaf) {
            return @{
                EnvironmentType   = "WSL"
                DetectionMethod   = "ProcVersion"
                IsVM              = $true
                Confidence        = "High"
            } | ConvertTo-PSCustomObject
        }
        
        # Check for WSL environment variables
        if ($env:WSL_DISTRO_NAME -or $env:WSL_INTEROP) {
            return @{
                EnvironmentType   = "WSL"
                DetectionMethod   = "EnvironmentVariable"
                IsVM              = $true
                Confidence        = "High"
            } | ConvertTo-PSCustomObject
        }
        
        # Check for Hyper-V Integration Services (RUNNING - only in guests)
        # Note: These services exist in guests but not on Hyper-V hosts
        try {
            $hypervService = Get-Service -Name "vmicheartbeat" -ErrorAction SilentlyContinue
            if ($hypervService -and $hypervService.Status -eq "Running") {
                return @{
                    EnvironmentType   = "HyperV"
                    DetectionMethod   = "HyperVIntegrationService"
                    IsVM              = $true
                    Confidence        = "High"
                } | ConvertTo-PSCustomObject
            }
        } catch {
            Write-Debug "Hyper-V service check failed: $($_.Exception.Message)"
        }
        
        # Check for Hyper-V via WMI (Hyper-V-specific BIOS/System info in guests)
        # This checks for signs of being IN a Hyper-V VM, not just having Hyper-V installed
        try {
            $biosMfg = (Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue).Manufacturer
            if ($biosMfg -like "*Hyper-V*") {
                return @{
                    EnvironmentType   = "HyperV"
                    DetectionMethod   = "WMIBIOSManufacturer"
                    IsVM              = $true
                    Confidence        = "High"
                } | ConvertTo-PSCustomObject
            }
        } catch {
            Write-Debug "WMI BIOS check failed: $($_.Exception.Message)"
        }
        
        # Check for Hyper-V via system enclosure (more reliable than CPU brand)
        try {
            $systemEnclosure = Get-WmiObject -Class Win32_SystemEnclosure -ErrorAction SilentlyContinue
            if ($systemEnclosure.Manufacturer -like "*Hyper-V*") {
                return @{
                    EnvironmentType   = "HyperV"
                    DetectionMethod   = "WMISystemEnclosure"
                    IsVM              = $true
                    Confidence        = "High"
                } | ConvertTo-PSCustomObject
            }
        } catch {
            Write-Debug "WMI system enclosure check failed: $($_.Exception.Message)"
        }
        
        # Check for Proxmox/QEMU indicators (RUNNING services/devices, not just installed)
        try {
            # Check for QEMU guest agent service
            $qemuService = Get-Service -Name "QEMU Guest Agent" -ErrorAction SilentlyContinue
            if ($qemuService -and $qemuService.Status -eq "Running") {
                return @{
                    EnvironmentType   = "Proxmox"
                    DetectionMethod   = "QEMUGuestAgent"
                    IsVM              = $true
                    Confidence        = "High"
                } | ConvertTo-PSCustomObject
            }
        } catch {
            Write-Debug "QEMU service check failed: $($_.Exception.Message)"
        }
        
        # Check for QEMU/Proxmox devices
        try {
            $qemuDevice = Get-WmiObject -Class Win32_PnPEntity -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*QEMU*" -or $_.Description -like "*Virtio*" }
            if ($qemuDevice) {
                return @{
                    EnvironmentType   = "Proxmox"
                    DetectionMethod   = "QEMUDevice"
                    IsVM              = $true
                    Confidence        = "Medium"
                } | ConvertTo-PSCustomObject
            }
        } catch {
            Write-Debug "QEMU device check failed: $($_.Exception.Message)"
        }
        
        # Check for generic VM indicators in WMI
        try {
            $computerSystem = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($computerSystem.Model -like "*virtual*" -or $computerSystem.Manufacturer -in @("QEMU", "Proxmox", "innotek GmbH")) {
                # If model/manufacturer indicates VM but we haven't identified which type yet, it's likely Proxmox
                return @{
                    EnvironmentType   = "Proxmox"
                    DetectionMethod   = "ComputerSystemWMI"
                    IsVM              = $true
                    Confidence        = "Low"
                } | ConvertTo-PSCustomObject
            }
        } catch {
            Write-Debug "ComputerSystem WMI check failed: $($_.Exception.Message)"
        }
        
        # Default to BareMetal if no VM indicators found
        return @{
            EnvironmentType   = "BareMetal"
            DetectionMethod   = "NoVMIndicators"
            IsVM              = $false
            Confidence        = "High"
        } | ConvertTo-PSCustomObject
    } catch {
        Write-ServerLog "Error during environment detection: $($_.Exception.Message)" -Level WARN
        return @{
            EnvironmentType   = "BareMetal"
            DetectionMethod   = "ErrorFallback"
            IsVM              = $false
            Confidence        = "Low"
        } | ConvertTo-PSCustomObject
    }
}

function ConvertTo-PSCustomObject {
    <#
    .SYNOPSIS
        Converts hashtable to PSCustomObject.
    
    .DESCRIPTION
        Helper function to convert hashtable pipeline input to PSCustomObject.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [hashtable]$InputObject
    )
    
    [PSCustomObject]$InputObject
}

function Set-GPUConfiguration {
    <#
    .SYNOPSIS
        Determines GPU configuration flags based on environment type.
    
    .DESCRIPTION
        Returns appropriate GPU-related launch flags for the Enshrouded server
        based on the detected or specified environment. Hyper-V defaults to CPU-only
        mode, while bare metal and Proxmox allow GPU initialization.
    
    .PARAMETER EnvironmentType
        The environment type (HyperV, Proxmox, BareMetal, WSL).
        If not provided, auto-detects via Get-EnvironmentType.
    
    .OUTPUTS
        PSCustomObject with properties:
        - Flags (string[]): Array of launch flags to pass to server executable
        - GPUEnabled (boolean): Whether GPU is enabled
        - SuggestedFlags (string): Human-readable flag description
        - Notes (string): Additional configuration notes
    
    .EXAMPLE
        $gpuConfig = Set-GPUConfiguration -EnvironmentType "HyperV"
        $serverArgs = @("enshrouded_server.exe") + $gpuConfig.Flags
        & ([string]::Join(' ', $serverArgs))
    
    .EXAMPLE
        $gpuConfig = Set-GPUConfiguration
        Write-ServerLog "GPU Configuration: $($gpuConfig.SuggestedFlags)" -Level INFO
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('HyperV', 'Proxmox', 'BareMetal', 'WSL')]
        [string]$EnvironmentType
    )
    
    try {
        # Auto-detect if not specified
        if (-not $EnvironmentType) {
            $envInfo = Get-EnvironmentType
            $EnvironmentType = $envInfo.EnvironmentType
            Write-ServerLog "Auto-detected environment: $EnvironmentType" -Level INFO
        }
        
        # Determine GPU configuration per environment
        $gpuConfig = switch ($EnvironmentType) {
            "HyperV" {
                # Hyper-V: Disable GPU (GPU passthrough is problematic in Hyper-V)
                # Enshrouded may not have explicit GPU disable flag, so we note CPU-only assumption
                @{
                    Flags           = @()  # Empty flags; server will auto-detect and use CPU-only if no GPU
                    GPUEnabled      = $false
                    SuggestedFlags  = "CPU-only mode (GPU disabled for Hyper-V)"
                    Notes           = "Hyper-V has limited GPU passthrough support. Server will run in CPU-only mode."
                }
            }
            "Proxmox" {
                # Proxmox: GPU acceleration typically not utilized for this project; CPU-only mode
                @{
                    Flags           = @()  # CPU-only mode for Proxmox guests
                    GPUEnabled      = $false
                    SuggestedFlags  = "CPU-only mode (Proxmox guest)"
                    Notes           = "Proxmox guests will run in CPU-only mode for this project. GPU acceleration is not required."
                }
            }
            "BareMetal" {
                # Bare metal: Allow full GPU initialization
                @{
                    Flags           = @()  # Server will auto-detect and use available GPU
                    GPUEnabled      = $true
                    SuggestedFlags  = "GPU enabled (native hardware access)"
                    Notes           = "Running on bare metal with native GPU access enabled."
                }
            }
            "WSL" {
                # WSL: Depends on nested virtualization (WSL in Hyper-V vs. native)
                # Default to CPU-only unless GPU passthrough available
                @{
                    Flags           = @()  # WSL typically doesn't support GPU passthrough easily
                    GPUEnabled      = $false
                    SuggestedFlags  = "CPU-only mode (WSL GPU passthrough limited)"
                    Notes           = "Running in WSL. GPU access is limited; CPU-only mode recommended."
                }
            }
            default {
                # Fallback to CPU-only for unknown environments
                @{
                    Flags           = @()
                    GPUEnabled      = $false
                    SuggestedFlags  = "CPU-only mode (unknown environment)"
                    Notes           = "Environment type unknown. Defaulting to CPU-only mode for stability."
                }
            }
        }
        
        Write-ServerLog "GPU Configuration: $($gpuConfig.SuggestedFlags)" -Level INFO
        Write-ServerLog "Notes: $($gpuConfig.Notes)" -Level INFO
        
        # Log flags if any were determined
        if ($gpuConfig.Flags.Count -gt 0) {
            Write-ServerLog "Launch flags: $($gpuConfig.Flags -join ' ')" -Level INFO
        }
        
        return [PSCustomObject]$gpuConfig
    } catch {
        Write-ServerLog "Error determining GPU configuration: $($_.Exception.Message)" -Level ERROR
        
        # Safe fallback: CPU-only
        return [PSCustomObject]@{
            Flags           = @()
            GPUEnabled      = $false
            SuggestedFlags  = "CPU-only mode (error fallback)"
            Notes           = "Error during GPU configuration. Defaulting to CPU-only for stability."
        }
    }
}

function Format-ByteSize {
    <#
    .SYNOPSIS
        Formats byte size into human-readable string.
    
    .DESCRIPTION
        Converts byte count to appropriate unit (KB, MB, GB, TB) with 2 decimal places.
    
    .PARAMETER Bytes
        The number of bytes to format.
    
    .OUTPUTS
        String formatted as "X.XX MB"
    
    .EXAMPLE
        Format-ByteSize 1234567890
        # Returns: "1.15 GB"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [long]$Bytes
    )
    
    if ($Bytes -ge 1TB) {
        return "{0:N2} TB" -f ($Bytes / 1TB)
    } elseif ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes bytes"
    }
}

function Show-ScriptMenu {
    <#
    .SYNOPSIS
        Displays available scripts and recommended next steps.

    .DESCRIPTION
        Shows a consistent footer after script execution listing all available
        management scripts and highlighting recommended next steps based on
        which script was just run.

    .PARAMETER CurrentScript
        The filename of the script that just finished (e.g. "7-Backup-GameFiles.ps1").

    .EXAMPLE
        Show-ScriptMenu -CurrentScript "7-Backup-GameFiles.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$CurrentScript
    )

    # Define all scripts with short descriptions
    $allScripts = [ordered]@{
        "0-Initial-Setup.ps1"        = "Full first-time server setup (runs steps 1-3)"
        "1-Install-Dependencies.ps1" = "Install SteamCMD, create directories, configure firewall"
        "2-Download-Server.ps1"      = "Download Enshrouded dedicated server via SteamCMD"
        "3-Configure-Server.ps1"     = "Apply server configuration (name, ports, passwords)"
        "4-Health-Check.ps1"         = "Check server process, ports, and disk space"
        "5-Update-Server.ps1"        = "Update server to latest version"
        "6-Setup-Alias.ps1"          = "Create 'enshrouded-update' PowerShell alias"
        "7-Backup-GameFiles.ps1"     = "Create backup archive of server files"
        "8-Setup-ScheduledTask.ps1"  = "Configure server auto-start on boot"
        "9-Start-Server.ps1"         = "Start the Enshrouded server"
        "10-Stop-Server.ps1"         = "Stop the Enshrouded server"
    }

    # Define recommended next steps per script
    $recommendations = @{
        "0-Initial-Setup.ps1"        = @("8-Setup-ScheduledTask.ps1", "9-Start-Server.ps1")
        "1-Install-Dependencies.ps1" = @("2-Download-Server.ps1")
        "2-Download-Server.ps1"      = @("3-Configure-Server.ps1")
        "2-Download-Server-Mock.ps1" = @("3-Configure-Server.ps1")
        "3-Configure-Server.ps1"     = @("9-Start-Server.ps1", "8-Setup-ScheduledTask.ps1")
        "4-Health-Check.ps1"         = @("5-Update-Server.ps1", "7-Backup-GameFiles.ps1")
        "5-Update-Server.ps1"        = @("4-Health-Check.ps1", "9-Start-Server.ps1")
        "6-Setup-Alias.ps1"          = @("9-Start-Server.ps1", "8-Setup-ScheduledTask.ps1")
        "7-Backup-GameFiles.ps1"     = @("9-Start-Server.ps1", "5-Update-Server.ps1")
        "8-Setup-ScheduledTask.ps1"  = @("9-Start-Server.ps1", "4-Health-Check.ps1")
        "9-Start-Server.ps1"         = @("4-Health-Check.ps1", "7-Backup-GameFiles.ps1")
        "10-Stop-Server.ps1"         = @("7-Backup-GameFiles.ps1", "5-Update-Server.ps1", "9-Start-Server.ps1")
        "Debug-SteamCMD.ps1"         = @("2-Download-Server.ps1", "1-Install-Dependencies.ps1")
        "Diagnose-ServerCrash.ps1"   = @("9-Start-Server.ps1", "4-Health-Check.ps1")
    }

    $recommended = $recommendations[$CurrentScript]

    Write-Host "`n========================================" -ForegroundColor DarkCyan
    Write-Host "  Available Scripts" -ForegroundColor DarkCyan
    Write-Host "========================================" -ForegroundColor DarkCyan

    foreach ($entry in $allScripts.GetEnumerator()) {
        $name = $entry.Key
        $desc = $entry.Value
        if ($name -eq $CurrentScript) {
            Write-Host "  * $name  — $desc" -ForegroundColor DarkGray
        } else {
            Write-Host "    $name  — $desc" -ForegroundColor Gray
        }
    }

    if ($recommended -and $recommended.Count -gt 0) {
        Write-Host "`n  Recommended next:" -ForegroundColor Yellow
        foreach ($r in $recommended) {
            Write-Host "    .\scripts\guest\$r" -ForegroundColor Cyan
        }
    }

    Write-Host "========================================`n" -ForegroundColor DarkCyan
}

# Export functions only when loaded as a module
if ($ExecutionContext.SessionState.Module) {
    Export-ModuleMember -Function Write-ServerLog, Write-EventLogEntry, Initialize-TranscriptLogging, Test-TranscriptRunning, Manage-TranscriptLogs, Get-EnvironmentType, ConvertTo-PSCustomObject, Set-GPUConfiguration, Test-ServerProcess, Get-ServerConfig, Test-AdminPrivileges, Format-ByteSize, Show-ScriptMenu
}
