<#
.SYNOPSIS
    Diagnoses why enshrouded_server.exe crashes immediately.

.DESCRIPTION
    Performs deep diagnostics on server crash issues:
    - Checks executable architecture and validity
    - Scans for missing DLL dependencies
    - Reviews Windows Event Viewer for application errors
    - Validates Visual C++ Redistributables
    - Checks DirectX runtime

.EXAMPLE
    .\Diagnose-ServerCrash.ps1
    Runs comprehensive server crash diagnostics.

.NOTES
    File Name  : Diagnose-ServerCrash.ps1
    Author     : Enshrouded Server Management Project
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Server Crash Diagnostics" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Starting crash diagnostics..." -Level INFO

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration." -ForegroundColor Red
    exit 1
}

$serverExe = Join-Path $config.Paths.ServerInstall "enshrouded_server.exe"

# Check 1: Verify executable exists
Write-Host "[1/7] Checking Server Executable" -ForegroundColor Yellow
Write-Host "---------------------------------" -ForegroundColor Gray

if (Test-Path $serverExe) {
    $exeInfo = Get-Item $serverExe
    Write-Host "[OK] Executable found" -ForegroundColor Green
    Write-Host "     Path: $serverExe" -ForegroundColor Gray
    Write-Host "     Size: $(Format-ByteSize $exeInfo.Length)" -ForegroundColor Gray
    Write-Host "     Modified: $($exeInfo.LastWriteTime)" -ForegroundColor Gray
    
    # Check if it's a valid PE file
    try {
        $bytes = [System.IO.File]::ReadAllBytes($serverExe)
        if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
            Write-Host "     Format: Valid PE executable (MZ header)" -ForegroundColor Gray
        } else {
            Write-Host "     [WARN] File does not have valid PE header!" -ForegroundColor Red
        }
    } catch {
        Write-Host "     [WARN] Could not read file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[FAIL] Server executable not found!" -ForegroundColor Red
    Write-Host "       Expected: $serverExe" -ForegroundColor Gray
    exit 1
}

# Check 2: Check architecture
Write-Host "`n[2/7] Checking Architecture" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Gray

$osArch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
Write-Host "OS Architecture: $osArch" -ForegroundColor Gray

