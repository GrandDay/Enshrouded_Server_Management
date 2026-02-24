<#
.SYNOPSIS
    Sets up PowerShell profile alias for server updates.

.DESCRIPTION
    Creates a PowerShell profile alias "Update-Enshrouded" that points to
    the 5-Update-Server.ps1 script for convenient server updates.

.EXAMPLE
    .\6-Setup-Alias.ps1
    Adds alias to PowerShell profile.

.NOTES
    File Name  : 6-Setup-Alias.ps1
    Author     : Enshrouded Server Management Project
    Requires   : PowerShell 5.1
    Version    : 1.0
#>

[CmdletBinding()]
param()

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Setup PowerShell Alias" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-ServerLog "Setting up PowerShell alias..." -Level INFO

# Get script path
$UpdateScriptPath = Join-Path $PSScriptRoot "5-Update-Server.ps1"

if (-not (Test-Path $UpdateScriptPath)) {
    Write-ServerLog "Update script not found: $UpdateScriptPath" -Level ERROR
    Write-Host "[FAIL] Update script not found." -ForegroundColor Red
    exit 1
}

# Alias configuration
$AliasName = "Update-Enshrouded"
$AliasLine = "Set-Alias -Name $AliasName -Value '$UpdateScriptPath'"

Write-Host "Alias Name:   $AliasName" -ForegroundColor Gray
Write-Host "Target Script: $UpdateScriptPath" -ForegroundColor Gray
Write-Host "Profile Path: $PROFILE`n" -ForegroundColor Gray

# Create profile if missing
if (!(Test-Path $PROFILE)) {
    Write-Host "PowerShell profile not found. Creating..." -ForegroundColor Yellow
    try {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
        Write-Host "[OK] Created PowerShell profile: $PROFILE" -ForegroundColor Green
        Write-ServerLog "Created PowerShell profile: $PROFILE" -Level INFO
    } catch {
        Write-ServerLog "Failed to create profile: $($_.Exception.Message)" -Level ERROR
        Write-Host "[FAIL] Failed to create profile file." -ForegroundColor Red
        exit 1
    }
}

# Check if alias already exists
if (Select-String -Path $PROFILE -Pattern $AliasName -Quiet) {
    Write-Host "[INFO] Alias '$AliasName' already exists in profile." -ForegroundColor Yellow
    Write-ServerLog "Alias '$AliasName' already exists in profile." -Level INFO
    
    Write-Host "`nUpdate existing alias? (Y/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "[INFO] Alias setup cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    # Remove existing alias line
    Write-Host "Removing existing alias..." -ForegroundColor Yellow
    $profileContent = Get-Content $PROFILE | Where-Object {$_ -notmatch "Set-Alias.*$AliasName"}
    $profileContent | Set-Content $PROFILE
}

# Add alias to profile
try {
    Add-Content -Path $PROFILE -Value "`n# Enshrouded Server Management Alias (Added: $(Get-Date -Format 'yyyy-MM-dd'))"
    Add-Content -Path $PROFILE -Value $AliasLine
    
    Write-Host "[OK] Alias '$AliasName' added to profile." -ForegroundColor Green
    Write-ServerLog "Alias '$AliasName' added to profile successfully." -Level SUCCESS
} catch {
    Write-ServerLog "Failed to add alias to profile: $($_.Exception.Message)" -Level ERROR
    Write-Host "[FAIL] Failed to add alias to profile." -ForegroundColor Red
    exit 1
}

# Activate in current session
Set-Alias -Name $AliasName -Value $UpdateScriptPath
Write-Host "[OK] Alias active in current session." -ForegroundColor Green
Write-ServerLog "Alias activated in current session." -Level SUCCESS

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Alias Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  In this session: $AliasName" -ForegroundColor White
Write-Host "  In new sessions: $AliasName (will be available automatically)" -ForegroundColor White

Write-Host "`nExample:" -ForegroundColor Cyan
Write-Host "  PS> $AliasName" -ForegroundColor Gray
Write-Host "  (This will run 5-Update-Server.ps1)" -ForegroundColor Gray

Write-Host "`n[INFO] You can now use '$AliasName' to update and restart the server." -ForegroundColor Yellow
Write-Host "`n" -NoNewline
