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

# Export functions (not needed for dot-sourcing, but good practice for documentation)
Export-ModuleMember -Function Write-ServerLog, Test-ServerProcess, Get-ServerConfig, Test-AdminPrivileges, Format-ByteSize
