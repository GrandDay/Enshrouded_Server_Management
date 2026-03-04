<#
.SYNOPSIS
    Diagnostic script to test SteamCMD connectivity and app ID validity.

.DESCRIPTION
    Helps troubleshoot SteamCMD issues by testing different app IDs and login methods.
    
.NOTES
    File Name  : Debug-SteamCMD.ps1
    Author     : Enshrouded Server Management Project
    Version    : 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [int]$AppId = 2278520
)

# Dot-source common functions
. "$PSScriptRoot\Common-Functions.ps1"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  SteamCMD Diagnostic Tool" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Load configuration
try {
    $config = Get-ServerConfig
} catch {
    Write-Host "[FAIL] Could not load configuration." -ForegroundColor Red
    exit 1
}

$steamCmdExe = Join-Path $config.Paths.SteamCMD "steamcmd.exe"
if (-not (Test-Path $steamCmdExe)) {
    Write-Host "[FAIL] SteamCMD not found at: $steamCmdExe" -ForegroundColor Red
    exit 1
}

Write-Host "Testing App ID: $AppId`n" -ForegroundColor Yellow

# Test 1: Try anonymous login with app_info
Write-Host "[Test 1] Checking if app $AppId exists..." -ForegroundColor Yellow
$testScript = Join-Path $env:TEMP "steamcmd_test.txt"
@"
@ShutdownOnFailedCommand 0
@NoPromptForPassword 1
login anonymous
app_info_print $AppId
quit
"@ | Out-File -FilePath $testScript -Encoding ASCII

Write-Host "Running SteamCMD app_info_print..." -ForegroundColor Gray
$process = Start-Process -FilePath $steamCmdExe -ArgumentList "+runscript `"$testScript`"" -Wait -NoNewWindow -PassThru

Write-Host "`n[Test 1] Exit Code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { 'Green' } else { 'Red' })

# Test 2: List known working dedicated server app IDs
Write-Host "`n[Test 2] Enshrouded App IDs:" -ForegroundColor Yellow
Write-Host "  - 2278520 (Enshrouded - unverified dedicated server)" -ForegroundColor Gray
Write-Host "  - 1203620 (Enshrouded - main game client)" -ForegroundColor Gray
Write-Host "`nNote: Enshrouded may not have a public dedicated server app" -ForegroundColor Yellow
Write-Host "that can be downloaded anonymously via SteamCMD." -ForegroundColor Yellow

# Recommendations
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Troubleshooting Steps" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "1. Verify correct app ID:" -ForegroundColor Yellow
Write-Host "   - Check official Enshrouded documentation" -ForegroundColor Gray
Write-Host "   - Search SteamDB (https://steamdb.info/) for 'Enshrouded Dedicated Server'" -ForegroundColor Gray
Write-Host "   - Check Enshrouded community/forums for server setup guides" -ForegroundColor Gray

Write-Host "`n2. Alternative installation methods:" -ForegroundColor Yellow
Write-Host "   - Manual download from Steam (if you own Enshrouded)" -ForegroundColor Gray
Write-Host "   - Direct download from official sources" -ForegroundColor Gray
Write-Host "   - Use Steam account login instead of anonymous" -ForegroundColor Gray

Write-Host "`n3. For educational/testing purposes:" -ForegroundColor Yellow
Write-Host "   - Create a mock server structure manually" -ForegroundColor Gray
Write-Host "   - Use placeholder files to test automation workflow" -ForegroundColor Gray
Write-Host "   - Document as a known limitation in the project" -ForegroundColor Gray

Write-Host "`n4. Update configuration if correct app ID is found:" -ForegroundColor Yellow
Write-Host "   - Edit scripts to use correct app ID" -ForegroundColor Gray
Write-Host "   - Update docs/Spec.MD with verified information" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan

Remove-Item $testScript -Force -ErrorAction SilentlyContinue

