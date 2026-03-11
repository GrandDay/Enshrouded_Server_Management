<#
.SYNOPSIS
    Pester tests for script quality and standards.
.DESCRIPTION
    Validates all project scripts for syntax, documentation, and
    coding standards. Only reads file contents — never executes scripts.
.NOTES
    File Name : Scripts.Tests.ps1
    Requires  : Pester 5.x
#>

Describe "Script Quality Tests" {

    BeforeAll {
        $root = Split-Path -Parent $PSScriptRoot
        $guestDir = Join-Path $root "scripts\guest"

        $guestFiles = Get-ChildItem $guestDir -Filter *.ps1 -File
    }

    # --- Inventory ---

    It "Guest scripts directory exists"       { Test-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\guest") | Should -Be $true }
    It "Has at least 12 guest scripts"        { $guestFiles.Count | Should -BeGreaterOrEqual 12 }

    # --- Syntax ---

    It "All scripts tokenize without errors" {
        foreach ($f in $guestFiles) {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $f.FullName -Raw), [ref]$errors
            )
            $errors.Count | Should -Be 0 -Because "$($f.Name) should have no syntax errors"
        }
    }

    # --- Documentation ---

    It "All non-Common scripts have .SYNOPSIS" {
        foreach ($f in ($guestFiles | Where-Object { $_.Name -ne 'Common-Functions.ps1' -and $_.Name -ne 'lab-start.ps1' })) {
            $c = Get-Content $f.FullName -Raw
            $c | Should -Match '\.SYNOPSIS' -Because "$($f.Name) needs a .SYNOPSIS block"
        }
    }

    It "All non-Common scripts have .DESCRIPTION" {
        foreach ($f in ($guestFiles | Where-Object { $_.Name -ne 'Common-Functions.ps1' -and $_.Name -ne 'lab-start.ps1' })) {
            $c = Get-Content $f.FullName -Raw
            $c | Should -Match '\.DESCRIPTION' -Because "$($f.Name) needs a .DESCRIPTION block"
        }
    }

    # --- Standards ---

    It "Guest scripts dot-source Common-Functions.ps1" {
        foreach ($f in ($guestFiles | Where-Object { $_.Name -ne 'Common-Functions.ps1' -and $_.Name -ne 'lab-start.ps1' })) {
            $c = Get-Content $f.FullName -Raw
            $c | Should -Match 'Common-Functions\.ps1' -Because "$($f.Name) should source Common-Functions"
        }
    }

    It "Guest scripts use Write-ServerLog" {
        foreach ($f in ($guestFiles | Where-Object { $_.Name -ne 'Common-Functions.ps1' -and $_.Name -ne 'lab-start.ps1' -and $_.Name -ne 'Debug-SteamCMD.ps1' })) {
            $c = Get-Content $f.FullName -Raw
            $c | Should -Match 'Write-ServerLog' -Because "$($f.Name) should use structured logging"
        }
    }

    It "All non-Common scripts have error handling" {
        foreach ($f in ($guestFiles | Where-Object { $_.Name -ne 'Common-Functions.ps1' -and $_.Name -ne 'lab-start.ps1' })) {
            $c = Get-Content $f.FullName -Raw
            ($c -match '\btry\b' -or $c -match '-ErrorAction') |
                Should -Be $true -Because "$($f.Name) needs try/catch or -ErrorAction"
        }
    }

    It "All non-Common scripts have [CmdletBinding()]" {
        foreach ($f in ($guestFiles | Where-Object { $_.Name -ne 'Common-Functions.ps1' -and $_.Name -ne 'lab-start.ps1' })) {
            $c = Get-Content $f.FullName -Raw
            $c | Should -Match '\[CmdletBinding\(\)\]' -Because "$($f.Name) should use CmdletBinding"
        }
    }

    It "No scripts contain hardcoded passwords" {
        foreach ($f in ($guestFiles | Where-Object Name -notmatch 'Mock')) {
            $c = Get-Content $f.FullName -Raw
            $c | Should -Not -Match "password\s*=\s*[`"'][^`"'\`$]{8,}" -Because "$($f.Name) must not hardcode passwords"
        }
    }
}
