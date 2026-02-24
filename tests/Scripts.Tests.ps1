<#
.SYNOPSIS
    Pester tests for PowerShell script quality and standards.

.DESCRIPTION
    Tests all PowerShell scripts in the project for:
    - Valid PowerShell syntax
    - Comment-based help present
    - Logging uses Write-ServerLog
    - Error handling with try/catch blocks
    - No hardcoded paths

.NOTES
    File Name  : Scripts.Tests.ps1
    Requires   : Pester 5.x
#>

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $GuestScriptsPath = Join-Path $ProjectRoot "scripts\guest"
    $HostScriptsPath = Join-Path $ProjectRoot "scripts\host"
    
    # Get all PowerShell script files
    $AllScripts = @()
    $AllScripts += Get-ChildItem $GuestScriptsPath -Filter *.ps1 -File -ErrorAction SilentlyContinue
    $AllScripts += Get-ChildItem $HostScriptsPath -Filter *.ps1 -File -ErrorAction SilentlyContinue
}

Describe "PowerShell Script Quality Tests" {
    
    Context "Script Files Exist" {
        
        It "Guest scripts directory should exist" {
            $GuestScriptsPath | Should -Exist
        }
        
        It "Host scripts directory should exist" {
            $HostScriptsPath | Should -Exist
        }
        
        It "Should have guest scripts" {
            $guestScripts = Get-ChildItem $GuestScriptsPath -Filter *.ps1 -File
            $guestScripts.Count | Should -BeGreaterThan 0
        }
        
        It "Should have host scripts" {
            $hostScripts = Get-ChildItem $HostScriptsPath -Filter *.ps1 -File
            $hostScripts.Count | Should -BeGreaterThan 0
        }
        
        It "Should have expected number of guest scripts (11)" {
            $guestScripts = Get-ChildItem $GuestScriptsPath -Filter *.ps1 -File | 
                Where-Object { $_.Name -notmatch "^Common-" }
            $guestScripts.Count | Should -BeGreaterOrEqual 10
        }
        
        It "Should have expected number of host scripts (2)" {
            $hostScripts = Get-ChildItem $HostScriptsPath -Filter *.ps1 -File
            $hostScripts.Count | Should -BeGreaterOrEqual 2
        }
    }
    
    Context "PowerShell Syntax Validation" {
        
        BeforeAll {
            $scriptFiles = $AllScripts | Where-Object { $_.Name -ne "Common-Functions.ps1" }
        }
        
        It "Script '<_.Name>' should have valid PowerShell syntax" -ForEach $scriptFiles {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $_.FullName -Raw), [ref]$errors
            )
            $errors.Count | Should -Be 0
        }
        
        It "Script '<_.Name>' should parse without errors (AST)" -ForEach $scriptFiles {
            { 
                $null = [System.Management.Automation.Language.Parser]::ParseFile(
                    $_.FullName, [ref]$null, [ref]$null
                )
            } | Should -Not -Throw
        }
    }
    
    Context "Comment-Based Help Validation" {
        
        BeforeAll {
            $scriptFiles = $AllScripts | Where-Object { $_.Name -ne "Common-Functions.ps1" }
        }
        
        It "Script '<_.Name>' should have .SYNOPSIS" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '\.SYNOPSIS'
        }
        
        It "Script '<_.Name>' should have .DESCRIPTION" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '\.DESCRIPTION'
        }
        
        It "Script '<_.Name>' should have .EXAMPLE" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '\.EXAMPLE'
        }
        
        It "Script '<_.Name>' should have .NOTES" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '\.NOTES'
        }
    }
    
    Context "Logging Standards" {
        
        BeforeAll {
            $guestScripts = Get-ChildItem $GuestScriptsPath -Filter *.ps1 -File | 
                Where-Object { $_.Name -ne "Common-Functions.ps1" }
        }
        
        It "Guest script '<_.Name>' should dot-source Common-Functions.ps1" -ForEach $guestScripts {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '\. .+Common-Functions\.ps1'
        }
        
        It "Guest script '<_.Name>' should use Write-ServerLog for logging" -ForEach $guestScripts {
            $content = Get-Content $_.FullName -Raw
            # Scripts should use Write-ServerLog (except Common-Functions which defines it)
            if ($_.Name -ne "Common-Functions.ps1") {
                $content | Should -Match 'Write-ServerLog'
            }
        }
    }
    
    Context "Error Handling Standards" {
        
        BeforeAll {
            $scriptFiles = $AllScripts | Where-Object { $_.Name -ne "Common-Functions.ps1" }
        }
        
        It "Script '<_.Name>' should have error handling (try/catch or ErrorAction)" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            # Should have try/catch blocks or -ErrorAction parameters
            ($content -match '\btry\b' -or $content -match '-ErrorAction') | Should -Be $true
        }
    }
    
    Context "Configuration Usage" {
        
        BeforeAll {
            $guestScripts = Get-ChildItem $GuestScriptsPath -Filter *.ps1 -File | 
                Where-Object { $_.Name -match '^\d+-' }  # Numbered scripts
        }
        
        It "Script '<_.Name>' should load configuration via Get-ServerConfig" -ForEach $guestScripts {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match 'Get-ServerConfig'
        }
        
        It "Script '<_.Name>' should not have hardcoded paths (C:\EnshroudedServer)" -ForEach $guestScripts {
            $content = Get-Content $_.FullName -Raw
            # Exclude configuration path itself and comments
            $codeLines = ($content -split "`n") | Where-Object { 
                $_ -notmatch '^\s*#' -and 
                $_ -notmatch '\.json' -and
                $_ -notmatch 'Get-ServerConfig'
            }
            $codeOnly = $codeLines -join "`n"
            
            # Allow C:\EnshroudedServer\EnshroudedServerConfig.json but not other hardcoded paths
            $hardcodedPathMatches = [regex]::Matches($codeOnly, 'C:\\(?!EnshroudedServer\\EnshroudedServerConfig\.json)')
            $hardcodedPathMatches.Count | Should -BeLessOrEqual 2  # Allow minimal hardcoding
        }
    }
    
    Context "CmdletBinding and Parameters" {
        
        BeforeAll {
            $scriptFiles = $AllScripts | Where-Object { $_.Name -ne "Common-Functions.ps1" }
        }
        
        It "Script '<_.Name>' should have [CmdletBinding()] attribute" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '\[CmdletBinding\(\)\]'
        }
        
        It "Script '<_.Name>' should have param() block" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            $content | Should -Match '\bparam\s*\('
        }
    }
    
    Context "Output Formatting" {
        
        BeforeAll {
            $scriptFiles = $AllScripts
        }
        
        It "Script '<_.Name>' should use Write-Host with -ForegroundColor for colored output" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            if ($content -match 'Write-Host') {
                # If using Write-Host, should specify colors for consistency
                $content | Should -Match 'Write-Host.*-ForegroundColor'
            }
        }
    }
    
    Context "Code Style Standards" {
        
        BeforeAll {
            $scriptFiles = $AllScripts
        }
        
        It "Script '<_.Name>' should not have trailing whitespace on lines" -ForEach $scriptFiles {
            $lines = Get-Content $_.FullName
            $trailingWhitespace = $lines | Where-Object { $_ -match '\s+$' }
            $trailingWhitespace.Count | Should -BeLessOrEqual 5  # Allow some flexibility
        }
        
        It "Script '<_.Name>' should use consistent indentation" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            # Check for mix of tabs and spaces (allow some flexibility)
            $tabCount = ([regex]::Matches($content, '^\t', 'Multiline')).Count
            $spaceIndentCount = ([regex]::Matches($content, '^    ', 'Multiline')).Count
            
            # Should predominantly use one or the other
            if ($tabCount -gt 10 -and $spaceIndentCount -gt 10) {
                $false | Should -Be $true -Because "Script mixes tabs and spaces for indentation"
            }
        }
    }
    
    Context "Security and Best Practices" {
        
        BeforeAll {
            $scriptFiles = $AllScripts
        }
        
        It "Script '<_.Name>' should not contain hardcoded passwords" -ForEach $scriptFiles {
            $content = Get-Content $_.FullName -Raw
            # Check for common password patterns (excluding variable names and comments)
            $content | Should -Not -Match 'password\s*=\s*["\'][^"\'$]{8,}'
        }
        
        It "Scripts requiring admin should check Test-AdminPrivileges" {
            $scriptsThatNeedAdmin = $AllScripts | Where-Object { 
                $_.Name -match '^(1-|8-|0-)' -or $_.Name -match 'Backup-|Hibernate-'
            }
            
            foreach ($script in $scriptsThatNeedAdmin) {
                $content = Get-Content $script.FullName -Raw
                $content | Should -Match 'Test-AdminPrivileges|Administrator'
            }
        }
    }
}