# Try to determine exe architecture
try {
    $exeArch = "Unknown"
    $bytes = [System.IO.File]::ReadAllBytes($serverExe)
    # Read PE header offset at 0x3C
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    # Read machine type at PE header + 4
    $machineType = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    
    $exeArch = switch ($machineType) {
        0x014c { "x86 (32-bit)" }
        0x8664 { "x64 (64-bit)" }
        0x0200 { "IA64 (Itanium)" }
        0xAA64 { "ARM64" }
        default { "Unknown (0x$($machineType.ToString('X4')))" }
    }
    
    Write-Host "Executable Architecture: $exeArch" -ForegroundColor Gray
    
    if ($osArch -eq "64-bit" -and $exeArch -like "*32-bit*") {
        Write-Host "[INFO] 32-bit exe on 64-bit OS - this should work via WOW64" -ForegroundColor Cyan
    } elseif ($osArch -eq "32-bit" -and $exeArch -like "*64-bit*") {
        Write-Host "[FAIL] 64-bit exe on 32-bit OS - INCOMPATIBLE!" -ForegroundColor Red
    } else {
        Write-Host "[OK] Architecture compatible" -ForegroundColor Green
    }
} catch {
    Write-Host "[WARN] Could not determine architecture: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Check 3: Visual C++ Redistributables
Write-Host "`n[3/7] Checking Visual C++ Redistributables" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray

$vcRedistKeys = @(
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86"
)

$vcFound = $false
foreach ($key in $vcRedistKeys) {
    $vcInfo = Get-ItemProperty $key -ErrorAction SilentlyContinue
    if ($vcInfo -and $vcInfo.Installed -eq 1) {
        Write-Host "[OK] Found: $key" -ForegroundColor Green
        Write-Host "     Version: $($vcInfo.Version)" -ForegroundColor Gray
        $vcFound = $true
    }
}

if (-not $vcFound) {
    Write-Host "[WARN] No Visual C++ Redistributables detected!" -ForegroundColor Red
    Write-Host "       Download: https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Yellow
}

# Check 4: DirectX Runtime
Write-Host "`n[4/7] Checking DirectX" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Gray

$d3d9 = Join-Path $env:SystemRoot "System32\d3d9.dll"
$d3d11 = Join-Path $env:SystemRoot "System32\d3d11.dll"
$dxgi = Join-Path $env:SystemRoot "System32\dxgi.dll"

if (Test-Path $d3d9) { Write-Host "[OK] DirectX 9 runtime present" -ForegroundColor Green } 
else { Write-Host "[WARN] DirectX 9 runtime missing" -ForegroundColor Yellow }

if (Test-Path $d3d11) { Write-Host "[OK] DirectX 11 runtime present" -ForegroundColor Green }
else { Write-Host "[WARN] DirectX 11 runtime missing" -ForegroundColor Yellow }

if (Test-Path $dxgi) { Write-Host "[OK] DXGI present" -ForegroundColor Green }
else { Write-Host "[WARN] DXGI missing" -ForegroundColor Yellow }

# Check 5: Recent Application Event Log errors
Write-Host "`n[5/7] Checking Windows Event Viewer" -ForegroundColor Yellow
Write-Host "-------------------------------------" -ForegroundColor Gray

try {
    $recentErrors = Get-EventLog -LogName Application -Source "Application Error" -Newest 10 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -like "*enshrouded*" }
    
    if ($recentErrors) {
        Write-Host "[INFO] Found recent application errors:" -ForegroundColor Yellow
        foreach ($err in $recentErrors) {
            Write-Host "`n  TimeGenerated: $($err.TimeGenerated)" -ForegroundColor Gray
            Write-Host "  Message:" -ForegroundColor Gray
            $err.Message -split "`n" | Select-Object -First 10 | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "[INFO] No recent enshrouded-related errors in Application log" -ForegroundColor Cyan
    }
} catch {
    Write-Host "[WARN] Could not read event log: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Check 6: GPU/Graphics availability
Write-Host "`n[6/7] Checking Graphics Capabilities" -ForegroundColor Yellow
Write-Host "-------------------------------------" -ForegroundColor Gray

# Get environment type for context
try {
    $envInfo = Get-EnvironmentType
    Write-Host "Detected Environment: $($envInfo.EnvironmentType)" -ForegroundColor Gray
    Write-Host "Is Virtual Machine: $($envInfo.IsVM)" -ForegroundColor Gray
    Write-ServerLog "Running diagnostics in environment: $($envInfo.EnvironmentType)" -Level INFO
} catch {
    Write-Host "[INFO] Could not determine environment type" -ForegroundColor Gray
}

try {
    $gpu = Get-WmiObject Win32_VideoController | Select-Object -First 1
    if ($gpu) {
        Write-Host "GPU: $($gpu.Name)" -ForegroundColor Gray
        Write-Host "Driver Version: $($gpu.DriverVersion)" -ForegroundColor Gray
        Write-Host "Video Memory: $([math]::Round($gpu.AdapterRAM/1MB)) MB" -ForegroundColor Gray
        
        if ($gpu.Name -like "*Microsoft Basic Display Adapter*" -or $gpu.Name -like "*Remote*") {
            Write-Host "[WARN] Basic/Remote display adapter detected" -ForegroundColor Yellow
            Write-Host "       Enshrouded may require actual GPU for headless mode" -ForegroundColor Yellow
            
            # Provide environment-specific guidance
            if ($envInfo.EnvironmentType -eq "HyperV") {
                Write-Host "`n[RECOMMENDATION for Hyper-V]" -ForegroundColor Cyan
                Write-Host "       GPU passthrough is limited in Hyper-V. Server is configured to run in CPU-only mode." -ForegroundColor Yellow
                Write-Host "       This is expected behavior. Server will use CPU rendering." -ForegroundColor Yellow
            } elseif ($envInfo.EnvironmentType -eq "Proxmox") {
                Write-Host "`n[RECOMMENDATION for Proxmox]" -ForegroundColor Cyan
                Write-Host "       Server is configured to run in CPU-only mode on Proxmox." -ForegroundColor Yellow
                Write-Host "       GPU acceleration is not utilized for this project. CPU rendering is expected." -ForegroundColor Yellow
            } elseif ($envInfo.EnvironmentType -eq "BareMetal") {
                Write-Host "`n[RECOMMENDATION for Bare Metal]" -ForegroundColor Cyan
                Write-Host "       Ensure GPU drivers are properly installed and up-to-date." -ForegroundColor Yellow
                Write-Host "       Update video driver software with the latest version from manufacturer." -ForegroundColor Yellow
            }
        } else {
            Write-Host "[OK] Dedicated GPU detected" -ForegroundColor Green
        }
    } else {
        Write-Host "[WARN] No GPU detected" -ForegroundColor Yellow
        
        # Provide environment-specific guidance
        if ($envInfo.EnvironmentType -eq "HyperV") {
            Write-Host "       This is expected in Hyper-V. CPU-only mode will be used." -ForegroundColor Gray
        } elseif ($envInfo.EnvironmentType -eq "BareMetal") {
            Write-Host "       This may indicate missing drivers or hardware issue." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "[WARN] Could not query GPU info: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Check 7: Try to get dependency info
Write-Host "`n[7/7] Checking for Missing DLLs" -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Gray

Write-Host "Attempting to load executable and check for errors..." -ForegroundColor Gray

try {
    # Try to spawn process and immediately capture exit
    $testProcess = New-Object System.Diagnostics.Process
    $testProcess.StartInfo.FileName = $serverExe
    $testProcess.StartInfo.WorkingDirectory = $config.Paths.ServerInstall
    $testProcess.StartInfo.UseShellExecute = $false
    $testProcess.StartInfo.RedirectStandardError = $true
    $testProcess.StartInfo.RedirectStandardOutput = $true
    $testProcess.StartInfo.CreateNoWindow = $true
    
    $null = $testProcess.Start()
    Start-Sleep -Milliseconds 500
    
    if ($testProcess.HasExited) {
        Write-Host "Exit Code: $($testProcess.ExitCode)" -ForegroundColor Red
        
        $stderr = $testProcess.StandardError.ReadToEnd()
        $stdout = $testProcess.StandardOutput.ReadToEnd()
        
        if ($stderr) {
            Write-Host "`nStandard Error:" -ForegroundColor Yellow
            Write-Host $stderr -ForegroundColor Gray
        }
        
        if ($stdout) {
            Write-Host "`nStandard Output:" -ForegroundColor Yellow
            Write-Host $stdout -ForegroundColor Gray
        }
    }
    
    $testProcess.Dispose()
} catch {
    Write-Host "[ERROR] Failed to start process: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*cannot find*" -or $_.Exception.Message -like "*dll*") {
        Write-Host "`n       This typically indicates a missing DLL dependency." -ForegroundColor Yellow
    }
}

# Summary and recommendations
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Recommendations" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Common fixes for exit code -1:" -ForegroundColor Yellow
Write-Host "  1. Install latest Visual C++ Redistributable" -ForegroundColor Gray
Write-Host "     https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Gray
Write-Host "`n  2. Install DirectX End-User Runtime" -ForegroundColor Gray
Write-Host "     https://www.microsoft.com/download/details.aspx?id=35" -ForegroundColor Gray
Write-Host "`n  3. For VMs: Enable GPU passthrough or use software rendering" -ForegroundColor Gray
Write-Host "`n  4. Check server logs for detailed error:" -ForegroundColor Gray
Write-Host "     $(Join-Path $config.Paths.ServerInstall 'logs')" -ForegroundColor Gray
Write-Host "`n  5. For Hyper-V: Try Enhanced Session Mode or RemoteFX" -ForegroundColor Gray
Write-Host "`n  6. Alternative: Test on physical hardware or different hypervisor" -ForegroundColor Gray
Write-Host "     (e.g., Proxmox with better GPU emulation)" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan

Write-ServerLog "Crash diagnostics completed." -Level INFO
